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
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resbund
import intldate/internal/icu/locale/localematcher
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/uloc_tag
import intldate/internal/icu/locale/zonemeta
import intldate/internal/icu/numsys/unumsys

pub type IcuError {
  FailedToLoadTimeZone(inner: String)
  FailedToLoadLocale(inner: String)
  FailedToLoadCalendar(inner: String)
  SystemTimeZoneUnavailable
  Unknown(inner: String)
}

type IcuOptions {
  IcuOptions(data_path: Option(String))
}

type FormatPart {
  FormatPart(type_: String, value: String, source: Option(String))
}

type FormatPartsResult {
  FormatPartsResult(formatted: String, parts: List(FormatPart))
}

const uloc_available_default = 0

fn options() -> IcuOptions {
  IcuOptions(None)
}

fn bundle_of(options: IcuOptions) -> resbund.Bundle {
  let path = case options.data_path {
    Some(p) -> p
    None -> ""
  }
  resbund.create_bundle(path)
}

fn zonemeta_bundle(bundle: resbund.Bundle) -> zonemeta.Bundle {
  zonemeta.Bundle(data_path: bundle.data_path, open_direct: fn(name) {
    resbund.open_direct_or_panic(bundle, name)
  })
}

fn available_locale_names(bundle: resbund.Bundle) -> Dict(String, Nil) {
  let key = "available\n" <> bundle.data_path
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) -> {
      let available =
        uloc.uloc_open_available_by_type(bundle, uloc_available_default)
      cache.put(
        key,
        list.fold(available.items, dict.new(), fn(acc, name) {
          dict.insert(acc, name, Nil)
        }),
      )
    }
  }
}

fn is_locale_supported(bundle: resbund.Bundle, base: String) -> Bool {
  case dict.has_key(available_locale_names(bundle), base) {
    True -> True
    False ->
      localematcher.accept_language_with_matcher(
        available_locale_matcher(bundle),
        [base],
        False,
        "",
      )
      |> option.is_some
  }
}

fn available_locale_matcher(
  bundle: resbund.Bundle,
) -> localematcher.LocaleMatcher {
  let key = "matcher\n" <> bundle.data_path
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) -> {
      let available =
        uloc.uloc_open_available_by_type(bundle, uloc_available_default)
      cache.put(
        key,
        localematcher.create_locale_matcher(bundle, available.items, None),
      )
    }
  }
}

fn raw_resolve_locale(tag: String, options: IcuOptions) -> Result(String, Nil) {
  case tag {
    "" -> Ok(uloc.uloc_get_default(uloc.default_locale_fallback))
    _ -> {
      let bundle = bundle_of(options)
      let parsed = uloc_tag.uloc_for_language_tag(bundle, tag)
      case parsed.parsed == string.length(tag) && parsed.locale_id != "" {
        False -> Error(Nil)
        True -> {
          let is_supported = case
            uloc.uloc_get_base_name(Some(parsed.locale_id))
          {
            "" -> False
            base -> is_locale_supported(bundle, base)
          }
          case is_supported {
            False -> Error(Nil)
            True -> Ok(parsed.locale_id)
          }
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
  bundle: resbund.Bundle,
  locale_id: String,
  tz: String,
  pattern: String,
) -> smpdtfmt.DateFormatter {
  let cal_type = uloc.get_calendar_type_to_use(bundle, locale_id)
  smpdtfmt.udat_open(bundle, locale_id, cal_type, tz, pattern)
}

fn raw_format(
  locale_id: String,
  tz: String,
  pattern: String,
  epoch_millis: Int,
  options: IcuOptions,
) -> String {
  let bundle = bundle_of(options)
  let fmt = date_formatter(bundle, locale_id, tz, pattern)
  smpdtfmt.udat_format(fmt, epoch_millis)
}

fn raw_format_to_parts(
  locale_id: String,
  tz: String,
  pattern: String,
  epoch_millis: Int,
  options: IcuOptions,
) -> FormatPartsResult {
  let bundle = bundle_of(options)
  let fmt = date_formatter(bundle, locale_id, tz, pattern)
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
  locale_id: String,
  tz: String,
  pattern: String,
  epoch_millis: Int,
  options: IcuOptions,
) -> FormatPartsResult {
  let single =
    raw_format_to_parts(locale_id, tz, pattern, epoch_millis, options)
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
  }
}

fn resolve_locale(
  locale: String,
  calendar: String,
) -> Result(String, IcuError) {
  uncached_full_resolve_locale(locale, calendar)
}

fn uncached_full_resolve_locale(
  locale: String,
  calendar: String,
) -> Result(String, IcuError) {
  use locale_id <- result.try(
    raw_resolve_locale(locale, options())
    |> result.replace_error(FailedToLoadLocale(locale)),
  )
  let bundle = bundle_of(options())
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
  let bundle = bundle_of(options())
  let #(result, _cache) =
    zonemeta.ucal_get_canonical_time_zone_id(
      zonemeta_bundle(bundle),
      zonemeta.new_canonical_id_cache(),
      tz,
    )
  case result.is_system_id {
    True -> Ok(tz)
    False -> Error(FailedToLoadTimeZone(tz))
  }
}

fn resolve_time_zone(time_zone: Option(String)) -> Result(String, IcuError) {
  case time_zone {
    Some(tz) -> {
      let key = "tz\n" <> tz
      case cache.get(key) {
        Ok(cached) -> cached
        Error(_) ->
          case uncached_resolve_time_zone(tz) {
            Ok(valid) -> cache.put(key, Ok(valid))
            Error(e) -> Error(e)
          }
      }
    }
    None ->
      system_time_zone()
      |> result.replace_error(SystemTimeZoneUnavailable)
  }
}

pub fn analyze(
  locale: String,
  calendar: String,
  skeleton: String,
) -> Result(#(String, Int, String, String), IcuError) {
  use locale_id <- result.try(resolve_locale(locale, calendar))
  let bundle = bundle_of(options())

  let dtpg = udatpg.udatpg_open_memo(bundle, locale_id)
  let default_hour_cycle = case udatpg.udatpg_get_default_hour_cycle(dtpg) {
    Ok(value) -> value
    Error(_) -> 2
  }
  let best =
    udatpg.udatpg_get_best_pattern_with_options(
      dtpg,
      skeleton,
      udatpg.udatpg_match_hour_field_length(),
    )
  let pattern = best.pattern

  let region = uloc.uloc_get_country(Some(locale_id))

  let numbering = unumsys.unumsys_open(bundle, locale_id)
  let numbering_system = case unumsys.unumsys_get_name(numbering) {
    "" -> "latn"
    name -> name
  }

  Ok(#(pattern, default_hour_cycle, region, numbering_system))
}

pub fn format(
  milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(String, IcuError) {
  use locale_id <- result.try(resolve_locale(locale, calendar))
  use tz <- result.try(resolve_time_zone(time_zone))
  Ok(raw_format(locale_id, tz, pattern, milliseconds, options()))
}

pub fn format_to_parts(
  milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(List(#(String, String)), IcuError) {
  use locale_id <- result.try(resolve_locale(locale, calendar))
  use tz <- result.try(resolve_time_zone(time_zone))
  let formatted =
    raw_format_to_parts(locale_id, tz, pattern, milliseconds, options())
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
  use locale_id <- result.try(resolve_locale(locale, calendar))
  use tz <- result.try(resolve_time_zone(time_zone))
  let bundle = bundle_of(options())
  let cal_type = uloc.get_calendar_type_to_use(bundle, locale_id)
  let skeleton = udatpg.udatpg_get_skeleton(pattern)

  let fmt = dtitvfmt.udtitvfmt_open(bundle, locale_id, skeleton, tz, cal_type)
  let wrapper =
    dtitvfmt.udtitvfmt_format_to_result(
      fmt,
      from_milliseconds,
      to_milliseconds,
      dtitvfmt.udtitvfmt_open_result(),
    )

  case dtitvfmt.udtitvfmt_result_as_value(wrapper) {
    None -> Ok(raw_format(locale_id, tz, pattern, from_milliseconds, options()))
    Some(result) ->
      case has_interval_span(result) {
        False ->
          Ok(raw_format(locale_id, tz, pattern, from_milliseconds, options()))
        True -> Ok(result.formatted)
      }
  }
}

pub fn format_range_to_parts(
  from_milliseconds: Int,
  to_milliseconds: Int,
  time_zone: Option(String),
  locale: String,
  calendar: String,
  pattern: String,
) -> Result(List(#(String, String, Option(String))), IcuError) {
  use locale_id <- result.try(resolve_locale(locale, calendar))
  use tz <- result.try(resolve_time_zone(time_zone))
  let bundle = bundle_of(options())
  let cal_type = uloc.get_calendar_type_to_use(bundle, locale_id)
  let skeleton = udatpg.udatpg_get_skeleton(pattern)

  let fmt = dtitvfmt.udtitvfmt_open(bundle, locale_id, skeleton, tz, cal_type)
  let wrapper =
    dtitvfmt.udtitvfmt_format_to_result(
      fmt,
      from_milliseconds,
      to_milliseconds,
      dtitvfmt.udtitvfmt_open_result(),
    )

  let formatted = case dtitvfmt.udtitvfmt_result_as_value(wrapper) {
    None ->
      single_date_shared_parts(
        locale_id,
        tz,
        pattern,
        from_milliseconds,
        options(),
      )
    Some(result) ->
      case has_interval_span(result) {
        False ->
          single_date_shared_parts(
            locale_id,
            tz,
            pattern,
            from_milliseconds,
            options(),
          )
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
) -> Result(String, IcuError) {
  use locale_id <- result.try(
    raw_resolve_locale(locale, options())
    |> result.replace_error(FailedToLoadLocale(locale)),
  )
  let bundle = bundle_of(options())
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
) -> Result(List(#(String, String)), IcuError) {
  use locale_id <- result.try(
    raw_resolve_locale(locale, options())
    |> result.replace_error(FailedToLoadLocale(locale)),
  )
  let bundle = bundle_of(options())
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
