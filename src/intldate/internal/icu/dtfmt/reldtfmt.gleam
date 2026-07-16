import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/numfmt/decimfmt
import intldate/internal/icu/plural/plurrule

pub type RelativeTimeUnitMap {
  RelativeTimeUnitMap(past: Dict(String, String), future: Dict(String, String))
}

pub type RelativeDateTimeData {
  RelativeDateTimeData(
    style_fallback: Dict(String, Option(String)),
    absolute: Dict(String, Dict(String, String)),
    relative_time: Dict(String, RelativeTimeUnitMap),
    now: Dict(String, String),
  )
}

pub type RelativeFormatPartType {
  Literal
  Integer
}

pub type RelativeFormatPart {
  RelativeFormatPart(
    type_: RelativeFormatPartType,
    value: String,
    start: Int,
    end: Int,
  )
}

pub type RelativeFormatResult {
  RelativeFormatResult(text: String, parts: List(RelativeFormatPart))
}

pub type RelativeDateTimeFormatter {
  RelativeDateTimeFormatter(bundle: Bundle, locale_id: String, style: String)
}

pub type RelativeDateTimeResult {
  RelativeDateTimeResult(value: Option(RelativeFormatResult))
}

pub type FieldKeyParseResult {
  FieldKeyParseResult(unit: String, style: String)
}

const unit_to_reskey = [
  #("year", "year"),
  #("quarter", "quarter"),
  #("month", "month"),
  #("week", "week"),
  #("day", "day"),
  #("hour", "hour"),
  #("minute", "minute"),
  #("second", "second"),
  #("sunday", "sun"),
  #("monday", "mon"),
  #("tuesday", "tue"),
  #("wednesday", "wed"),
  #("thursday", "thu"),
  #("friday", "fri"),
  #("saturday", "sat"),
]

const units_with_absolute = [
  "year", "quarter", "month", "week", "day", "hour", "minute", "sunday",
  "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
]

const styles = ["long", "short", "narrow"]

const cache_prefix = "relative-data:"

fn parse_field_key(key: String) -> Option(FieldKeyParseResult) {
  let #(style, base) = case string.ends_with(key, "-narrow") {
    True -> #("narrow", string.slice(key, 0, string.length(key) - 7))
    False ->
      case string.ends_with(key, "-short") {
        True -> #("short", string.slice(key, 0, string.length(key) - 6))
        False -> #("long", key)
      }
  }
  find_unit_for_reskey(unit_to_reskey, base, style)
}

fn find_unit_for_reskey(
  entries: List(#(String, String)),
  base: String,
  style: String,
) -> Option(FieldKeyParseResult) {
  case entries {
    [] -> None
    [#(unit, res_key), ..rest] ->
      case res_key == base {
        True -> Some(FieldKeyParseResult(unit:, style:))
        False -> find_unit_for_reskey(rest, base, style)
      }
  }
}

fn style_from_alias_target(alias_str: String) -> String {
  case string.ends_with(alias_str, "-narrow") {
    True -> "narrow"
    False ->
      case string.ends_with(alias_str, "-short") {
        True -> "short"
        False -> "long"
      }
  }
}

fn absolute_key(style: String, unit: String) -> String {
  style <> "|" <> unit
}

fn dict_get_or(d: Dict(String, a), key: String, default: a) -> a {
  case dict.get(d, key) {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn merge_unit_table(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  found: resource.RelativeUnitData,
) -> RelativeDateTimeData {
  let state = merge_relative_table(state, unit, style, found.relative)
  merge_relative_time_table(state, unit, style, found.past, found.future)
}

fn merge_relative_table(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  found: Dict(String, String),
) -> RelativeDateTimeData {
  let map_key = absolute_key(style, unit)
  let dest = dict_get_or(state.absolute, map_key, dict.new())
  let dest = merge_missing(dest, found)
  let state =
    RelativeDateTimeData(
      ..state,
      absolute: dict.insert(state.absolute, map_key, dest),
    )
  case unit == "second", dict.get(found, "0"), dict.get(state.now, style) {
    True, Ok(now_value), Error(_) ->
      RelativeDateTimeData(
        ..state,
        now: dict.insert(state.now, style, now_value),
      )
    _, _, _ -> state
  }
}

fn merge_relative_time_table(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  past: Dict(String, String),
  future: Dict(String, String),
) -> RelativeDateTimeData {
  let map_key = absolute_key(style, unit)
  let dest =
    dict_get_or(
      state.relative_time,
      map_key,
      RelativeTimeUnitMap(past: dict.new(), future: dict.new()),
    )
  let dest =
    RelativeTimeUnitMap(
      past: merge_missing(dest.past, past),
      future: merge_missing(dest.future, future),
    )
  RelativeDateTimeData(
    ..state,
    relative_time: dict.insert(state.relative_time, map_key, dest),
  )
}

fn merge_missing(
  dest: Dict(String, String),
  found: Dict(String, String),
) -> Dict(String, String) {
  dict.fold(found, dest, fn(acc, key, value) {
    case dict.has_key(acc, key) {
      True -> acc
      False -> dict.insert(acc, key, value)
    }
  })
}

fn empty_relative_date_time_data() -> RelativeDateTimeData {
  RelativeDateTimeData(
    style_fallback: dict.new(),
    absolute: dict.new(),
    relative_time: dict.new(),
    now: dict.new(),
  )
}

pub fn create_relative_date_time_data(
  bundle: Bundle,
  locale_id: String,
) -> RelativeDateTimeData {
  let chain =
    localechain.locale_chain(
      bundle.locale_parents,
      uloc.get_base_name(Some(locale_id)),
    )
  let locales = bundle.relative_fields_by_locale.locales
  let state = build_from_chain(locales, chain, empty_relative_date_time_data())
  fill_missing_style_fallbacks(state, styles)
}

fn build_from_chain(
  locales: Dict(String, Dict(String, resource.RelativeField)),
  chain: List(String),
  state: RelativeDateTimeData,
) -> RelativeDateTimeData {
  case chain {
    [] -> state
    [level, ..rest] -> {
      let state = case dict.get(locales, level) {
        Error(_) -> state
        Ok(fields) -> build_from_level(fields, state)
      }
      build_from_chain(locales, rest, state)
    }
  }
}

fn build_from_level(
  fields: Dict(String, resource.RelativeField),
  state: RelativeDateTimeData,
) -> RelativeDateTimeData {
  dict.fold(fields, state, fn(state, key, field) {
    let state = case field {
      resource.RelativeFieldAliasTo(alias_str) ->
        case parse_field_key(key) {
          None -> state
          Some(parsed) -> {
            let target_style = style_from_alias_target(alias_str)
            case dict.get(state.style_fallback, parsed.style) {
              Ok(_) -> state
              Error(_) ->
                RelativeDateTimeData(
                  ..state,
                  style_fallback: dict.insert(
                    state.style_fallback,
                    parsed.style,
                    Some(target_style),
                  ),
                )
            }
          }
        }
      resource.RelativeFieldValue(found) ->
        case parse_field_key(key) {
          None -> state
          Some(parsed) ->
            merge_unit_table(state, parsed.unit, parsed.style, found)
        }
    }
    state
  })
}

fn fill_missing_style_fallbacks(
  state: RelativeDateTimeData,
  remaining: List(String),
) -> RelativeDateTimeData {
  case remaining {
    [] -> state
    [style, ..rest] -> {
      let state = case dict.get(state.style_fallback, style) {
        Ok(_) -> state
        Error(_) ->
          RelativeDateTimeData(
            ..state,
            style_fallback: dict.insert(state.style_fallback, style, None),
          )
      }
      fill_missing_style_fallbacks(state, rest)
    }
  }
}

pub fn relative_date_time_data_style_chain(
  data: RelativeDateTimeData,
  style: String,
) -> List(String) {
  build_style_chain(data, style, [style])
}

fn build_style_chain(
  data: RelativeDateTimeData,
  current: String,
  acc: List(String),
) -> List(String) {
  case dict_get_or(data.style_fallback, current, None) {
    None -> list.reverse(acc)
    Some(next) ->
      case list.contains(acc, next) {
        True -> list.reverse(acc)
        False -> build_style_chain(data, next, [next, ..acc])
      }
  }
}

pub fn relative_date_time_data_lookup_absolute(
  data: RelativeDateTimeData,
  style: String,
  unit: String,
  direction_key: String,
) -> Option(String) {
  lookup_absolute_in_chain(
    data,
    unit,
    direction_key,
    relative_date_time_data_style_chain(data, style),
  )
}

fn lookup_absolute_in_chain(
  data: RelativeDateTimeData,
  unit: String,
  direction_key: String,
  chain: List(String),
) -> Option(String) {
  case chain {
    [] -> None
    [s, ..rest] ->
      case dict.get(data.absolute, absolute_key(s, unit)) {
        Error(_) -> lookup_absolute_in_chain(data, unit, direction_key, rest)
        Ok(m) ->
          case dict.get(m, direction_key) {
            Ok(value) -> Some(value)
            Error(_) ->
              lookup_absolute_in_chain(data, unit, direction_key, rest)
          }
      }
  }
}

pub fn relative_date_time_data_lookup_now(
  data: RelativeDateTimeData,
  style: String,
) -> Option(String) {
  lookup_now_in_chain(data, relative_date_time_data_style_chain(data, style))
}

fn lookup_now_in_chain(
  data: RelativeDateTimeData,
  chain: List(String),
) -> Option(String) {
  case chain {
    [] -> None
    [s, ..rest] ->
      case dict.get(data.now, s) {
        Ok(value) -> Some(value)
        Error(_) -> lookup_now_in_chain(data, rest)
      }
  }
}

pub fn relative_date_time_data_lookup_relative_time_exact(
  data: RelativeDateTimeData,
  style: String,
  unit: String,
  direction: String,
  category: String,
) -> Option(String) {
  lookup_relative_time_exact_in_chain(
    data,
    unit,
    direction,
    category,
    relative_date_time_data_style_chain(data, style),
  )
}

fn lookup_relative_time_exact_in_chain(
  data: RelativeDateTimeData,
  unit: String,
  direction: String,
  category: String,
  chain: List(String),
) -> Option(String) {
  case chain {
    [] -> None
    [s, ..rest] ->
      case dict.get(data.relative_time, absolute_key(s, unit)) {
        Error(_) ->
          lookup_relative_time_exact_in_chain(
            data,
            unit,
            direction,
            category,
            rest,
          )
        Ok(m) -> {
          let target = case direction {
            "past" -> m.past
            _ -> m.future
          }
          case dict.get(target, category) {
            Ok(value) -> Some(value)
            Error(_) ->
              lookup_relative_time_exact_in_chain(
                data,
                unit,
                direction,
                category,
                rest,
              )
          }
        }
      }
  }
}

pub fn relative_date_time_data_lookup_relative_time(
  data: RelativeDateTimeData,
  style: String,
  unit: String,
  direction: String,
  category: String,
) -> Option(String) {
  case
    relative_date_time_data_lookup_relative_time_exact(
      data,
      style,
      unit,
      direction,
      category,
    )
  {
    Some(value) -> Some(value)
    None ->
      case category == "other" {
        True -> None
        False ->
          relative_date_time_data_lookup_relative_time_exact(
            data,
            style,
            unit,
            direction,
            "other",
          )
      }
  }
}

pub fn get_data(bundle: Bundle, locale_id: String) -> RelativeDateTimeData {
  let base_name = uloc.get_base_name(Some(locale_id))
  let key = cache_prefix <> base_name
  case cache.get(key) {
    Ok(data) -> data
    Error(_) ->
      cache.put(key, create_relative_date_time_data(bundle, base_name))
  }
}

pub fn get_plural_rules(
  bundle: Bundle,
  locale_id: String,
) -> plurrule.PluralRules {
  plurrule.create_plural_rules(
    bundle,
    locale_id,
    plurrule.uplural_type_cardinal,
  )
}

fn direction_key_for_int(intoffset: Int) -> Option(String) {
  case intoffset {
    -200 -> Some("-2")
    -100 -> Some("-1")
    0 -> Some("0")
    100 -> Some("1")
    200 -> Some("2")
    _ -> None
  }
}

fn literal_part(text: String) -> RelativeFormatPart {
  RelativeFormatPart(
    type_: Literal,
    value: text,
    start: 0,
    end: string.length(text),
  )
}

pub fn format_relative(
  bundle: Bundle,
  locale_id: String,
  style: String,
  unit: String,
  offset: Float,
  always_numeric: Bool,
) -> RelativeFormatResult {
  let data = get_data(bundle, locale_id)

  let direction_key = case !always_numeric && offset >. -2.1 && offset <. 2.1 {
    False -> None
    True -> {
      let offsetx100 = offset *. 100.0
      let intoffset = case offsetx100 <. 0.0 {
        True -> float.truncate(offsetx100 -. 0.5)
        False -> float.truncate(offsetx100 +. 0.5)
      }
      direction_key_for_int(intoffset)
    }
  }

  case unit == "second" && direction_key == Some("0") {
    True ->
      case relative_date_time_data_lookup_now(data, style) {
        Some(text) -> RelativeFormatResult(text:, parts: [literal_part(text)])
        None ->
          format_numeric_tier(bundle, locale_id, data, style, unit, offset)
      }
    False ->
      case direction_key {
        Some(dk) ->
          case list.contains(units_with_absolute, unit) {
            True ->
              case
                relative_date_time_data_lookup_absolute(data, style, unit, dk)
              {
                Some(text) ->
                  RelativeFormatResult(text:, parts: [literal_part(text)])
                None ->
                  format_numeric_tier(
                    bundle,
                    locale_id,
                    data,
                    style,
                    unit,
                    offset,
                  )
              }
            False ->
              format_numeric_tier(bundle, locale_id, data, style, unit, offset)
          }
        None ->
          format_numeric_tier(bundle, locale_id, data, style, unit, offset)
      }
  }
}

fn format_numeric_tier(
  bundle: Bundle,
  locale_id: String,
  data: RelativeDateTimeData,
  style: String,
  unit: String,
  offset: Float,
) -> RelativeFormatResult {
  let is_past = offset <. 0.0 || is_negative_zero(offset)
  let direction = case is_past {
    True -> "past"
    False -> "future"
  }
  let magnitude = float.absolute_value(offset)

  let decimal_result = decimfmt.format_decimal(bundle, locale_id, magnitude)
  let num_text = decimal_result.text
  let plural_rules = get_plural_rules(bundle, locale_id)
  let category =
    plurrule.plural_rules_select(plural_rules, decimal_result.operands)

  case
    relative_date_time_data_lookup_relative_time(
      data,
      style,
      unit,
      direction,
      category,
    )
  {
    None ->
      RelativeFormatResult(text: num_text, parts: [
        RelativeFormatPart(
          type_: Integer,
          value: num_text,
          start: 0,
          end: string.length(num_text),
        ),
      ])
    Some(pattern) -> build_pattern_result(pattern, num_text)
  }
}

fn is_negative_zero(x: Float) -> Bool {
  x == 0.0 && 1.0 /. x <. 0.0
}

fn find_placeholder(s: String) -> Option(Int) {
  find_placeholder_loop(string.to_graphemes(s), 0)
}

fn find_placeholder_loop(graphemes: List(String), index: Int) -> Option(Int) {
  case graphemes {
    [] -> None
    ["{", "0", "}", ..] -> Some(index)
    [_, ..rest] -> find_placeholder_loop(rest, index + 1)
  }
}

fn build_pattern_result(
  pattern: String,
  num_text: String,
) -> RelativeFormatResult {
  case find_placeholder(pattern) {
    None -> RelativeFormatResult(text: pattern, parts: [literal_part(pattern)])
    Some(idx) -> {
      let before = string.slice(pattern, 0, idx)
      let after_start = idx + 3
      let pattern_len = string.length(pattern)
      let after = string.slice(pattern, after_start, pattern_len - after_start)
      let text = before <> num_text <> after
      let #(parts, pos) = case before {
        "" -> #([], 0)
        _ -> #([literal_part(before)], string.length(before))
      }
      let num_part =
        RelativeFormatPart(
          type_: Integer,
          value: num_text,
          start: pos,
          end: pos + string.length(num_text),
        )
      let parts = list.append(parts, [num_part])
      let pos = pos + string.length(num_text)
      let parts = case after {
        "" -> parts
        _ ->
          list.append(parts, [
            RelativeFormatPart(
              type_: Literal,
              value: after,
              start: pos,
              end: pos + string.length(after),
            ),
          ])
      }
      RelativeFormatResult(text:, parts:)
    }
  }
}

pub fn create_relative_date_time_formatter(
  bundle: Bundle,
  locale_id: String,
  style: String,
) -> RelativeDateTimeFormatter {
  RelativeDateTimeFormatter(bundle:, locale_id:, style:)
}

pub fn relative_date_time_formatter_format_to_value(
  fmt: RelativeDateTimeFormatter,
  offset: Float,
  unit: String,
) -> RelativeFormatResult {
  format_relative(fmt.bundle, fmt.locale_id, fmt.style, unit, offset, False)
}

pub fn relative_date_time_formatter_format_numeric_to_value(
  fmt: RelativeDateTimeFormatter,
  offset: Float,
  unit: String,
) -> RelativeFormatResult {
  format_relative(fmt.bundle, fmt.locale_id, fmt.style, unit, offset, True)
}

pub fn ureldatefmt_open(
  bundle: Bundle,
  locale_id: String,
  style: String,
) -> RelativeDateTimeFormatter {
  create_relative_date_time_formatter(bundle, locale_id, style)
}

pub fn ureldatefmt_open_result() -> RelativeDateTimeResult {
  RelativeDateTimeResult(value: None)
}

pub fn ureldatefmt_format_to_result(
  fmt: RelativeDateTimeFormatter,
  value: Float,
  unit: String,
  _result: RelativeDateTimeResult,
) -> RelativeDateTimeResult {
  RelativeDateTimeResult(
    value: Some(relative_date_time_formatter_format_to_value(fmt, value, unit)),
  )
}

pub fn ureldatefmt_format_numeric_to_result(
  fmt: RelativeDateTimeFormatter,
  value: Float,
  unit: String,
  _result: RelativeDateTimeResult,
) -> RelativeDateTimeResult {
  RelativeDateTimeResult(
    value: Some(relative_date_time_formatter_format_numeric_to_value(
      fmt,
      value,
      unit,
    )),
  )
}

pub fn ureldatefmt_result_as_value(
  result: RelativeDateTimeResult,
) -> Option(RelativeFormatResult) {
  result.value
}
