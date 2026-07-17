import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{
  type Bundle, scoped_date_interval_data,
}
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc

pub const pattern_char_base = 0x41

const different_field = 0x1000

const string_numeric_difference = 0x100

type IntervalFieldMap =
  Dict(String, String)

pub type DateIntervalInfo {
  DateIntervalInfo(
    patterns: Dict(String, IntervalFieldMap),
    skeleton_widths: List(#(String, Dict(String, Int))),
    fallback_pattern: String,
    later_date_first: Bool,
  )
}

const cache_prefix = "interval-info:"

pub type BestSkeletonResult {
  BestSkeletonResult(best_skeleton: Option(String), difference_info: Int)
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
  found: Dict(String, String),
) -> IntervalFieldMap {
  dict.fold(found, existing, fn(existing, letter, value) {
    case letter_to_field(letter) {
      None -> existing
      Some(field) ->
        case dict.has_key(existing, field) {
          True -> existing
          False -> dict.insert(existing, field, value)
        }
    }
  })
}

fn merge_interval_formats(
  state: DateIntervalInfoState,
  found: resource.IntervalFormats,
) -> DateIntervalInfoState {
  let state = case state.fallback_set, found.fallback {
    False, Some(pattern) ->
      DateIntervalInfoState(
        ..apply_fallback_pattern(state, pattern),
        fallback_set: True,
      )
    _, _ -> state
  }
  let patterns =
    dict.fold(found.patterns, state.patterns, fn(acc, skeleton, fields) {
      let existing = case dict.get(acc, skeleton) {
        Ok(values) -> values
        Error(_) -> dict.new()
      }
      dict.insert(acc, skeleton, merge_field_map(existing, fields))
    })
  DateIntervalInfoState(..state, patterns:)
}

fn interval_formats_for(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  locale: String,
  cal_type: String,
) -> Option(resource.CalendarField(resource.IntervalFormats)) {
  case dict.get(locales, locale) {
    Error(_) -> None
    Ok(by_cal) ->
      case dict.get(by_cal, cal_type) {
        Error(_) -> None
        Ok(data) -> data.interval_formats
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
    localechain.locale_chain(
      bundle.locale_parents,
      uloc.get_base_name(Some(locale_id)),
    )
  let locales = scoped_date_interval_data(bundle).locales

  let initial =
    DateIntervalInfoState(
      patterns: dict.new(),
      fallback_pattern: "{0} \u{2013} {1}",
      later_date_first: False,
      fallback_set: False,
    )

  build_date_interval_info_state_loop(locales, chain, cal_type, initial, [])
}

fn build_date_interval_info_state_loop(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
  state: DateIntervalInfoState,
  loaded_calendar_types: List(String),
) -> DateIntervalInfoState {
  case loaded_contains(loaded_calendar_types, cal_type) {
    True -> state
    False -> {
      let loaded_calendar_types = [cal_type, ..loaded_calendar_types]
      let #(state, next_cal_type) =
        walk_chain_levels(locales, chain, cal_type, state, None)
      case next_cal_type {
        None -> state
        Some(next) ->
          build_date_interval_info_state_loop(
            locales,
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
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  remaining_from_level: List(String),
  cal_type: String,
  state: DateIntervalInfoState,
  next_cal_type: Option(String),
) -> #(DateIntervalInfoState, Option(String)) {
  case remaining_from_level {
    [] -> #(state, next_cal_type)
    [level, ..rest_of_full] -> {
      case interval_formats_for(locales, level, cal_type) {
        None ->
          walk_chain_levels(
            locales,
            rest_of_full,
            cal_type,
            state,
            next_cal_type,
          )
        Some(resource.CalendarAliasTo(target)) ->
          walk_chain_levels(
            locales,
            rest_of_full,
            cal_type,
            state,
            Some(target),
          )
        Some(resource.CalendarValue(found)) ->
          walk_chain_levels(
            locales,
            rest_of_full,
            cal_type,
            merge_interval_formats(state, found),
            next_cal_type,
          )
      }
    }
  }
}

pub fn create_date_interval_info(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
) -> DateIntervalInfo {
  let base_name = uloc.get_base_name(Some(locale_id))
  let key = cache_prefix <> base_name <> "@" <> cal_type
  case cache.get_ets(key) {
    Ok(info) -> info
    Error(_) ->
      cache.put_ets(
        key,
        create_uncached_date_interval_info(bundle, locale_id, cal_type),
      )
  }
}

fn create_uncached_date_interval_info(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
) -> DateIntervalInfo {
  let state = build_date_interval_info_state(bundle, locale_id, cal_type)
  DateIntervalInfo(
    patterns: state.patterns,
    skeleton_widths: state.patterns
      |> dict.keys
      |> list.map(fn(skeleton) { #(skeleton, parse_skeleton(skeleton)) }),
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
  let #(best_skeleton, best_match_distance_info) =
    find_best_skeleton_loop(
      info.skeleton_widths,
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
  candidates: List(#(String, Dict(String, Int))),
  input_width: Dict(String, Int),
  best_skeleton: Option(String),
  best_match_distance_info: Int,
  best_distance: Int,
) -> #(Option(String), Int) {
  case candidates {
    [] -> #(best_skeleton, best_match_distance_info)
    [#(candidate, width), ..rest] -> {
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
