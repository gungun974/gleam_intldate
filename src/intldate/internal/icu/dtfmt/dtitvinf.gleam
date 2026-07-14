import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/icudata/uresimp
import intldate/internal/icu/locale/uloc

pub const pattern_char_base = 0x41

const different_field = 0x1000

const string_numeric_difference = 0x100

type IntervalFieldMap =
  Dict(String, String)

pub type DateIntervalInfo {
  DateIntervalInfo(
    bundle: Bundle,
    locale_id: String,
    cal_type: String,
    patterns: Dict(String, IntervalFieldMap),
    fallback_pattern: String,
    later_date_first: Bool,
  )
}

pub type BestSkeletonResult {
  BestSkeletonResult(best_skeleton: Option(String), difference_info: Int)
}

type IntervalFormatsRes {
  IntervalFormatsRes(res: Int, res_data: resource.ResourceData)
}

fn letter_to_field(letter: String) -> Option(String) {
  case letter {
    "G" -> Some("era")
    "y" -> Some("year")
    "M" -> Some("month")
    "d" -> Some("date")
    "a" -> Some("ampm")
    "B" -> Some("ampm")
    "h" -> Some("hour")
    "H" -> Some("hour")
    "m" -> Some("minute")
    _ -> None
  }
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

fn width_get(widths: Dict(String, Int), field: String) -> Int {
  case dict.get(widths, field) {
    Ok(value) -> value
    Error(_) -> 0
  }
}

fn width_inc(widths: Dict(String, Int), field: String) -> Dict(String, Int) {
  dict.insert(widths, field, width_get(widths, field) + 1)
}

pub fn parse_skeleton(skeleton: String) -> Dict(String, Int) {
  parse_skeleton_loop(string.to_graphemes(skeleton), dict.new())
}

fn parse_skeleton_loop(
  chars: List(String),
  width: Dict(String, Int),
) -> Dict(String, Int) {
  case chars {
    [] -> width
    [c, ..rest] -> {
      let width = case char_code(c) >= pattern_char_base {
        True -> width_inc(width, c)
        False -> width
      }
      parse_skeleton_loop(rest, width)
    }
  }
}

fn string_numeric(
  field_width: Int,
  another_field_width: Int,
  pattern_letter: String,
) -> Bool {
  case pattern_letter == "M" {
    True ->
      { field_width <= 2 && another_field_width > 2 }
      || { field_width > 2 && another_field_width <= 2 }
    False -> False
  }
}

fn table_keys_and_res(
  table: resource.ResourceTableView,
) -> List(#(String, Int)) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      table_keys_and_res_loop(get_key, get_res, 0, table.length)
    _, _ -> []
  }
}

fn table_keys_and_res_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(#(String, Int)) {
  case i >= length {
    True -> []
    False -> [
      #(get_key(i), get_res(i)),
      ..table_keys_and_res_loop(get_key, get_res, i + 1, length)
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

fn parse_interval_formats_alias_target(alias_text: String) -> Option(String) {
  case string.split_once(alias_text, "/LOCALE/calendar/") {
    Error(_) -> None
    Ok(#(_before, after)) ->
      case string.split_once(after, "/intervalFormats") {
        Error(_) -> None
        Ok(#(cal_type, "")) ->
          case cal_type == "" || string.contains(cal_type, "/") {
            True -> None
            False -> Some(cal_type)
          }
        Ok(#(_cal_type, _rest)) -> None
      }
  }
}

fn get_raw_interval_formats_res(
  level: resbund.LocaleChainEntry,
  cal_type: String,
) -> Option(IntervalFormatsRes) {
  case level.res_data {
    None -> None
    Some(res_data) -> {
      let cal_res =
        resource.get_table_item_by_key(res_data, res_data.root_res, "calendar")
      case
        cal_res == uresimp.res_bogus
        || !uresimp.ures_is_table(uresimp.res_get_type(cal_res))
      {
        True -> None
        False -> {
          let cal_type_res =
            resource.get_table_item_by_key(res_data, cal_res, cal_type)
          case
            cal_type_res == uresimp.res_bogus
            || !uresimp.ures_is_table(uresimp.res_get_type(cal_type_res))
          {
            True -> None
            False -> {
              let iv_res =
                resource.get_table_item_by_key(
                  res_data,
                  cal_type_res,
                  "intervalFormats",
                )
              case iv_res == uresimp.res_bogus {
                True -> None
                False -> Some(IntervalFormatsRes(iv_res, res_data))
              }
            }
          }
        }
      }
    }
  }
}

pub type DateIntervalInfoState {
  DateIntervalInfoState(
    patterns: Dict(String, IntervalFieldMap),
    fallback_pattern: String,
    later_date_first: Bool,
    fallback_set: Bool,
  )
}

fn apply_fallback_pattern(
  state: DateIntervalInfoState,
  pattern: String,
) -> DateIntervalInfoState {
  case string.split_once(pattern, "{0}"), string.split_once(pattern, "{1}") {
    Error(_), _ -> state
    _, Error(_) -> state
    Ok(#(before0, _)), Ok(#(before1, _)) ->
      DateIntervalInfoState(
        ..state,
        later_date_first: string.length(before0) > string.length(before1),
        fallback_pattern: pattern,
      )
  }
}

fn merge_field_map(
  existing: IntervalFieldMap,
  sub_table: resource.ResourceTableView,
  res_data: resource.ResourceData,
) -> IntervalFieldMap {
  merge_field_map_loop(existing, table_keys_and_res(sub_table), res_data)
}

fn merge_field_map_loop(
  existing: IntervalFieldMap,
  entries: List(#(String, Int)),
  res_data: resource.ResourceData,
) -> IntervalFieldMap {
  case entries {
    [] -> existing
    [#(letter, res), ..rest] ->
      case letter_to_field(letter) {
        None -> merge_field_map_loop(existing, rest, res_data)
        Some(field) ->
          case dict.has_key(existing, field) {
            True -> merge_field_map_loop(existing, rest, res_data)
            False ->
              case
                uresimp.res_get_type(res) == uresimp.ResString
                || uresimp.res_get_type(res) == uresimp.ResStringV2
              {
                False -> merge_field_map_loop(existing, rest, res_data)
                True ->
                  case resource_string_text(res_data, res) {
                    None -> merge_field_map_loop(existing, rest, res_data)
                    Some(value) ->
                      merge_field_map_loop(
                        dict.insert(existing, field, value),
                        rest,
                        res_data,
                      )
                  }
              }
          }
      }
  }
}

fn load_level(
  bundle: Bundle,
  sub_chain: List(resbund.LocaleChainEntry),
  cal_type: String,
  state: DateIntervalInfoState,
) -> DateIntervalInfoState {
  case
    resbund.get_by_path(
      bundle,
      sub_chain,
      "calendar/" <> cal_type <> "/intervalFormats",
      0,
    )
  {
    None -> state
    Some(found) -> {
      let table = resource.get_table(found.res_data, found.res)
      load_level_entries(state, table_keys_and_res(table), found.res_data)
    }
  }
}

fn load_level_entries(
  state: DateIntervalInfoState,
  entries: List(#(String, Int)),
  res_data: resource.ResourceData,
) -> DateIntervalInfoState {
  case entries {
    [] -> state
    [#(key, res), ..rest] ->
      case key {
        "fallback" ->
          case
            !state.fallback_set
            && {
              uresimp.res_get_type(res) == uresimp.ResString
              || uresimp.res_get_type(res) == uresimp.ResStringV2
            }
          {
            False -> load_level_entries(state, rest, res_data)
            True ->
              case resource_string_text(res_data, res) {
                None -> load_level_entries(state, rest, res_data)
                Some(pattern) -> {
                  let state =
                    DateIntervalInfoState(
                      ..apply_fallback_pattern(state, pattern),
                      fallback_set: True,
                    )
                  load_level_entries(state, rest, res_data)
                }
              }
          }
        _ ->
          case uresimp.ures_is_table(uresimp.res_get_type(res)) {
            False -> load_level_entries(state, rest, res_data)
            True -> {
              let existing = case dict.get(state.patterns, key) {
                Ok(m) -> m
                Error(_) -> dict.new()
              }
              let sub_table = resource.get_table(res_data, res)
              let merged = merge_field_map(existing, sub_table, res_data)
              let state =
                DateIntervalInfoState(
                  ..state,
                  patterns: dict.insert(state.patterns, key, merged),
                )
              load_level_entries(state, rest, res_data)
            }
          }
      }
  }
}

fn loaded_contains(loaded: List(String), cal_type: String) -> Bool {
  list.contains(loaded, cal_type)
}

pub fn build_date_interval_info_state(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
) -> DateIntervalInfoState {
  let chain =
    resbund.open_locale_chain(bundle, uloc.get_base_name(Some(locale_id)))

  let initial =
    DateIntervalInfoState(
      patterns: dict.new(),
      fallback_pattern: "{0} \u{2013} {1}",
      later_date_first: False,
      fallback_set: False,
    )

  build_date_interval_info_state_loop(bundle, chain, cal_type, initial, [])
}

fn build_date_interval_info_state_loop(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  cal_type: String,
  state: DateIntervalInfoState,
  loaded_calendar_types: List(String),
) -> DateIntervalInfoState {
  case loaded_contains(loaded_calendar_types, cal_type) {
    True -> state
    False -> {
      let loaded_calendar_types = [cal_type, ..loaded_calendar_types]
      let #(state, next_cal_type) =
        walk_chain_levels(bundle, chain, cal_type, state, None)
      case next_cal_type {
        None -> state
        Some(next) ->
          build_date_interval_info_state_loop(
            bundle,
            chain,
            next,
            state,
            loaded_calendar_types,
          )
      }
    }
  }
}

fn walk_chain_levels(
  bundle: Bundle,
  remaining_from_level: List(resbund.LocaleChainEntry),
  cal_type: String,
  state: DateIntervalInfoState,
  next_cal_type: Option(String),
) -> #(DateIntervalInfoState, Option(String)) {
  case remaining_from_level {
    [] -> #(state, next_cal_type)
    [level, ..rest_of_full] -> {
      case get_raw_interval_formats_res(level, cal_type) {
        None ->
          walk_chain_levels(
            bundle,
            rest_of_full,
            cal_type,
            state,
            next_cal_type,
          )
        Some(raw) ->
          case uresimp.res_get_type(raw.res) == uresimp.ResAlias {
            True -> {
              let next_cal_type = case
                resource_alias_text(raw.res_data, raw.res)
              {
                None -> next_cal_type
                Some(alias_text) ->
                  case parse_interval_formats_alias_target(alias_text) {
                    None -> next_cal_type
                    Some(target) -> Some(target)
                  }
              }
              walk_chain_levels(
                bundle,
                rest_of_full,
                cal_type,
                state,
                next_cal_type,
              )
            }
            False -> {
              let state =
                load_level(bundle, remaining_from_level, cal_type, state)
              walk_chain_levels(
                bundle,
                rest_of_full,
                cal_type,
                state,
                next_cal_type,
              )
            }
          }
      }
    }
  }
}

pub fn create_date_interval_info(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
) -> DateIntervalInfo {
  let state = build_date_interval_info_state(bundle, locale_id, cal_type)
  DateIntervalInfo(
    bundle:,
    locale_id:,
    cal_type:,
    patterns: state.patterns,
    fallback_pattern: state.fallback_pattern,
    later_date_first: state.later_date_first,
  )
}

pub fn get_interval_pattern(
  info: DateIntervalInfo,
  skeleton: String,
  field: String,
) -> String {
  case dict.get(info.patterns, skeleton) {
    Error(_) -> ""
    Ok(field_map) ->
      case dict.get(field_map, field) {
        Ok(value) -> value
        Error(_) -> ""
      }
  }
}

pub fn get_fallback_interval_pattern(info: DateIntervalInfo) -> String {
  info.fallback_pattern
}

pub fn get_default_order(info: DateIntervalInfo) -> Bool {
  info.later_date_first
}

pub fn get_best_skeleton(
  info: DateIntervalInfo,
  skeleton: String,
) -> BestSkeletonResult {
  let has_alt_chars = string_contains_any(skeleton, ["z", "k", "K", "a", "b"])
  let input_skeleton = case has_alt_chars {
    True -> replace_alternate_chars(skeleton)
    False -> skeleton
  }

  let input_width = parse_skeleton(input_skeleton)
  let candidates = dict.keys(info.patterns)
  let #(best_skeleton, best_match_distance_info) =
    find_best_skeleton_loop(
      candidates,
      input_width,
      None,
      -1,
      infinity_distance,
    )

  let best_match_distance_info = case
    has_alt_chars && best_match_distance_info != -1
  {
    True -> 2
    False -> best_match_distance_info
  }

  BestSkeletonResult(best_skeleton:, difference_info: best_match_distance_info)
}

fn string_contains_any(s: String, needles: List(String)) -> Bool {
  case needles {
    [] -> False
    [n, ..rest] ->
      case string.contains(s, n) {
        True -> True
        False -> string_contains_any(s, rest)
      }
  }
}

fn replace_alternate_chars(skeleton: String) -> String {
  skeleton
  |> string.replace("z", "v")
  |> string.replace("k", "H")
  |> string.replace("K", "h")
  |> string.replace("a", "")
  |> string.replace("b", "")
}

const infinity_distance = 999_999_999

fn find_best_skeleton_loop(
  candidates: List(String),
  input_width: Dict(String, Int),
  best_skeleton: Option(String),
  best_match_distance_info: Int,
  best_distance: Int,
) -> #(Option(String), Int) {
  case candidates {
    [] -> #(best_skeleton, best_match_distance_info)
    [candidate, ..rest] -> {
      let width = parse_skeleton(candidate)
      let fields = merge_unique_keys(dict.keys(input_width), dict.keys(width))
      let #(distance, field_difference) =
        compare_widths(input_width, width, fields, 0, 1)
      case distance < best_distance {
        True ->
          case distance == 0 {
            True -> #(Some(candidate), 0)
            False ->
              find_best_skeleton_loop(
                rest,
                input_width,
                Some(candidate),
                field_difference,
                distance,
              )
          }
        False ->
          find_best_skeleton_loop(
            rest,
            input_width,
            best_skeleton,
            best_match_distance_info,
            best_distance,
          )
      }
    }
  }
}

fn merge_unique_keys(left: List(String), right: List(String)) -> List(String) {
  merge_unique_keys_loop(left, right)
}

fn merge_unique_keys_loop(
  left: List(String),
  right: List(String),
) -> List(String) {
  case left {
    [] -> right
    [head, ..tail] ->
      case list.contains(right, head) {
        True -> merge_unique_keys_loop(tail, right)
        False -> [head, ..merge_unique_keys_loop(tail, right)]
      }
  }
}

fn compare_widths(
  input_width: Dict(String, Int),
  width: Dict(String, Int),
  fields: List(String),
  distance: Int,
  field_difference: Int,
) -> #(Int, Int) {
  case fields {
    [] -> #(distance, field_difference)
    [field, ..rest] -> {
      let input_field_width = width_get(input_width, field)
      let field_width = width_get(width, field)
      case input_field_width == field_width {
        True ->
          compare_widths(input_width, width, rest, distance, field_difference)
        False ->
          case input_field_width == 0 || field_width == 0 {
            True ->
              compare_widths(
                input_width,
                width,
                rest,
                distance + different_field,
                -1,
              )
            False ->
              case string_numeric(input_field_width, field_width, field) {
                True ->
                  compare_widths(
                    input_width,
                    width,
                    rest,
                    distance + string_numeric_difference,
                    field_difference,
                  )
                False -> {
                  let diff = case input_field_width > field_width {
                    True -> input_field_width - field_width
                    False -> field_width - input_field_width
                  }
                  compare_widths(
                    input_width,
                    width,
                    rest,
                    distance + diff,
                    field_difference,
                  )
                }
              }
          }
      }
    }
  }
}
