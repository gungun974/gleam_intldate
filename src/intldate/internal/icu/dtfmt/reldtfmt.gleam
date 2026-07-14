import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/icudata/uresimp
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

fn table_entries(table: resource.ResourceTableView) -> List(#(String, Int)) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      table_entries_loop(get_key, get_res, 0, table.length)
    _, _ -> []
  }
}

fn table_entries_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(#(String, Int)) {
  case i >= length {
    True -> []
    False -> [
      #(get_key(i), get_res(i)),
      ..table_entries_loop(get_key, get_res, i + 1, length)
    ]
  }
}

fn resource_string_text(rd: resource.ResourceData, res: Int) -> Option(String) {
  case
    resource.resource_value_get_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> Some(s.text)
    None -> None
  }
}

fn resource_alias_text(rd: resource.ResourceData, res: Int) -> Option(String) {
  case
    resource.resource_value_get_alias_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> Some(s.text)
    None -> None
  }
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
  res_data: resource.ResourceData,
  res: Int,
) -> RelativeDateTimeData {
  let sub = resource.get_table(res_data, res)
  merge_unit_table_entries(state, unit, style, res_data, table_entries(sub))
}

fn merge_unit_table_entries(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  res_data: resource.ResourceData,
  entries: List(#(String, Int)),
) -> RelativeDateTimeData {
  case entries {
    [] -> state
    [#(key, sub_res), ..rest] -> {
      let item_type = uresimp.res_get_type(sub_res)
      let state = case key == "relative" && uresimp.ures_is_table(item_type) {
        True -> merge_relative_table(state, unit, style, res_data, sub_res)
        False ->
          case key == "relativeTime" && uresimp.ures_is_table(item_type) {
            True ->
              merge_relative_time_table(state, unit, style, res_data, sub_res)
            False -> state
          }
      }
      merge_unit_table_entries(state, unit, style, res_data, rest)
    }
  }
}

fn merge_relative_table(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  res_data: resource.ResourceData,
  res: Int,
) -> RelativeDateTimeData {
  let rel_table = resource.get_table(res_data, res)
  let map_key = absolute_key(style, unit)
  let dest = dict_get_or(state.absolute, map_key, dict.new())
  let #(dest, now_entry) =
    merge_relative_entries(dest, res_data, table_entries(rel_table), unit, None)
  let state =
    RelativeDateTimeData(
      ..state,
      absolute: dict.insert(state.absolute, map_key, dest),
    )
  case now_entry {
    None -> state
    Some(now_value) ->
      case dict.get(state.now, style) {
        Ok(_) -> state
        Error(_) ->
          RelativeDateTimeData(
            ..state,
            now: dict.insert(state.now, style, now_value),
          )
      }
  }
}

fn merge_relative_entries(
  dest: Dict(String, String),
  res_data: resource.ResourceData,
  entries: List(#(String, Int)),
  unit: String,
  now_entry: Option(String),
) -> #(Dict(String, String), Option(String)) {
  case entries {
    [] -> #(dest, now_entry)
    [#(d_key, item_res), ..rest] -> {
      let item_type = uresimp.res_get_type(item_res)
      case item_type == uresimp.ResString || item_type == uresimp.ResStringV2 {
        False -> merge_relative_entries(dest, res_data, rest, unit, now_entry)
        True -> {
          let text = resource_string_text(res_data, item_res)
          case text {
            None ->
              merge_relative_entries(dest, res_data, rest, unit, now_entry)
            Some(value) -> {
              let already = dict.get(dest, d_key)
              let dest = case already {
                Ok(_) -> dest
                Error(_) -> dict.insert(dest, d_key, value)
              }
              let now_entry = case
                unit == "second" && d_key == "0" && now_entry == None
              {
                True -> Some(value)
                False -> now_entry
              }
              merge_relative_entries(dest, res_data, rest, unit, now_entry)
            }
          }
        }
      }
    }
  }
}

fn merge_relative_time_table(
  state: RelativeDateTimeData,
  unit: String,
  style: String,
  res_data: resource.ResourceData,
  res: Int,
) -> RelativeDateTimeData {
  let rt_table = resource.get_table(res_data, res)
  let map_key = absolute_key(style, unit)
  let dest =
    dict_get_or(
      state.relative_time,
      map_key,
      RelativeTimeUnitMap(past: dict.new(), future: dict.new()),
    )
  let dest =
    merge_relative_time_entries(dest, res_data, table_entries(rt_table))
  RelativeDateTimeData(
    ..state,
    relative_time: dict.insert(state.relative_time, map_key, dest),
  )
}

fn merge_relative_time_entries(
  dest: RelativeTimeUnitMap,
  res_data: resource.ResourceData,
  entries: List(#(String, Int)),
) -> RelativeTimeUnitMap {
  case entries {
    [] -> dest
    [#(pf, pf_res), ..rest] ->
      case pf == "past" || pf == "future" {
        False -> merge_relative_time_entries(dest, res_data, rest)
        True -> {
          let cat_type = uresimp.res_get_type(pf_res)
          case uresimp.ures_is_table(cat_type) {
            False -> merge_relative_time_entries(dest, res_data, rest)
            True -> {
              let cat_table = resource.get_table(res_data, pf_res)
              let target = case pf {
                "past" -> dest.past
                _ -> dest.future
              }
              let target =
                merge_category_entries(
                  target,
                  res_data,
                  table_entries(cat_table),
                )
              let dest = case pf {
                "past" -> RelativeTimeUnitMap(..dest, past: target)
                _ -> RelativeTimeUnitMap(..dest, future: target)
              }
              merge_relative_time_entries(dest, res_data, rest)
            }
          }
        }
      }
  }
}

fn merge_category_entries(
  dest: Dict(String, String),
  res_data: resource.ResourceData,
  entries: List(#(String, Int)),
) -> Dict(String, String) {
  case entries {
    [] -> dest
    [#(cat, item_res), ..rest] -> {
      let item_type = uresimp.res_get_type(item_res)
      case item_type == uresimp.ResString || item_type == uresimp.ResStringV2 {
        False -> merge_category_entries(dest, res_data, rest)
        True ->
          case dict.get(dest, cat) {
            Ok(_) -> merge_category_entries(dest, res_data, rest)
            Error(_) ->
              case resource_string_text(res_data, item_res) {
                None -> merge_category_entries(dest, res_data, rest)
                Some(value) ->
                  merge_category_entries(
                    dict.insert(dest, cat, value),
                    res_data,
                    rest,
                  )
              }
          }
      }
    }
  }
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
    resbund.open_locale_chain(bundle, uloc.get_base_name(Some(locale_id)))
  let state = build_from_chain(bundle, chain, empty_relative_date_time_data())
  fill_missing_style_fallbacks(state, styles)
}

fn build_from_chain(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  state: RelativeDateTimeData,
) -> RelativeDateTimeData {
  case chain {
    [] -> state
    [level, ..rest] -> {
      let state = case level.res_data {
        None -> state
        Some(_) -> build_from_level(bundle, level, state)
      }
      build_from_chain(bundle, rest, state)
    }
  }
}

fn build_from_level(
  bundle: Bundle,
  level: resbund.LocaleChainEntry,
  state: RelativeDateTimeData,
) -> RelativeDateTimeData {
  case resbund.get_by_path(bundle, [level], "fields", 0) {
    None -> state
    Some(found) -> {
      let table = resource.get_table(found.res_data, found.res)
      build_from_table_entries(state, found.res_data, table_entries(table))
    }
  }
}

fn build_from_table_entries(
  state: RelativeDateTimeData,
  res_data: resource.ResourceData,
  entries: List(#(String, Int)),
) -> RelativeDateTimeData {
  case entries {
    [] -> state
    [#(key, res), ..rest] -> {
      let type_ = uresimp.res_get_type(res)
      let state = case type_ == uresimp.ResAlias {
        True ->
          case parse_field_key(key) {
            None -> state
            Some(parsed) ->
              case resource_alias_text(res_data, res) {
                None -> state
                Some(alias_str) -> {
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
          }
        False ->
          case uresimp.ures_is_table(type_) {
            False -> state
            True ->
              case parse_field_key(key) {
                None -> state
                Some(parsed) ->
                  merge_unit_table(
                    state,
                    parsed.unit,
                    parsed.style,
                    res_data,
                    res,
                  )
              }
          }
      }
      build_from_table_entries(state, res_data, rest)
    }
  }
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
  create_relative_date_time_data(bundle, locale_id)
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
