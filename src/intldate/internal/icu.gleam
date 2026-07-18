import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import intldate/internal/icu/dtfmt/dtitvfmt
import intldate/internal/icu/dtfmt/reldtfmt
import intldate/internal/icu/dtfmt/smpdtfmt
import intldate/internal/icu/dtptngen/udatpg
import intldate/internal/icu/icudata/bundle
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/loader
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/locale/localematcher
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/uloc_tag
import intldate/internal/icu/locale/zonemeta
import intldate/internal/icu/numsys/unumsys

pub type IcuError {
  FailedToLoadTimeZone(inner: String)
  FailedToLoadLocale(inner: String)
  FailedToLoadCalendar(inner: String)
  FailedToLoadData(inner: String)
  SystemTimeZoneUnavailable
  Unknown(inner: String)
}

pub type DateTimeContext {
  DateTimeContext(bundle: bundle.Bundle, locale_id: String)
}

pub type DateTimeAnalysis {
  DateTimeAnalysis(
    context: DateTimeContext,
    pattern: String,
    hour_cycle: Int,
    region: String,
    numbering_system: String,
    locale: String,
    calendar: String,
  )
}

pub type LocaleMatcher {
  LocaleMatcherBestFit
  LocaleMatcherLookup
}

type FormatPart {
  FormatPart(type_: String, value: String, source: Option(String))
}

type FormatPartsResult {
  FormatPartsResult(formatted: String, parts: List(FormatPart))
}

const uloc_available_default = 0

fn zonemeta_bundle(bundle: bundle.Bundle) -> bundle.Bundle {
  bundle
}

fn available_locale_names(bundle: bundle.Bundle) -> Dict(String, Nil) {
  bundle.available_locales
}

fn lookup_supported_locale(
  bundle: bundle.Bundle,
  base: String,
) -> Option(String) {
  first_available_locale(bundle, best_available_chain(base))
}

fn best_available_chain(candidate: String) -> List(String) {
  case candidate {
    "" -> []
    _ -> [candidate, ..best_available_chain(truncate_locale(candidate))]
  }
}

fn truncate_locale(candidate: String) -> String {
  case string.split(candidate, "_") {
    [] | [_] -> ""
    parts -> {
      let kept = list.take(parts, list.length(parts) - 1)
      case kept {
        [single] -> single
        _ ->
          case list.last(kept) {
            Ok(last) ->
              case string.length(last) == 1 {
                True -> string.join(list.take(kept, list.length(kept) - 1), "_")
                False -> string.join(kept, "_")
              }
            Error(_) -> string.join(kept, "_")
          }
      }
    }
  }
}

fn best_fit_supported_locale(
  bundle: bundle.Bundle,
  base: String,
) -> Result(Option(String), IcuError) {
  case dict.has_key(available_locale_names(bundle), base) {
    True -> Ok(Some(base))
    False -> {
      use matcher <- result.try(available_locale_matcher(bundle))
      let matched =
        localematcher.accept_language_with_matcher(matcher, [base], False, "")
      case matched {
        None -> Ok(None)
        Some(_) -> Ok(lookup_supported_locale(bundle, base))
      }
    }
  }
}

fn first_available_locale(
  bundle: bundle.Bundle,
  chain: List(String),
) -> Option(String) {
  case chain {
    [] -> None
    [name, ..rest] ->
      case dict.has_key(available_locale_names(bundle), name) {
        True -> Some(name)
        False -> first_available_locale(bundle, rest)
      }
  }
}

fn replace_locale_base(locale_id: String, base: String) -> String {
  case string.split_once(locale_id, "@") {
    Ok(#(_, keywords)) -> base <> "@" <> keywords
    Error(_) -> base
  }
}

fn bare_locale(language: String, script: String) -> String {
  case script {
    "" -> language
    _ -> language <> "_" <> script
  }
}

fn borrows_from_other_language(
  bundle: bundle.Bundle,
  language: String,
  script: String,
) -> Bool {
  let bare = bare_locale(language, script)
  let generators = bundle.pattern_generators.locale_to_generator
  case dict.get(generators, bare) {
    Error(_) -> False
    Ok(bare_generator) ->
      borrows_loop(
        generators,
        language,
        bare_generator,
        localechain.locale_chain(bundle.locale_parents, bare),
      )
  }
}

fn borrows_loop(
  generators: Dict(String, Int),
  language: String,
  bare_generator: Int,
  chain: List(String),
) -> Bool {
  case chain {
    [] -> False
    [ancestor, ..rest] ->
      case
        ancestor != localechain.root_locale_name
        && uloc.get_language_subtag(Some(ancestor)) != language
      {
        True ->
          case dict.get(generators, ancestor) {
            Ok(generator) -> generator == bare_generator
            Error(_) -> False
          }
        False -> borrows_loop(generators, language, bare_generator, rest)
      }
  }
}

fn display_locale_id(bundle: bundle.Bundle, locale_id: String) -> String {
  let base = uloc.get_base_name(Some(locale_id))
  let language = uloc.get_language_subtag(Some(base))
  let script = uloc.get_script_subtag(Some(base))
  let region = uloc.get_region_subtag(Some(base))
  case region == "" {
    True -> locale_id
    False ->
      case borrows_from_other_language(bundle, language, script) {
        False -> locale_id
        True -> replace_locale_base(locale_id, bare_locale(language, script))
      }
  }
}

fn select_supported_locale(
  bundle: bundle.Bundle,
  locale_id: String,
  matcher: LocaleMatcher,
) -> Result(String, IcuError) {
  let base = uloc.uloc_get_base_name(Some(locale_id))
  case base {
    "" -> Error(FailedToLoadLocale(locale_id))
    _ -> {
      use matched <- result.try(case matcher {
        LocaleMatcherBestFit -> best_fit_supported_locale(bundle, base)
        LocaleMatcherLookup -> Ok(lookup_supported_locale(bundle, base))
      })
      case matched {
        Some(supported) -> Ok(replace_locale_base(locale_id, supported))
        None -> Error(FailedToLoadLocale(locale_id))
      }
    }
  }
}

fn available_locale_matcher(
  bundle: bundle.Bundle,
) -> Result(localematcher.LocaleMatcher, IcuError) {
  let available =
    uloc.uloc_open_available_by_type(bundle, uloc_available_default)
  localematcher.create_locale_matcher(bundle, available.items, None)
  |> result.map_error(FailedToLoadData)
}

fn load_bundle() -> Result(bundle.Bundle, IcuError) {
  bundle.create_bundle()
  |> result.map_error(fn(error) {
    FailedToLoadData(loader.describe_error(error))
  })
}

fn scope_bundle(
  global: bundle.Bundle,
  locale_id: String,
) -> Result(bundle.Bundle, IcuError) {
  bundle.for_locale(global, locale_id)
  |> result.map_error(fn(error) {
    FailedToLoadData(loader.describe_error(error))
  })
}

fn raw_resolve_locale(
  tag: String,
  matcher: LocaleMatcher,
) -> Result(String, IcuError) {
  case tag {
    "" -> {
      use bundle <- result.try(load_bundle())
      select_supported_locale(
        bundle,
        uloc.uloc_get_default(uloc.default_locale_fallback),
        matcher,
      )
    }
    _ -> {
      use bundle <- result.try(load_bundle())
      let parsed = uloc_tag.uloc_for_language_tag(bundle, tag)
      case parsed.parsed == string.length(tag) && parsed.locale_id != "" {
        False -> Error(FailedToLoadLocale(tag))
        True ->
          case select_supported_locale(bundle, parsed.locale_id, matcher) {
            Ok(locale_id) -> Ok(locale_id)
            Error(FailedToLoadData(inner)) -> Error(FailedToLoadData(inner))
            Error(_) -> Error(FailedToLoadLocale(tag))
          }
      }
    }
  }
}

@external(erlang, "intldate_systemtz_ffi", "detect")
fn system_time_zone() -> Result(String, Nil) {
  panic as "unsupported Target"
}

fn date_formatter(
  bundle: bundle.Bundle,
  locale_id: String,
  tz: String,
  pattern: String,
) -> smpdtfmt.DateFormatter {
  let cal_type = uloc.get_calendar_type_to_use(bundle, locale_id)
  smpdtfmt.udat_open(bundle, locale_id, cal_type, tz, pattern)
}

fn raw_format(
  context: DateTimeContext,
  tz: String,
  pattern: String,
  epoch_millis: Int,
) -> String {
  let fmt = date_formatter(context.bundle, context.locale_id, tz, pattern)
  smpdtfmt.udat_format(fmt, epoch_millis)
}

fn raw_format_to_parts(
  context: DateTimeContext,
  tz: String,
  pattern: String,
  epoch_millis: Int,
) -> FormatPartsResult {
  let fmt = date_formatter(context.bundle, context.locale_id, tz, pattern)
  let result = smpdtfmt.udat_format_for_fields(fmt, epoch_millis)
  let parts =
    list.map(result.parts, fn(part) {
      FormatPart(type_: part.type_, value: part.value, source: None)
    })
  FormatPartsResult(formatted: result.formatted, parts:)
}

fn has_interval_span(result: dtitvfmt.DateIntervalFormatResult) -> Bool {
  list.any(result.parts, fn(p) { p.source != "shared" })
}

fn single_date_shared_parts(
  context: DateTimeContext,
  tz: String,
  pattern: String,
  epoch_millis: Int,
) -> FormatPartsResult {
  let single = raw_format_to_parts(context, tz, pattern, epoch_millis)
  let parts =
    list.map(single.parts, fn(p) {
      FormatPart(type_: p.type_, value: p.value, source: Some("shared"))
    })
  FormatPartsResult(formatted: single.formatted, parts:)
}

fn relative_part_type_name(type_: reldtfmt.RelativeFormatPartType) -> String {
  case type_ {
    reldtfmt.Literal -> "literal"
    reldtfmt.Integer -> "integer"
    reldtfmt.NumberField(kind) -> kind
  }
}

fn resolve_locale(
  locale: String,
  calendar: String,
  matcher: LocaleMatcher,
) -> Result(String, IcuError) {
  uncached_full_resolve_locale(locale, calendar, matcher)
}

fn uncached_full_resolve_locale(
  locale: String,
  calendar: String,
  matcher: LocaleMatcher,
) -> Result(String, IcuError) {
  use locale_id <- result.try(raw_resolve_locale(locale, matcher))
  use bundle <- result.try(load_bundle())
  case calendar {
    "" -> Ok(locale_id)
    _ ->
      case uloc.uloc_to_legacy_type(Some(bundle), "calendar", calendar) {
        None -> Error(FailedToLoadCalendar(calendar))
        Some(legacy) ->
          case uloc.set_keyword_value("calendar", Some(legacy), locale_id) {
            Error(_) -> Error(FailedToLoadCalendar(calendar))
            Ok(new_locale_id) -> Ok(new_locale_id)
          }
      }
  }
}

fn uncached_resolve_time_zone(tz: String) -> Result(String, IcuError) {
  use bundle <- result.try(load_bundle())
  let #(result, _cache) =
    zonemeta.ucal_get_canonical_time_zone_id(
      zonemeta_bundle(bundle),
      zonemeta.new_canonical_id_cache(),
      tz,
    )
  case result.is_system_id, result.canonical_id {
    True, Some("Etc/UTC") -> Ok("UTC")
    True, Some("Etc/GMT") -> Ok("UTC")
    True, Some("GMT") -> Ok("UTC")
    True, Some(canonical_id) -> Ok(canonical_id)
    _, _ -> Error(FailedToLoadTimeZone(tz))
  }
}

pub fn resolve_time_zone(
  time_zone: Option(String),
) -> Result(String, IcuError) {
  case time_zone {
    Some(tz) -> uncached_resolve_time_zone(tz)
    None -> {
      use detected <- result.try(
        system_time_zone()
        |> result.replace_error(SystemTimeZoneUnavailable),
      )
      uncached_resolve_time_zone(detected)
    }
  }
}

fn resolve_date_time_context(
  locale: String,
  calendar: String,
  matcher: LocaleMatcher,
) -> Result(DateTimeContext, IcuError) {
  use locale_id <- result.try(resolve_locale(locale, calendar, matcher))
  use global_bundle <- result.try(load_bundle())
  use scoped_bundle <- result.try(scope_bundle(global_bundle, locale_id))
  Ok(DateTimeContext(bundle: scoped_bundle, locale_id:))
}

pub fn analyze(
  locale: String,
  calendar: String,
  skeleton: String,
  matcher: LocaleMatcher,
  match_hour_field_length: Bool,
  hour12: Option(Bool),
  has_hour: Bool,
) -> Result(DateTimeAnalysis, IcuError) {
  use context <- result.try(resolve_date_time_context(locale, calendar, matcher))
  use raw_locale_id <- result.try(raw_resolve_locale(locale, matcher))

  let resolved =
    resolve_analysis(
      context,
      raw_locale_id,
      calendar,
      hour12,
      has_hour,
      skeleton,
      match_hour_field_length,
    )

  Ok(DateTimeAnalysis(
    context:,
    pattern: resolved.pattern,
    hour_cycle: resolved.hour_cycle,
    region: resolved.region,
    numbering_system: resolved.numbering_system,
    locale: resolved.locale,
    calendar: resolved.calendar,
  ))
}

type ResolvedAnalysis {
  ResolvedAnalysis(
    pattern: String,
    hour_cycle: Int,
    region: String,
    numbering_system: String,
    locale: String,
    calendar: String,
  )
}

fn resolve_analysis(
  context: DateTimeContext,
  raw_locale_id: String,
  calendar: String,
  hour12: Option(Bool),
  has_hour: Bool,
  skeleton: String,
  match_hour_field_length: Bool,
) -> ResolvedAnalysis {
  let key =
    "analysis:"
    <> context.locale_id
    <> "@"
    <> raw_locale_id
    <> "@"
    <> calendar
    <> "@"
    <> case hour12 {
      Some(True) -> "1"
      Some(False) -> "0"
      None -> "n"
    }
    <> case has_hour {
      True -> "h"
      False -> "-"
    }
    <> "@"
    <> skeleton
    <> "@"
    <> case match_hour_field_length {
      True -> "1"
      False -> "0"
    }
  case cache.get_ets(key) {
    Ok(resolved) -> resolved
    Error(_) ->
      cache.put_ets(
        key,
        compute_analysis(
          context,
          raw_locale_id,
          calendar,
          hour12,
          has_hour,
          skeleton,
          match_hour_field_length,
        ),
      )
  }
}

fn compute_analysis(
  context: DateTimeContext,
  raw_locale_id: String,
  calendar: String,
  hour12: Option(Bool),
  has_hour: Bool,
  skeleton: String,
  match_hour_field_length: Bool,
) -> ResolvedAnalysis {
  let dtpg = udatpg.udatpg_open_memo(context.bundle, context.locale_id)
  let default_hour_cycle = case udatpg.udatpg_get_default_hour_cycle(dtpg) {
    Ok(value) -> value
    Error(_) -> 2
  }
  let best =
    udatpg.udatpg_get_best_pattern_with_options(
      dtpg,
      skeleton,
      case match_hour_field_length {
        True -> udatpg.udatpg_match_hour_field_length()
        False -> 0
      },
    )
  let pattern = best.pattern

  let region = uloc.uloc_get_country(Some(context.locale_id))

  let numbering = unumsys.unumsys_open(context.bundle, context.locale_id)
  let numbering_system = case unumsys.unumsys_get_name(numbering) {
    "" -> "latn"
    name -> name
  }
  let locale_calendar = uloc.get_keyword_value(Some(raw_locale_id), "calendar")
  let include_calendar = case calendar {
    "" -> locale_calendar != ""
    _ ->
      case
        uloc.uloc_to_legacy_type(Some(context.bundle), "calendar", calendar)
      {
        Some(legacy) -> legacy == locale_calendar && locale_calendar != ""
        None -> False
      }
  }
  let locale_hour_cycle = uloc.get_keyword_value(Some(raw_locale_id), "hours")
  let include_hours = case locale_hour_cycle {
    "" -> False
    _ ->
      case hour12 {
        None -> True
        Some(want12) ->
          has_hour && is_12_hour_cycle(locale_hour_cycle) == want12
      }
  }
  let relevant_locale_keys =
    list.append(
      case include_calendar {
        True -> ["calendar"]
        False -> []
      },
      case include_hours {
        True -> ["hours", "numbers"]
        False -> ["numbers"]
      },
    )
  let resolved_locale =
    uloc.to_language_tag(
      context.bundle,
      display_locale_id(context.bundle, raw_locale_id),
      relevant_locale_keys,
    )
  let resolved_calendar =
    resolved_calendar_name(uloc.get_calendar_type_to_use(
      context.bundle,
      context.locale_id,
    ))

  ResolvedAnalysis(
    pattern:,
    hour_cycle: default_hour_cycle,
    region:,
    numbering_system:,
    locale: resolved_locale,
    calendar: resolved_calendar,
  )
}

fn is_12_hour_cycle(hour_cycle: String) -> Bool {
  hour_cycle == "h11" || hour_cycle == "h12"
}

fn resolved_calendar_name(calendar: String) -> String {
  case calendar {
    "gregorian" -> "gregory"
    "ethiopic-amete-alem" -> "ethioaa"
    other -> other
  }
}

pub fn format(
  milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(String, IcuError) {
  use context <- result.try(resolve_date_time_context(
    locale,
    calendar,
    LocaleMatcherBestFit,
  ))
  format_resolved(milliseconds, time_zone, context, pattern)
}

pub fn format_resolved(
  milliseconds: Int,
  time_zone: Option(String),
  context: DateTimeContext,
  pattern: String,
) -> Result(String, IcuError) {
  use tz <- result.try(resolve_time_zone(time_zone))
  Ok(raw_format(context, tz, pattern, milliseconds))
}

pub fn format_to_parts(
  milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(List(#(String, String)), IcuError) {
  use context <- result.try(resolve_date_time_context(
    locale,
    calendar,
    LocaleMatcherBestFit,
  ))
  format_to_parts_resolved(milliseconds, time_zone, context, pattern)
}

pub fn format_to_parts_resolved(
  milliseconds: Int,
  time_zone: Option(String),
  context: DateTimeContext,
  pattern: String,
) -> Result(List(#(String, String)), IcuError) {
  use tz <- result.try(resolve_time_zone(time_zone))
  let formatted = raw_format_to_parts(context, tz, pattern, milliseconds)
  Ok(list.map(formatted.parts, fn(part) { #(part.type_, part.value) }))
}

// gregocal.ucal_set_gregorian_change is a no-op in this port: the ported
// calendar computation is already pure proleptic Gregorian, so there is no
// Julian/Gregorian cutover to disable here.
pub fn format_range(
  from_milliseconds: Int,
  to_milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(String, IcuError) {
  use context <- result.try(resolve_date_time_context(
    locale,
    calendar,
    LocaleMatcherBestFit,
  ))
  format_range_resolved(
    from_milliseconds,
    to_milliseconds,
    time_zone,
    context,
    pattern,
  )
}

pub fn format_range_resolved(
  from_milliseconds: Int,
  to_milliseconds: Int,
  time_zone: Option(String),
  context: DateTimeContext,
  pattern: String,
) -> Result(String, IcuError) {
  use tz <- result.try(resolve_time_zone(time_zone))
  let cal_type =
    uloc.get_calendar_type_to_use(context.bundle, context.locale_id)
  let skeleton = udatpg.udatpg_get_skeleton(pattern)

  let fmt =
    dtitvfmt.udtitvfmt_open(
      context.bundle,
      context.locale_id,
      skeleton,
      tz,
      cal_type,
    )
  let wrapper =
    dtitvfmt.udtitvfmt_format_to_result(
      fmt,
      from_milliseconds,
      to_milliseconds,
      dtitvfmt.udtitvfmt_open_result(),
    )

  case dtitvfmt.udtitvfmt_result_as_value(wrapper) {
    None ->
      Ok(normalize_spaces(raw_format(context, tz, pattern, from_milliseconds)))
    Some(result) ->
      case has_interval_span(result) {
        False ->
          Ok(
            normalize_spaces(raw_format(context, tz, pattern, from_milliseconds)),
          )
        True -> Ok(result.formatted)
      }
  }
}

fn normalize_spaces(text: String) -> String {
  text
  |> string.replace("\u{00A0}", " ")
  |> string.replace("\u{202F}", " ")
}

pub fn format_range_to_parts(
  from_milliseconds: Int,
  to_milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(List(#(String, String, Option(String))), IcuError) {
  use context <- result.try(resolve_date_time_context(
    locale,
    calendar,
    LocaleMatcherBestFit,
  ))
  format_range_to_parts_resolved(
    from_milliseconds,
    to_milliseconds,
    time_zone,
    context,
    pattern,
  )
}

pub fn format_range_to_parts_resolved(
  from_milliseconds: Int,
  to_milliseconds: Int,
  time_zone: Option(String),
  context: DateTimeContext,
  pattern: String,
) -> Result(List(#(String, String, Option(String))), IcuError) {
  use tz <- result.try(resolve_time_zone(time_zone))
  let cal_type =
    uloc.get_calendar_type_to_use(context.bundle, context.locale_id)
  let skeleton = udatpg.udatpg_get_skeleton(pattern)

  let fmt =
    dtitvfmt.udtitvfmt_open(
      context.bundle,
      context.locale_id,
      skeleton,
      tz,
      cal_type,
    )
  let wrapper =
    dtitvfmt.udtitvfmt_format_to_result(
      fmt,
      from_milliseconds,
      to_milliseconds,
      dtitvfmt.udtitvfmt_open_result(),
    )

  let formatted = case dtitvfmt.udtitvfmt_result_as_value(wrapper) {
    None -> single_date_shared_parts(context, tz, pattern, from_milliseconds)
    Some(result) ->
      case has_interval_span(result) {
        False ->
          single_date_shared_parts(context, tz, pattern, from_milliseconds)
        True -> {
          let parts =
            list.map(result.parts, fn(p) {
              FormatPart(type_: p.type_, value: p.value, source: Some(p.source))
            })
          FormatPartsResult(formatted: result.formatted, parts:)
        }
      }
  }
  Ok(
    list.map(formatted.parts, fn(part) {
      #(part.type_, part.value, part.source)
    }),
  )
}

pub fn format_relative(
  value: Float,
  unit: String,
  locale: String,
  style: String,
  numeric_always: Bool,
  matcher: LocaleMatcher,
) -> Result(String, IcuError) {
  use locale_id <- result.try(raw_resolve_locale(locale, matcher))
  use global_bundle <- result.try(load_bundle())
  use bundle <- result.try(scope_bundle(global_bundle, locale_id))
  let fmt = reldtfmt.ureldatefmt_open(bundle, locale_id, style)
  let offset = int.to_float(float.round(value))
  let result = reldtfmt.ureldatefmt_open_result()
  let result = case numeric_always {
    True ->
      reldtfmt.ureldatefmt_format_numeric_to_result(fmt, offset, unit, result)
    False -> reldtfmt.ureldatefmt_format_to_result(fmt, offset, unit, result)
  }

  Ok(case reldtfmt.ureldatefmt_result_as_value(result) {
    Some(v) -> v.text
    None -> ""
  })
}

pub fn format_relative_to_parts(
  value: Float,
  unit: String,
  locale: String,
  style: String,
  numeric_always: Bool,
  matcher: LocaleMatcher,
) -> Result(List(#(String, String)), IcuError) {
  use locale_id <- result.try(raw_resolve_locale(locale, matcher))
  use global_bundle <- result.try(load_bundle())
  use bundle <- result.try(scope_bundle(global_bundle, locale_id))
  let fmt = reldtfmt.ureldatefmt_open(bundle, locale_id, style)
  let offset = int.to_float(float.round(value))
  let result = reldtfmt.ureldatefmt_open_result()
  let result = case numeric_always {
    True ->
      reldtfmt.ureldatefmt_format_numeric_to_result(fmt, offset, unit, result)
    False -> reldtfmt.ureldatefmt_format_to_result(fmt, offset, unit, result)
  }

  let formatted = case reldtfmt.ureldatefmt_result_as_value(result) {
    None -> FormatPartsResult(formatted: "", parts: [])
    Some(v) -> {
      let parts =
        list.map(v.parts, fn(p) {
          FormatPart(
            type_: relative_part_type_name(p.type_),
            value: p.value,
            source: None,
          )
        })
      FormatPartsResult(formatted: v.text, parts:)
    }
  }
  Ok(list.map(formatted.parts, fn(part) { #(part.type_, part.value) }))
}

pub fn resolve_relative_options(
  locale: String,
  matcher: LocaleMatcher,
) -> Result(#(String, String), IcuError) {
  use locale_id <- result.try(raw_resolve_locale(locale, matcher))
  use global_bundle <- result.try(load_bundle())
  use scoped_bundle <- result.try(scope_bundle(global_bundle, locale_id))
  let numbering = unumsys.unumsys_open(scoped_bundle, locale_id)
  let numbering_system = case unumsys.unumsys_get_name(numbering) {
    "" -> "latn"
    name -> name
  }
  let resolved_locale =
    uloc.to_language_tag(
      scoped_bundle,
      display_locale_id(scoped_bundle, locale_id),
      ["numbers"],
    )
  Ok(#(resolved_locale, numbering_system))
}
