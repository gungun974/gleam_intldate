import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/loader
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/numfmt/decimfmt
import intldate/internal/icu/numsys/numsys

pub const udatpg_era_field = 0

pub const udatpg_year_field = 1

pub const udatpg_quarter_field = 2

pub const udatpg_month_field = 3

pub const udatpg_week_of_year_field = 4

pub const udatpg_week_of_month_field = 5

pub const udatpg_weekday_field = 6

pub const udatpg_day_of_year_field = 7

pub const udatpg_day_of_week_in_month_field = 8

pub const udatpg_day_field = 9

pub const udatpg_dayperiod_field = 10

pub const udatpg_hour_field = 11

pub const udatpg_minute_field = 12

pub const udatpg_second_field = 13

pub const udatpg_fractional_second_field = 14

pub const udatpg_zone_field = 15

pub const udatpg_field_count = 16

pub const udatpg_width_count = 3

pub const udatpg_width_appenditem = 0

pub fn udatpg_match_hour_field_length() -> Int {
  2048
}

fn udatpg_match_minute_field_length() -> Int {
  4096
}

fn udatpg_match_second_field_length() -> Int {
  8192
}

pub const udat_hour_cycle_11 = 0

pub const udat_hour_cycle_12 = 1

pub const udat_hour_cycle_23 = 2

pub const udat_hour_cycle_24 = 3

pub const udatpg_no_conflict = 0

pub const udatpg_base_conflict = 1

pub const udatpg_conflict = 2

const dt_narrow = -257

const dt_shorter = -258

const dt_short = -259

const dt_long = -260

const dt_numeric = 256

const dt_delta = 16

const none_type = 0

fn udatpg_fractional_mask() -> Int {
  16_384
}

fn udatpg_second_and_fractional_mask() -> Int {
  24_576
}

pub type DtType {
  DtType(
    pattern_char: String,
    field: Int,
    type_: Int,
    min_len: Int,
    weight: Int,
  )
}

fn dt_types() -> List(DtType) {
  [
    DtType("G", udatpg_era_field, dt_short, 1, 3),
    DtType("G", udatpg_era_field, dt_long, 4, 0),
    DtType("G", udatpg_era_field, dt_narrow, 5, 0),
    DtType("y", udatpg_year_field, dt_numeric, 1, 20),
    DtType("Y", udatpg_year_field, dt_numeric + dt_delta, 1, 20),
    DtType("u", udatpg_year_field, dt_numeric + 2 * dt_delta, 1, 20),
    DtType("r", udatpg_year_field, dt_numeric + 3 * dt_delta, 1, 20),
    DtType("U", udatpg_year_field, dt_short, 1, 3),
    DtType("U", udatpg_year_field, dt_long, 4, 0),
    DtType("U", udatpg_year_field, dt_narrow, 5, 0),
    DtType("Q", udatpg_quarter_field, dt_numeric, 1, 2),
    DtType("Q", udatpg_quarter_field, dt_short, 3, 0),
    DtType("Q", udatpg_quarter_field, dt_long, 4, 0),
    DtType("Q", udatpg_quarter_field, dt_narrow, 5, 0),
    DtType("q", udatpg_quarter_field, dt_numeric + dt_delta, 1, 2),
    DtType("q", udatpg_quarter_field, dt_short - dt_delta, 3, 0),
    DtType("q", udatpg_quarter_field, dt_long - dt_delta, 4, 0),
    DtType("q", udatpg_quarter_field, dt_narrow - dt_delta, 5, 0),
    DtType("M", udatpg_month_field, dt_numeric, 1, 2),
    DtType("M", udatpg_month_field, dt_short, 3, 0),
    DtType("M", udatpg_month_field, dt_long, 4, 0),
    DtType("M", udatpg_month_field, dt_narrow, 5, 0),
    DtType("L", udatpg_month_field, dt_numeric + dt_delta, 1, 2),
    DtType("L", udatpg_month_field, dt_short - dt_delta, 3, 0),
    DtType("L", udatpg_month_field, dt_long - dt_delta, 4, 0),
    DtType("L", udatpg_month_field, dt_narrow - dt_delta, 5, 0),
    DtType("l", udatpg_month_field, dt_numeric + dt_delta, 1, 1),
    DtType("w", udatpg_week_of_year_field, dt_numeric, 1, 2),
    DtType("W", udatpg_week_of_month_field, dt_numeric, 1, 0),
    DtType("E", udatpg_weekday_field, dt_short, 1, 3),
    DtType("E", udatpg_weekday_field, dt_long, 4, 0),
    DtType("E", udatpg_weekday_field, dt_narrow, 5, 0),
    DtType("E", udatpg_weekday_field, dt_shorter, 6, 0),
    DtType("c", udatpg_weekday_field, dt_numeric + 2 * dt_delta, 1, 2),
    DtType("c", udatpg_weekday_field, dt_short - 2 * dt_delta, 3, 0),
    DtType("c", udatpg_weekday_field, dt_long - 2 * dt_delta, 4, 0),
    DtType("c", udatpg_weekday_field, dt_narrow - 2 * dt_delta, 5, 0),
    DtType("c", udatpg_weekday_field, dt_shorter - 2 * dt_delta, 6, 0),
    DtType("e", udatpg_weekday_field, dt_numeric + dt_delta, 1, 2),
    DtType("e", udatpg_weekday_field, dt_short - dt_delta, 3, 0),
    DtType("e", udatpg_weekday_field, dt_long - dt_delta, 4, 0),
    DtType("e", udatpg_weekday_field, dt_narrow - dt_delta, 5, 0),
    DtType("e", udatpg_weekday_field, dt_shorter - dt_delta, 6, 0),
    DtType("d", udatpg_day_field, dt_numeric, 1, 2),
    DtType("g", udatpg_day_field, dt_numeric + dt_delta, 1, 20),
    DtType("D", udatpg_day_of_year_field, dt_numeric, 1, 3),
    DtType("F", udatpg_day_of_week_in_month_field, dt_numeric, 1, 0),
    DtType("a", udatpg_dayperiod_field, dt_short, 1, 3),
    DtType("a", udatpg_dayperiod_field, dt_long, 4, 0),
    DtType("a", udatpg_dayperiod_field, dt_narrow, 5, 0),
    DtType("b", udatpg_dayperiod_field, dt_short - dt_delta, 1, 3),
    DtType("b", udatpg_dayperiod_field, dt_long - dt_delta, 4, 0),
    DtType("b", udatpg_dayperiod_field, dt_narrow - dt_delta, 5, 0),
    DtType("B", udatpg_dayperiod_field, dt_short - 3 * dt_delta, 1, 3),
    DtType("B", udatpg_dayperiod_field, dt_long - 3 * dt_delta, 4, 0),
    DtType("B", udatpg_dayperiod_field, dt_narrow - 3 * dt_delta, 5, 0),
    DtType("H", udatpg_hour_field, dt_numeric + 10 * dt_delta, 1, 2),
    DtType("k", udatpg_hour_field, dt_numeric + 11 * dt_delta, 1, 2),
    DtType("h", udatpg_hour_field, dt_numeric, 1, 2),
    DtType("K", udatpg_hour_field, dt_numeric + dt_delta, 1, 2),
    DtType("J", udatpg_hour_field, dt_numeric + 5 * dt_delta, 1, 2),
    DtType("j", udatpg_hour_field, dt_numeric + 6 * dt_delta, 1, 6),
    DtType("C", udatpg_hour_field, dt_numeric + 7 * dt_delta, 1, 6),
    DtType("m", udatpg_minute_field, dt_numeric, 1, 2),
    DtType("s", udatpg_second_field, dt_numeric, 1, 2),
    DtType("A", udatpg_second_field, dt_numeric + dt_delta, 1, 1000),
    DtType("S", udatpg_fractional_second_field, dt_numeric, 1, 1000),
    DtType("v", udatpg_zone_field, dt_short - 2 * dt_delta, 1, 0),
    DtType("v", udatpg_zone_field, dt_long - 2 * dt_delta, 4, 0),
    DtType("z", udatpg_zone_field, dt_short, 1, 3),
    DtType("z", udatpg_zone_field, dt_long, 4, 0),
    DtType("Z", udatpg_zone_field, dt_narrow - dt_delta, 1, 3),
    DtType("Z", udatpg_zone_field, dt_long - dt_delta, 4, 0),
    DtType("Z", udatpg_zone_field, dt_short - dt_delta, 5, 0),
    DtType("O", udatpg_zone_field, dt_short - dt_delta, 1, 0),
    DtType("O", udatpg_zone_field, dt_long - dt_delta, 4, 0),
    DtType("V", udatpg_zone_field, dt_short - dt_delta, 1, 0),
    DtType("V", udatpg_zone_field, dt_long - dt_delta, 2, 0),
    DtType("V", udatpg_zone_field, dt_long - 1 - dt_delta, 3, 0),
    DtType("V", udatpg_zone_field, dt_long - 2 - dt_delta, 4, 0),
    DtType("X", udatpg_zone_field, dt_narrow - dt_delta, 1, 0),
    DtType("X", udatpg_zone_field, dt_short - dt_delta, 2, 0),
    DtType("X", udatpg_zone_field, dt_long - dt_delta, 4, 0),
    DtType("x", udatpg_zone_field, dt_narrow - dt_delta, 1, 0),
    DtType("x", udatpg_zone_field, dt_short - dt_delta, 2, 0),
    DtType("x", udatpg_zone_field, dt_long - dt_delta, 4, 0),
  ]
}

const cldr_field_append = [
  "Era", "Year", "Quarter", "Month", "Week", "*", "Day-Of-Week", "*", "*", "Day",
  "*", "Hour", "Minute", "Second", "*", "Timezone",
]

const cldr_field_name = [
  "era", "year", "quarter", "month", "week", "weekOfMonth", "weekday",
  "dayOfYear", "weekdayOfMonth", "day", "dayperiod", "hour", "minute", "second",
  "*", "zone",
]

const udatpg_item_format = "{0} \u{251c}{2}: {1}\u{2524}"

const max_dt_token = 50

const kdtpg_no_flags = 0

const kdtpg_fix_fractional_seconds = 1

const kdtpg_skeleton_uses_cap_j = 2

fn field_string_dict(default: String) -> Dict(Int, String) {
  field_string_dict_loop(default, 0, dict.new())
}

fn field_string_dict_loop(
  default: String,
  field: Int,
  acc: Dict(Int, String),
) -> Dict(Int, String) {
  case field >= udatpg_field_count {
    True -> acc
    False ->
      field_string_dict_loop(
        default,
        field + 1,
        dict.insert(acc, field, default),
      )
  }
}

fn field_int_dict(default: Int) -> Dict(Int, Int) {
  field_int_dict_loop(default, 0, dict.new())
}

fn field_int_dict_loop(
  default: Int,
  field: Int,
  acc: Dict(Int, Int),
) -> Dict(Int, Int) {
  case field >= udatpg_field_count {
    True -> acc
    False ->
      field_int_dict_loop(default, field + 1, dict.insert(acc, field, default))
  }
}

fn width_string_dict(default: String) -> Dict(Int, String) {
  width_string_dict_loop(default, 0, dict.new())
}

fn width_string_dict_loop(
  default: String,
  width: Int,
  acc: Dict(Int, String),
) -> Dict(Int, String) {
  case width >= udatpg_width_count {
    True -> acc
    False ->
      width_string_dict_loop(
        default,
        width + 1,
        dict.insert(acc, width, default),
      )
  }
}

fn style_string_dict(default: String) -> Dict(Int, String) {
  style_string_dict_loop(default, 0, dict.new())
}

fn style_string_dict_loop(
  default: String,
  style: Int,
  acc: Dict(Int, String),
) -> Dict(Int, String) {
  case style > 3 {
    True -> acc
    False ->
      style_string_dict_loop(
        default,
        style + 1,
        dict.insert(acc, style, default),
      )
  }
}

fn dict_string_get(
  items: Dict(Int, String),
  index: Int,
  default: String,
) -> String {
  case dict.get(items, index) {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn dict_int_get(items: Dict(Int, Int), index: Int, default: Int) -> Int {
  case dict.get(items, index) {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn codepoint_at_loop(cps: List(a), index: Int) -> Result(a, Nil) {
  case cps, index {
    [], _ -> Error(Nil)
    [head, ..], 0 -> Ok(head)
    [_, ..tail], _ -> codepoint_at_loop(tail, index - 1)
  }
}

fn codepoint_at(s: String, index: Int) -> Int {
  case codepoint_at_loop(string.to_utf_codepoints(s), index) {
    Error(_) -> 0
    Ok(cp) -> string.utf_codepoint_to_int(cp)
  }
}

fn char_at(s: String, index: Int) -> String {
  case codepoint_at_loop(string.to_utf_codepoints(s), index) {
    Error(_) -> ""
    Ok(cp) -> string.from_utf_codepoints([cp])
  }
}

fn char_len(s: String) -> Int {
  list.length(string.to_utf_codepoints(s))
}

fn is_ascii_upper(c: String) -> Bool {
  let cp = codepoint_at(c, 0)
  cp >= 65 && cp <= 90
}

fn is_ascii_lower(c: String) -> Bool {
  let cp = codepoint_at(c, 0)
  cp >= 97 && cp <= 122
}

fn get_header_index(base_char: String) -> Int {
  case is_ascii_upper(base_char) {
    True -> codepoint_at(base_char, 0) - 65
    False ->
      case is_ascii_lower(base_char) {
        True -> 26 + codepoint_at(base_char, 0) - 97
        False -> -1
      }
  }
}

pub type FormatParser {
  FormatParser(items: List(String), item_number: Int, index: Dict(Int, String))
}

pub fn create_format_parser() -> FormatParser {
  FormatParser(items: [], item_number: 0, index: dict.new())
}

fn format_parser_item_at(fp: FormatParser, index: Int) -> String {
  dict_string_get(fp.index, index, "")
}

fn is_ascii_letter_codepoint(cp: Int) -> Bool {
  { cp >= 65 && cp <= 90 } || { cp >= 97 && cp <= 122 }
}

fn codepoint_int_to_string(cp: Int) -> String {
  case string.utf_codepoint(cp) {
    Ok(codepoint) -> string.from_utf_codepoints([codepoint])
    Error(_) -> ""
  }
}

fn count_matching_run(
  chars: List(Int),
  target: Int,
  acc: Int,
) -> #(Int, List(Int)) {
  case chars {
    [c, ..rest] if c == target -> count_matching_run(rest, target, acc + 1)
    _ -> #(acc, chars)
  }
}

fn build_item_index(items: List(String)) -> Dict(Int, String) {
  items
  |> list.index_map(fn(item, i) { #(i, item) })
  |> dict.from_list
}

fn finish_format_parser(items: List(String), count: Int) -> FormatParser {
  let ordered = list.reverse(items)
  FormatParser(
    items: ordered,
    item_number: count,
    index: build_item_index(ordered),
  )
}

pub fn format_parser_set(pattern: String) -> FormatParser {
  let chars =
    string.to_utf_codepoints(pattern)
    |> list.map(string.utf_codepoint_to_int)
  format_parser_set_loop(chars, [], 0)
}

fn format_parser_set_loop(
  chars: List(Int),
  items: List(String),
  count: Int,
) -> FormatParser {
  case count >= max_dt_token {
    True -> finish_format_parser(items, count)
    False ->
      case chars {
        [] -> finish_format_parser(items, count)
        [c, ..rest] ->
          case is_ascii_letter_codepoint(c) {
            False ->
              format_parser_set_loop(
                rest,
                [codepoint_int_to_string(c), ..items],
                count + 1,
              )
            True -> {
              let #(run_len, rest_after) = count_matching_run(rest, c, 1)
              let item = string.repeat(codepoint_int_to_string(c), run_len)
              format_parser_set_loop(rest_after, [item, ..items], count + 1)
            }
          }
      }
  }
}

pub fn get_canonical_index(s: String, strict: Bool) -> Int {
  let len = char_len(s)
  case len == 0 {
    True -> -1
    False -> {
      let ch = char_at(s, 0)
      case get_canonical_index_check_uniform(s, ch, 1, len) {
        False -> -1
        True -> get_canonical_index_loop(dt_types(), 0, ch, len, -1, strict)
      }
    }
  }
}

fn get_canonical_index_check_uniform(
  s: String,
  ch: String,
  l: Int,
  len: Int,
) -> Bool {
  case l >= len {
    True -> True
    False ->
      case ch != char_at(s, l) {
        True -> False
        False -> get_canonical_index_check_uniform(s, ch, l + 1, len)
      }
  }
}

fn get_canonical_index_loop(
  rows: List(DtType),
  i: Int,
  ch: String,
  len: Int,
  best_row: Int,
  strict: Bool,
) -> Int {
  case rows {
    [] ->
      case strict {
        True -> -1
        False -> best_row
      }
    [row, ..rest] ->
      case row.pattern_char != ch {
        True -> get_canonical_index_loop(rest, i + 1, ch, len, best_row, strict)
        False ->
          case rest {
            [] -> i
            [next, ..] ->
              case next.pattern_char != row.pattern_char {
                True -> i
                False ->
                  case next.min_len <= len {
                    True ->
                      get_canonical_index_loop(rest, i + 1, ch, len, i, strict)
                    False -> i
                  }
              }
          }
      }
  }
}

fn dt_type_at(index: Int) -> Option(DtType) {
  case index < 0 {
    True -> None
    False ->
      case list.drop(dt_types(), index) |> list.first {
        Ok(row) -> Some(row)
        Error(_) -> None
      }
  }
}

pub fn is_quote_literal(s: String) -> Bool {
  char_at(s, 0) == "'"
}

pub type QuoteLiteralResult {
  QuoteLiteralResult(quote: String, item_index: Int)
}

pub fn format_parser_get_quote_literal(
  fp: FormatParser,
  item_index: Int,
) -> QuoteLiteralResult {
  case char_at(format_parser_item_at(fp, item_index), 0) == "'" {
    True ->
      format_parser_get_quote_literal_loop(
        fp,
        item_index + 1,
        format_parser_item_at(fp, item_index),
      )
    False -> format_parser_get_quote_literal_loop(fp, item_index, "")
  }
}

fn format_parser_get_quote_literal_loop(
  fp: FormatParser,
  i: Int,
  quote: String,
) -> QuoteLiteralResult {
  case i >= fp.item_number {
    True -> QuoteLiteralResult(quote, i)
    False -> {
      let item = format_parser_item_at(fp, i)
      case char_at(item, 0) == "'" {
        True -> {
          let next = format_parser_item_at(fp, i + 1)
          case i + 1 < fp.item_number && char_at(next, 0) == "'" {
            True ->
              format_parser_get_quote_literal_loop(
                fp,
                i + 2,
                quote <> item <> next,
              )
            False -> QuoteLiteralResult(quote <> item, i)
          }
        }
        False -> format_parser_get_quote_literal_loop(fp, i + 1, quote <> item)
      }
    }
  }
}

pub fn format_parser_is_pattern_separator(
  fp: FormatParser,
  field: String,
) -> Bool {
  format_parser_is_pattern_separator_loop(fp, field, 0, char_len(field))
}

fn format_parser_is_pattern_separator_loop(
  fp: FormatParser,
  field: String,
  i: Int,
  len: Int,
) -> Bool {
  case i >= len {
    True -> True
    False -> {
      let c = char_at(field, i)
      case
        c == "'"
        || c == "\\"
        || c == " "
        || c == ":"
        || c == "\""
        || c == ","
        || c == "-"
        || char_at(format_parser_item_at(fp, i), 0) == "."
      {
        True -> format_parser_is_pattern_separator_loop(fp, field, i + 1, len)
        False -> False
      }
    }
  }
}

const max_pattern_entries = 52

pub type SkeletonFields {
  SkeletonFields(chars: Dict(Int, String), lengths: Dict(Int, Int))
}

pub fn create_skeleton_fields() -> SkeletonFields {
  SkeletonFields(chars: field_string_dict("\u{0}"), lengths: field_int_dict(0))
}

pub fn skeleton_fields_clear_field(
  sf: SkeletonFields,
  field: Int,
) -> SkeletonFields {
  SkeletonFields(
    chars: dict.insert(sf.chars, field, "\u{0}"),
    lengths: dict.insert(sf.lengths, field, 0),
  )
}

pub fn skeleton_fields_get_field_char(
  sf: SkeletonFields,
  field: Int,
) -> String {
  dict_string_get(sf.chars, field, "\u{0}")
}

pub fn skeleton_fields_get_field_length(sf: SkeletonFields, field: Int) -> Int {
  dict_int_get(sf.lengths, field, 0)
}

pub fn skeleton_fields_populate(
  sf: SkeletonFields,
  field: Int,
  value: String,
  repeat_count: Int,
) -> SkeletonFields {
  SkeletonFields(
    chars: dict.insert(sf.chars, field, value),
    lengths: dict.insert(sf.lengths, field, repeat_count),
  )
}

pub fn skeleton_fields_populate_from_value(
  sf: SkeletonFields,
  field: Int,
  value: String,
) -> SkeletonFields {
  skeleton_fields_populate(sf, field, char_at(value, 0), char_len(value))
}

pub fn skeleton_fields_is_field_empty(sf: SkeletonFields, field: Int) -> Bool {
  dict_int_get(sf.lengths, field, 0) == 0
}

pub fn skeleton_fields_append_to(
  sf: SkeletonFields,
  string_in: String,
) -> String {
  skeleton_fields_append_to_loop(sf, string_in, 0)
}

fn skeleton_fields_append_to_loop(
  sf: SkeletonFields,
  string_in: String,
  i: Int,
) -> String {
  case i >= udatpg_field_count {
    True -> string_in
    False ->
      skeleton_fields_append_to_loop(
        sf,
        skeleton_fields_append_field_to(sf, i, string_in),
        i + 1,
      )
  }
}

pub fn skeleton_fields_append_field_to(
  sf: SkeletonFields,
  field: Int,
  string_in: String,
) -> String {
  string_in
  <> string.repeat(
    dict_string_get(sf.chars, field, "\u{0}"),
    times: dict_int_get(sf.lengths, field, 0),
  )
}

pub fn skeleton_fields_get_first_char(sf: SkeletonFields) -> String {
  skeleton_fields_get_first_char_loop(sf, 0)
}

fn skeleton_fields_get_first_char_loop(sf: SkeletonFields, i: Int) -> String {
  case i >= udatpg_field_count {
    True -> "\u{0}"
    False ->
      case dict_int_get(sf.lengths, i, 0) != 0 {
        True -> dict_string_get(sf.chars, i, "\u{0}")
        False -> skeleton_fields_get_first_char_loop(sf, i + 1)
      }
  }
}

pub fn skeleton_fields_equals(
  sf: SkeletonFields,
  other: SkeletonFields,
) -> Bool {
  skeleton_fields_equals_loop(sf, other, 0)
}

fn skeleton_fields_equals_loop(
  sf: SkeletonFields,
  other: SkeletonFields,
  i: Int,
) -> Bool {
  case i >= udatpg_field_count {
    True -> True
    False ->
      case
        dict_string_get(sf.chars, i, "\u{0}")
        != dict_string_get(other.chars, i, "\u{0}")
        || dict_int_get(sf.lengths, i, 0) != dict_int_get(other.lengths, i, 0)
      {
        True -> False
        False -> skeleton_fields_equals_loop(sf, other, i + 1)
      }
  }
}

pub type PtnSkeleton {
  PtnSkeleton(
    type_: Dict(Int, Int),
    type_vector: FieldTypes,
    original: SkeletonFields,
    base_original: SkeletonFields,
    added_default_day_period: Bool,
  )
}

pub type FieldTypes {
  FieldTypes(
    era: Int,
    year: Int,
    quarter: Int,
    month: Int,
    week_of_year: Int,
    week_of_month: Int,
    weekday: Int,
    day_of_year: Int,
    day_of_week_in_month: Int,
    day: Int,
    dayperiod: Int,
    hour: Int,
    minute: Int,
    second: Int,
    fractional_second: Int,
    zone: Int,
  )
}

fn field_types_of(types: Dict(Int, Int)) -> FieldTypes {
  FieldTypes(
    era: dict_int_get(types, 0, 0),
    year: dict_int_get(types, 1, 0),
    quarter: dict_int_get(types, 2, 0),
    month: dict_int_get(types, 3, 0),
    week_of_year: dict_int_get(types, 4, 0),
    week_of_month: dict_int_get(types, 5, 0),
    weekday: dict_int_get(types, 6, 0),
    day_of_year: dict_int_get(types, 7, 0),
    day_of_week_in_month: dict_int_get(types, 8, 0),
    day: dict_int_get(types, 9, 0),
    dayperiod: dict_int_get(types, 10, 0),
    hour: dict_int_get(types, 11, 0),
    minute: dict_int_get(types, 12, 0),
    second: dict_int_get(types, 13, 0),
    fractional_second: dict_int_get(types, 14, 0),
    zone: dict_int_get(types, 15, 0),
  )
}

pub fn create_ptn_skeleton() -> PtnSkeleton {
  let types = field_int_dict(0)
  PtnSkeleton(
    type_: types,
    type_vector: field_types_of(types),
    original: create_skeleton_fields(),
    base_original: create_skeleton_fields(),
    added_default_day_period: False,
  )
}

pub fn ptn_skeleton_copy_from(other: PtnSkeleton) -> PtnSkeleton {
  PtnSkeleton(
    type_: other.type_,
    type_vector: other.type_vector,
    original: other.original,
    base_original: other.base_original,
    added_default_day_period: other.added_default_day_period,
  )
}

pub fn ptn_skeleton_clear() -> PtnSkeleton {
  create_ptn_skeleton()
}

fn remove_default_day_period(result: String, added: Bool) -> String {
  case added {
    False -> result
    True ->
      case string.split_once(result, "a") {
        Error(_) -> result
        Ok(#(before, after)) -> before <> after
      }
  }
}

pub fn ptn_skeleton_get_skeleton(ps: PtnSkeleton) -> String {
  remove_default_day_period(
    skeleton_fields_append_to(ps.original, ""),
    ps.added_default_day_period,
  )
}

pub fn ptn_skeleton_get_first_char(ps: PtnSkeleton) -> String {
  skeleton_fields_get_first_char(ps.base_original)
}

pub type DistanceInfo {
  DistanceInfo(missing_field_mask: Int, extra_field_mask: Int)
}

pub fn create_distance_info() -> DistanceInfo {
  DistanceInfo(missing_field_mask: 0, extra_field_mask: 0)
}

pub fn distance_info_clear() -> DistanceInfo {
  create_distance_info()
}

pub fn distance_info_set_to(other: DistanceInfo) -> DistanceInfo {
  DistanceInfo(
    missing_field_mask: other.missing_field_mask,
    extra_field_mask: other.extra_field_mask,
  )
}

pub fn distance_info_add_missing(di: DistanceInfo, field: Int) -> DistanceInfo {
  DistanceInfo(
    missing_field_mask: int.bitwise_or(
      di.missing_field_mask,
      int.bitwise_shift_left(1, field),
    ),
    extra_field_mask: di.extra_field_mask,
  )
}

pub fn distance_info_add_extra(di: DistanceInfo, field: Int) -> DistanceInfo {
  DistanceInfo(
    missing_field_mask: di.missing_field_mask,
    extra_field_mask: int.bitwise_or(
      di.extra_field_mask,
      int.bitwise_shift_left(1, field),
    ),
  )
}

pub type DateTimeMatcher {
  DateTimeMatcher(skeleton: PtnSkeleton)
}

pub fn create_date_time_matcher() -> DateTimeMatcher {
  DateTimeMatcher(skeleton: create_ptn_skeleton())
}

pub fn date_time_matcher_copy_from(
  new_skeleton: Option(PtnSkeleton),
) -> DateTimeMatcher {
  case new_skeleton {
    Some(s) -> DateTimeMatcher(skeleton: ptn_skeleton_copy_from(s))
    None -> DateTimeMatcher(skeleton: ptn_skeleton_clear())
  }
}

pub fn date_time_matcher_equals(
  dtm: DateTimeMatcher,
  other: Option(DateTimeMatcher),
) -> Bool {
  case other {
    None -> False
    Some(o) ->
      skeleton_fields_equals(dtm.skeleton.original, o.skeleton.original)
  }
}

pub fn date_time_matcher_get_field_mask(dtm: DateTimeMatcher) -> Int {
  date_time_matcher_get_field_mask_loop(dtm.skeleton.type_, 0, 0)
}

fn date_time_matcher_get_field_mask_loop(
  types: Dict(Int, Int),
  i: Int,
  acc: Int,
) -> Int {
  case i >= udatpg_field_count {
    True -> acc
    False -> {
      let acc = case dict_int_get(types, i, 0) != 0 {
        True -> int.bitwise_or(acc, int.bitwise_shift_left(1, i))
        False -> acc
      }
      date_time_matcher_get_field_mask_loop(types, i + 1, acc)
    }
  }
}

pub fn date_time_matcher_get_skeleton_ptr(dtm: DateTimeMatcher) -> PtnSkeleton {
  dtm.skeleton
}

pub fn date_time_matcher_get_base_pattern(dtm: DateTimeMatcher) -> String {
  skeleton_fields_append_to(dtm.skeleton.base_original, "")
}

pub fn date_time_matcher_get_distance(
  dtm: DateTimeMatcher,
  other: DateTimeMatcher,
  include_mask: Int,
) -> #(Int, DistanceInfo) {
  field_types_distance(
    dtm.skeleton.type_vector,
    other.skeleton.type_vector,
    include_mask,
    0x7fffffff,
  )
}

fn date_time_matcher_get_distance_bounded(
  dtm: DateTimeMatcher,
  other: DateTimeMatcher,
  include_mask: Int,
  limit: Int,
) -> #(Int, DistanceInfo) {
  field_types_distance(
    dtm.skeleton.type_vector,
    other.skeleton.type_vector,
    include_mask,
    limit,
  )
}

@external(erlang, "intldate_dtpg_ffi", "distance")
fn field_types_distance(
  _mine: FieldTypes,
  _theirs: FieldTypes,
  _include_mask: Int,
  _limit: Int,
) -> #(Int, DistanceInfo) {
  panic as "unsupported Target"
}

pub type PtnElem {
  PtnElem(
    base_pattern: String,
    skeleton: PtnSkeleton,
    pattern: String,
    skeleton_was_specified: Bool,
  )
}

pub type PatternMap {
  PatternMap(boot: Dict(Int, List(PtnElem)), all_elems: List(PtnElem))
}

pub fn create_pattern_map() -> PatternMap {
  PatternMap(boot: pattern_map_boot(), all_elems: [])
}

fn pattern_map_boot() -> Dict(Int, List(PtnElem)) {
  pattern_map_boot_loop(0, dict.new())
}

fn pattern_map_boot_loop(
  index: Int,
  acc: Dict(Int, List(PtnElem)),
) -> Dict(Int, List(PtnElem)) {
  case index >= max_pattern_entries {
    True -> acc
    False -> pattern_map_boot_loop(index + 1, dict.insert(acc, index, []))
  }
}

pub fn pattern_map_get_header(
  pm: PatternMap,
  base_char: String,
) -> List(PtnElem) {
  case get_header_index(base_char) {
    idx if idx < 0 -> []
    idx ->
      case dict.get(pm.boot, idx) {
        Ok(bucket) -> bucket
        Error(_) -> []
      }
  }
}

fn pattern_map_get_duplicate_elem(
  base_pattern: String,
  skeleton: PtnSkeleton,
  bucket: List(PtnElem),
) -> Option(PtnElem) {
  case bucket {
    [] -> None
    [elem, ..rest] ->
      case
        base_pattern == elem.base_pattern
        && elem.skeleton.type_ == skeleton.type_
      {
        True -> Some(elem)
        False -> pattern_map_get_duplicate_elem(base_pattern, skeleton, rest)
      }
  }
}

fn list_replace_first(
  list: List(PtnElem),
  target: PtnElem,
  replacement: PtnElem,
) -> List(PtnElem) {
  case list {
    [] -> []
    [elem, ..rest] ->
      case elem == target {
        True -> [replacement, ..rest]
        False -> [elem, ..list_replace_first(rest, target, replacement)]
      }
  }
}

pub fn pattern_map_add(
  pm: PatternMap,
  base_pattern: String,
  skeleton: PtnSkeleton,
  value: String,
  skeleton_was_specified: Bool,
) -> PatternMap {
  let idx = get_header_index(char_at(base_pattern, 0))
  let bucket = pattern_map_get_header(pm, char_at(base_pattern, 0))
  case bucket {
    [] -> {
      let new_elem =
        PtnElem(base_pattern, skeleton, value, skeleton_was_specified)
      PatternMap(boot: dict.insert(pm.boot, idx, [new_elem]), all_elems: [])
    }
    _ ->
      case pattern_map_get_duplicate_elem(base_pattern, skeleton, bucket) {
        None -> {
          let new_elem =
            PtnElem(base_pattern, skeleton, value, skeleton_was_specified)
          PatternMap(
            boot: dict.insert(pm.boot, idx, list.append(bucket, [new_elem])),
            all_elems: [],
          )
        }
        Some(dup) -> {
          let replacement =
            PtnElem(
              dup.base_pattern,
              dup.skeleton,
              value,
              skeleton_was_specified,
            )
          PatternMap(
            boot: dict.insert(
              pm.boot,
              idx,
              list_replace_first(bucket, dup, replacement),
            ),
            all_elems: [],
          )
        }
      }
  }
}

pub type PatternResult {
  PatternResult(pattern: String, skeleton_was_specified: Bool)
}

pub fn pattern_map_get_pattern_from_base_pattern(
  pm: PatternMap,
  base_pattern: String,
) -> Option(PatternResult) {
  pattern_map_get_pattern_from_base_pattern_loop(
    pattern_map_get_header(pm, char_at(base_pattern, 0)),
    base_pattern,
  )
}

fn pattern_map_get_pattern_from_base_pattern_loop(
  bucket: List(PtnElem),
  base_pattern: String,
) -> Option(PatternResult) {
  case bucket {
    [] -> None
    [elem, ..rest] ->
      case base_pattern == elem.base_pattern {
        True -> Some(PatternResult(elem.pattern, elem.skeleton_was_specified))
        False ->
          pattern_map_get_pattern_from_base_pattern_loop(rest, base_pattern)
      }
  }
}

pub type SkeletonResult {
  SkeletonResult(
    pattern: Option(String),
    specified_skeleton: Option(PtnSkeleton),
  )
}

pub fn pattern_map_get_pattern_from_skeleton(
  pm: PatternMap,
  skeleton: PtnSkeleton,
  want_specified_skeleton: Bool,
) -> SkeletonResult {
  let bucket = pattern_map_get_header(pm, ptn_skeleton_get_first_char(skeleton))
  pattern_map_get_pattern_from_skeleton_loop(
    bucket,
    skeleton,
    want_specified_skeleton,
  )
}

fn pattern_map_get_pattern_from_skeleton_loop(
  bucket: List(PtnElem),
  skeleton: PtnSkeleton,
  want_specified_skeleton: Bool,
) -> SkeletonResult {
  case bucket {
    [] -> SkeletonResult(None, None)
    [elem, ..rest] -> {
      let equal = case want_specified_skeleton {
        True ->
          skeleton_fields_equals(elem.skeleton.original, skeleton.original)
        False ->
          skeleton_fields_equals(
            elem.skeleton.base_original,
            skeleton.base_original,
          )
      }
      case equal {
        True -> {
          let specified_skeleton = case
            want_specified_skeleton && elem.skeleton_was_specified
          {
            True -> Some(elem.skeleton)
            False -> None
          }
          SkeletonResult(Some(elem.pattern), specified_skeleton)
        }
        False ->
          pattern_map_get_pattern_from_skeleton_loop(
            rest,
            skeleton,
            want_specified_skeleton,
          )
      }
    }
  }
}

pub fn pattern_map_all_elems(pm: PatternMap) -> List(PtnElem) {
  case pm.all_elems {
    [] -> pm.boot |> dict.values |> list.flatten
    elems -> elems
  }
}

fn finalize_pattern_map(pm: PatternMap) -> PatternMap {
  PatternMap(..pm, all_elems: pm.boot |> dict.values |> list.flatten)
}

pub type DtSkeletonEnumeration {
  DtSkeletonEnumeration(skeletons: List(String), remaining: List(String))
}

pub type DtSkeletonEnumerationNextResult {
  DtSkeletonEnumerationNextResult(
    value: Option(String),
    enumeration: DtSkeletonEnumeration,
  )
}

pub type DtRedundantEnumeration {
  DtRedundantEnumeration(patterns: List(String), remaining: List(String))
}

pub type DtRedundantEnumerationNextResult {
  DtRedundantEnumerationNextResult(
    value: Option(String),
    enumeration: DtRedundantEnumeration,
  )
}

pub fn simple_format(template: String, values: List(String)) -> String {
  simple_format_loop(template, values, 0)
}

fn simple_format_loop(
  template: String,
  values: List(String),
  i: Int,
) -> String {
  case values {
    [] -> template
    [value, ..rest] -> {
      let placeholder = "{" <> int.to_string(i) <> "}"
      simple_format_loop(
        string_replace_all(template, placeholder, value),
        rest,
        i + 1,
      )
    }
  }
}

fn string_replace_all(
  s: String,
  needle: String,
  replacement: String,
) -> String {
  string.split(s, needle) |> string.join(replacement)
}

fn get_date_time_format_style(req_skeleton: PtnSkeleton) -> Int {
  let month_field_len =
    skeleton_fields_get_field_length(
      req_skeleton.base_original,
      udatpg_month_field,
    )
  case month_field_len {
    4 ->
      case
        skeleton_fields_get_field_length(
          req_skeleton.base_original,
          udatpg_weekday_field,
        )
        > 0
      {
        True -> 0
        False -> 1
      }
    3 -> 2
    _ -> 3
  }
}

fn find_first_dt_type_for_field(field: Int) -> Option(DtType) {
  find_first_dt_type_for_field_loop(dt_types(), field)
}

fn find_first_dt_type_for_field_loop(
  rows: List(DtType),
  field: Int,
) -> Option(DtType) {
  case rows {
    [] -> None
    [row, ..rest] ->
      case row.field == field {
        True -> Some(row)
        False -> find_first_dt_type_for_field_loop(rest, field)
      }
  }
}

fn compute_skeleton_tokens_loop(
  fp: FormatParser,
  i: Int,
  skeleton: PtnSkeleton,
) -> PtnSkeleton {
  case i >= fp.item_number {
    True -> skeleton
    False -> {
      let value = format_parser_item_at(fp, i)
      case is_quote_literal(value) {
        True -> {
          let r = format_parser_get_quote_literal(fp, i)
          compute_skeleton_tokens_loop(fp, r.item_index + 1, skeleton)
        }
        False -> {
          let canonical_index = get_canonical_index(value, True)
          case canonical_index < 0 {
            True -> compute_skeleton_tokens_loop(fp, i + 1, skeleton)
            False -> {
              let row = dt_type_at(canonical_index)
              case row {
                None -> compute_skeleton_tokens_loop(fp, i + 1, skeleton)
                Some(row) -> {
                  let field = row.field
                  let original =
                    skeleton_fields_populate_from_value(
                      skeleton.original,
                      field,
                      value,
                    )
                  let base_original =
                    skeleton_fields_populate(
                      skeleton.base_original,
                      field,
                      row.pattern_char,
                      row.min_len,
                    )
                  let sub_field = case row.type_ > 0 {
                    True -> row.type_ + char_len(value)
                    False -> row.type_
                  }
                  let type_ = dict.insert(skeleton.type_, field, sub_field)
                  compute_skeleton_tokens_loop(
                    fp,
                    i + 1,
                    PtnSkeleton(
                      ..skeleton,
                      original:,
                      base_original:,
                      type_:,
                      type_vector: field_types_of(type_),
                    ),
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

fn fixup_second_from_minute_fractional(skeleton: PtnSkeleton) -> PtnSkeleton {
  case
    !skeleton_fields_is_field_empty(skeleton.original, udatpg_minute_field)
    && !skeleton_fields_is_field_empty(
      skeleton.original,
      udatpg_fractional_second_field,
    )
    && skeleton_fields_is_field_empty(skeleton.original, udatpg_second_field)
  {
    False -> skeleton
    True ->
      case find_first_dt_type_for_field(udatpg_second_field) {
        None -> skeleton
        Some(row) -> {
          let original =
            skeleton_fields_populate(
              skeleton.original,
              udatpg_second_field,
              row.pattern_char,
              row.min_len,
            )
          let base_original =
            skeleton_fields_populate(
              skeleton.base_original,
              udatpg_second_field,
              row.pattern_char,
              row.min_len,
            )
          let sub_field = case row.type_ > 0 {
            True -> row.type_ + 1
            False -> row.type_
          }
          let type_ =
            dict.insert(skeleton.type_, udatpg_second_field, sub_field)
          PtnSkeleton(..skeleton, original:, base_original:, type_:)
        }
      }
  }
}

fn fixup_hour_day_period(skeleton: PtnSkeleton) -> PtnSkeleton {
  case skeleton_fields_is_field_empty(skeleton.original, udatpg_hour_field) {
    True -> skeleton
    False -> {
      let hour_char =
        skeleton_fields_get_field_char(skeleton.original, udatpg_hour_field)
      case hour_char == "h" || hour_char == "K" {
        True ->
          case
            skeleton_fields_is_field_empty(
              skeleton.original,
              udatpg_dayperiod_field,
            )
          {
            False -> skeleton
            True ->
              case find_first_dt_type_for_field(udatpg_dayperiod_field) {
                None -> skeleton
                Some(row) -> {
                  let original =
                    skeleton_fields_populate(
                      skeleton.original,
                      udatpg_dayperiod_field,
                      row.pattern_char,
                      row.min_len,
                    )
                  let base_original =
                    skeleton_fields_populate(
                      skeleton.base_original,
                      udatpg_dayperiod_field,
                      row.pattern_char,
                      row.min_len,
                    )
                  let type_ =
                    dict.insert(
                      skeleton.type_,
                      udatpg_dayperiod_field,
                      row.type_,
                    )
                  PtnSkeleton(
                    original:,
                    base_original:,
                    type_:,
                    type_vector: field_types_of(type_),
                    added_default_day_period: True,
                  )
                }
              }
          }
        False -> {
          let original =
            skeleton_fields_clear_field(
              skeleton.original,
              udatpg_dayperiod_field,
            )
          let base_original =
            skeleton_fields_clear_field(
              skeleton.base_original,
              udatpg_dayperiod_field,
            )
          let type_ =
            dict.insert(skeleton.type_, udatpg_dayperiod_field, none_type)
          PtnSkeleton(..skeleton, original:, base_original:, type_:)
        }
      }
    }
  }
}

pub fn date_time_matcher_compute_skeleton(
  pattern: String,
  _fp: FormatParser,
) -> #(PtnSkeleton, FormatParser) {
  let skeleton =
    PtnSkeleton(..ptn_skeleton_clear(), type_: field_int_dict(none_type))
  let local_fp = format_parser_set(pattern)
  let skeleton = compute_skeleton_tokens_loop(local_fp, 0, skeleton)
  let skeleton = fixup_second_from_minute_fractional(skeleton)
  let skeleton = fixup_hour_day_period(skeleton)
  #(skeleton, local_fp)
}

pub fn date_time_matcher_set(
  pattern: String,
  fp: FormatParser,
) -> #(DateTimeMatcher, FormatParser, PtnSkeleton) {
  let #(computed, new_fp) = date_time_matcher_compute_skeleton(pattern, fp)
  let matcher = date_time_matcher_copy_from(Some(computed))
  #(matcher, new_fp, computed)
}

pub type DateTimePatternGenerator {
  DateTimePatternGenerator(
    fp: FormatParser,
    dt_matcher: DateTimeMatcher,
    distance_info: DistanceInfo,
    pattern_map: PatternMap,
    append_item_formats: Dict(Int, String),
    field_display_names: Dict(Int, Dict(Int, String)),
    date_time_format: Dict(Int, String),
    decimal: String,
    skip_matcher: Option(DateTimeMatcher),
    available_format_keys: List(String),
    default_hour_format_char: String,
    allowed_hour_formats: List(String),
    bundle: Option(Bundle),
    locale_id: String,
    base_name: String,
    chain: Option(List(String)),
  )
}

pub fn create_date_time_pattern_generator() -> DateTimePatternGenerator {
  DateTimePatternGenerator(
    fp: create_format_parser(),
    dt_matcher: create_date_time_matcher(),
    distance_info: create_distance_info(),
    pattern_map: create_pattern_map(),
    append_item_formats: field_string_dict(""),
    field_display_names: field_width_string_dict(""),
    date_time_format: style_string_dict("{1} {0}"),
    decimal: ".",
    skip_matcher: None,
    available_format_keys: [],
    default_hour_format_char: "\u{0}",
    allowed_hour_formats: [],
    bundle: None,
    locale_id: "",
    base_name: "",
    chain: None,
  )
}

fn field_width_string_dict(default: String) -> Dict(Int, Dict(Int, String)) {
  field_width_string_dict_loop(default, 0, dict.new())
}

fn field_width_string_dict_loop(
  default: String,
  field: Int,
  acc: Dict(Int, Dict(Int, String)),
) -> Dict(Int, Dict(Int, String)) {
  case field >= udatpg_field_count {
    True -> acc
    False ->
      field_width_string_dict_loop(
        default,
        field + 1,
        dict.insert(acc, field, width_string_dict(default)),
      )
  }
}

fn field_display_row_get(
  rows: Dict(Int, Dict(Int, String)),
  field: Int,
) -> Dict(Int, String) {
  case dict.get(rows, field) {
    Ok(row) -> row
    Error(_) -> width_string_dict("")
  }
}

fn field_display_name_get(
  rows: Dict(Int, Dict(Int, String)),
  field: Int,
  width: Int,
) -> String {
  dict_string_get(field_display_row_get(rows, field), width, "")
}

fn field_display_name_set(
  rows: Dict(Int, Dict(Int, String)),
  field: Int,
  width: Int,
  value: String,
) -> Dict(Int, Dict(Int, String)) {
  let row = field_display_row_get(rows, field)
  dict.insert(rows, field, dict.insert(row, width, value))
}

fn date_time_format_get(formats: Dict(Int, String), style: Int) -> String {
  dict_string_get(formats, style, "{1} {0}")
}

fn date_time_format_set(
  formats: Dict(Int, String),
  style: Int,
  value: String,
) -> Dict(Int, String) {
  dict.insert(formats, style, value)
}

pub type AddPatternResult {
  AddPatternResult(
    dtpg: DateTimePatternGenerator,
    conflicting_status: Int,
    conflicting_pattern: String,
  )
}

pub fn dtpg_add_pattern(
  dtpg: DateTimePatternGenerator,
  pattern: String,
  override: Bool,
) -> AddPatternResult {
  dtpg_add_pattern_with_optional_skeleton(dtpg, pattern, None, override)
}

pub fn dtpg_add_pattern_with_optional_skeleton(
  dtpg: DateTimePatternGenerator,
  pattern: String,
  skeleton_to_use: Option(String),
  override: Bool,
) -> AddPatternResult {
  let to_parse = case skeleton_to_use {
    None -> pattern
    Some(s) -> s
  }
  let #(matcher, new_fp, skeleton) = date_time_matcher_set(to_parse, dtpg.fp)
  let dtpg = DateTimePatternGenerator(..dtpg, fp: new_fp)
  let base_pattern = date_time_matcher_get_base_pattern(matcher)

  let dup =
    pattern_map_get_pattern_from_base_pattern(dtpg.pattern_map, base_pattern)
  let #(conflicting_status, conflicting_pattern, should_return) = case dup {
    None -> #(udatpg_no_conflict, "", False)
    Some(d) -> {
      let triggers =
        !d.skeleton_was_specified
        || { option.is_some(skeleton_to_use) && !override }
      case triggers {
        False -> #(udatpg_no_conflict, "", False)
        True ->
          case !override {
            True -> #(udatpg_base_conflict, d.pattern, True)
            False -> #(udatpg_base_conflict, d.pattern, False)
          }
      }
    }
  }
  case should_return {
    True -> AddPatternResult(dtpg, conflicting_status, conflicting_pattern)
    False -> {
      let dup2 =
        pattern_map_get_pattern_from_skeleton(dtpg.pattern_map, skeleton, True)
      let #(conflicting_status, conflicting_pattern, should_return2) = case
        dup2.pattern
      {
        None -> #(conflicting_status, conflicting_pattern, False)
        Some(p) ->
          case
            !override
            || {
              option.is_some(skeleton_to_use)
              && option.is_some(dup2.specified_skeleton)
            }
          {
            True -> #(udatpg_conflict, p, True)
            False -> #(udatpg_conflict, p, False)
          }
      }
      case should_return2 {
        True -> AddPatternResult(dtpg, conflicting_status, conflicting_pattern)
        False -> {
          let pattern_map =
            pattern_map_add(
              dtpg.pattern_map,
              base_pattern,
              skeleton,
              pattern,
              option.is_some(skeleton_to_use),
            )
          AddPatternResult(
            DateTimePatternGenerator(..dtpg, pattern_map:),
            udatpg_no_conflict,
            "",
          )
        }
      }
    }
  }
}

fn dtpg_add_canonical_items(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  dtpg_add_canonical_items_loop(dtpg, 0)
}

fn dtpg_add_canonical_items_loop(
  dtpg: DateTimePatternGenerator,
  i: Int,
) -> DateTimePatternGenerator {
  case i >= udatpg_field_count {
    True -> dtpg
    False -> {
      let r = dtpg_add_pattern(dtpg, canonical_item_at(i), False)
      dtpg_add_canonical_items_loop(r.dtpg, i + 1)
    }
  }
}

fn canonical_item_at(index: Int) -> String {
  case index {
    0 -> "G"
    1 -> "y"
    2 -> "Q"
    3 -> "M"
    4 -> "w"
    5 -> "W"
    6 -> "E"
    7 -> "D"
    8 -> "F"
    9 -> "d"
    10 -> "a"
    11 -> "H"
    12 -> "m"
    13 -> "s"
    14 -> "S"
    15 -> "v"
    _ -> ""
  }
}

fn dtpg_get_calendar_type_to_use(dtpg: DateTimePatternGenerator) -> String {
  case dtpg.bundle {
    None -> "gregorian"
    Some(bundle) -> uloc.get_calendar_type_to_use(bundle, dtpg.locale_id)
  }
}

fn calendar_data_for(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  locale: String,
  cal_type: String,
) -> Option(resource.DateIntervalCalendarData) {
  case dict.get(locales, locale) {
    Error(_) -> None
    Ok(by_cal) -> option.from_result(dict.get(by_cal, cal_type))
  }
}

fn find_calendar_field(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  full_chain: List(String),
  chain: List(String),
  cal_type: String,
  select: fn(resource.DateIntervalCalendarData) ->
    Option(resource.CalendarField(a)),
  depth: Int,
) -> Option(a) {
  case depth >= 8 {
    True -> None
    False ->
      case chain {
        [] -> None
        [locale, ..rest] ->
          case calendar_data_for(locales, locale, cal_type) {
            None ->
              find_calendar_field(
                locales,
                full_chain,
                rest,
                cal_type,
                select,
                depth,
              )
            Some(data) ->
              case select(data) {
                None ->
                  find_calendar_field(
                    locales,
                    full_chain,
                    rest,
                    cal_type,
                    select,
                    depth,
                  )
                Some(resource.CalendarValue(value)) -> Some(value)
                Some(resource.CalendarAliasTo(target)) ->
                  find_calendar_field(
                    locales,
                    full_chain,
                    full_chain,
                    target,
                    select,
                    depth + 1,
                  )
              }
          }
      }
  }
}

fn merge_missing_map(
  acc: Dict(String, a),
  found: Dict(String, a),
) -> Dict(String, a) {
  dict.fold(found, acc, fn(acc, key, value) {
    case dict.has_key(acc, key) {
      True -> acc
      False -> dict.insert(acc, key, value)
    }
  })
}

fn merge_calendar_field(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
  select: fn(resource.DateIntervalCalendarData) ->
    Option(resource.CalendarField(Dict(String, a))),
) -> Dict(String, a) {
  merge_calendar_field_calendars(
    locales,
    chain,
    cal_type,
    select,
    dict.new(),
    [],
  )
}

fn merge_calendar_field_calendars(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
  select: fn(resource.DateIntervalCalendarData) ->
    Option(resource.CalendarField(Dict(String, a))),
  acc: Dict(String, a),
  loaded: List(String),
) -> Dict(String, a) {
  case list.contains(loaded, cal_type) {
    True -> acc
    False -> {
      let #(acc, next_cal) =
        merge_calendar_field_chain(locales, chain, cal_type, select, acc, None)
      case next_cal {
        None -> acc
        Some(target) ->
          merge_calendar_field_calendars(locales, chain, target, select, acc, [
            cal_type,
            ..loaded
          ])
      }
    }
  }
}

fn merge_calendar_field_chain(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
  select: fn(resource.DateIntervalCalendarData) ->
    Option(resource.CalendarField(Dict(String, a))),
  acc: Dict(String, a),
  next_cal: Option(String),
) -> #(Dict(String, a), Option(String)) {
  case chain {
    [] -> #(acc, next_cal)
    [locale, ..rest] ->
      case calendar_data_for(locales, locale, cal_type) {
        None ->
          merge_calendar_field_chain(
            locales,
            rest,
            cal_type,
            select,
            acc,
            next_cal,
          )
        Some(data) ->
          case select(data) {
            None ->
              merge_calendar_field_chain(
                locales,
                rest,
                cal_type,
                select,
                acc,
                next_cal,
              )
            Some(resource.CalendarValue(found)) ->
              merge_calendar_field_chain(
                locales,
                rest,
                cal_type,
                select,
                merge_missing_map(acc, found),
                next_cal,
              )
            Some(resource.CalendarAliasTo(target)) ->
              merge_calendar_field_chain(
                locales,
                rest,
                cal_type,
                select,
                acc,
                Some(target),
              )
          }
      }
  }
}

fn dtpg_add_icu_patterns(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  case dtpg.bundle, dtpg.chain {
    Some(bundle), Some(chain) -> {
      let cal_type = dtpg_get_calendar_type_to_use(dtpg)
      let locales = bundle.date_interval_data_by_locale.locales
      case
        find_calendar_field(
          locales,
          chain,
          chain,
          cal_type,
          fn(data) { data.date_time_patterns },
          0,
        )
      {
        None -> dtpg
        Some(patterns) ->
          patterns
          |> list.take(8)
          |> list.fold(dtpg, fn(dtpg, pattern) {
            dtpg_add_pattern_with_optional_skeleton(dtpg, pattern, None, False).dtpg
          })
      }
    }
    _, _ -> dtpg
  }
}

fn dtpg_get_append_format_number(field: String) -> Int {
  dtpg_get_append_format_number_loop(cldr_field_append, field, 0)
}

fn dtpg_get_append_format_number_loop(
  names: List(String),
  field: String,
  i: Int,
) -> Int {
  case names {
    [] -> udatpg_field_count
    [head, ..rest] ->
      case head == field {
        True -> i
        False -> dtpg_get_append_format_number_loop(rest, field, i + 1)
      }
  }
}

pub type FieldWidthIndices {
  FieldWidthIndices(field: Int, width: Int)
}

fn dtpg_get_field_and_width_indices(key: String) -> FieldWidthIndices {
  case string.split_once(key, "-") {
    Error(_) -> dtpg_find_field_index(cldr_field_name, key, 0, 0)
    Ok(#(before, after_suffix)) -> {
      let suffix = "-" <> after_suffix
      let width = find_width_index(suffix, 2)
      dtpg_find_field_index(cldr_field_name, before, 0, width)
    }
  }
}

fn find_width_index(suffix: String, i: Int) -> Int {
  case i <= 0 {
    True -> 0
    False ->
      case cldr_field_width_at(i) == suffix {
        True -> i
        False -> find_width_index(suffix, i - 1)
      }
  }
}

fn cldr_field_width_at(index: Int) -> String {
  case index {
    1 -> "-short"
    2 -> "-narrow"
    _ -> ""
  }
}

fn dtpg_find_field_index(
  names: List(String),
  cldr_field_key: String,
  i: Int,
  width: Int,
) -> FieldWidthIndices {
  case names {
    [] -> FieldWidthIndices(udatpg_field_count, width)
    [head, ..rest] ->
      case head == cldr_field_key {
        True -> FieldWidthIndices(i, width)
        False -> dtpg_find_field_index(rest, cldr_field_key, i + 1, width)
      }
  }
}

fn dtpg_add_cldr_data_append_items(
  dtpg: DateTimePatternGenerator,
  cal_type: String,
) -> DateTimePatternGenerator {
  case dtpg.bundle, dtpg.chain {
    Some(bundle), Some(chain) -> {
      let locales = bundle.date_interval_data_by_locale.locales
      let items =
        merge_calendar_field(locales, chain, cal_type, fn(data) {
          data.append_items
        })
      let dtpg =
        dict.fold(items, dtpg, fn(dtpg, key, value) {
          let field = dtpg_get_append_format_number(key)
          case
            field == udatpg_field_count
            || value == ""
            || dict_string_get(dtpg.append_item_formats, field, "") != ""
          {
            True -> dtpg
            False ->
              DateTimePatternGenerator(
                ..dtpg,
                append_item_formats: dict.insert(
                  dtpg.append_item_formats,
                  field,
                  value,
                ),
              )
          }
        })
      let append_item_formats =
        fill_append_item_formats(dtpg.append_item_formats, 0)
      DateTimePatternGenerator(..dtpg, append_item_formats:)
    }
    _, _ -> dtpg
  }
}

fn fill_append_item_formats(
  formats: Dict(Int, String),
  field: Int,
) -> Dict(Int, String) {
  case field >= udatpg_field_count {
    True -> formats
    False -> {
      let value = dict_string_get(formats, field, "")
      let formats = case value == "" {
        True -> dict.insert(formats, field, udatpg_item_format)
        False -> formats
      }
      fill_append_item_formats(formats, field + 1)
    }
  }
}

fn dtpg_add_cldr_data_field_names(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  case dtpg.bundle, dtpg.chain {
    Some(bundle), Some(chain) -> {
      let locales = bundle.relative_fields_by_locale.locales
      let dtpg =
        list.fold(chain, dtpg, fn(dtpg, locale) {
          case dict.get(locales, locale) {
            Error(_) -> dtpg
            Ok(fields) ->
              dict.fold(fields, dtpg, fn(dtpg, key, value) {
                let fw = dtpg_get_field_and_width_indices(key)
                case fw.field == udatpg_field_count {
                  True -> dtpg
                  False ->
                    case value {
                      resource.RelativeFieldAliasTo(_) -> dtpg
                      resource.RelativeFieldValue(data) ->
                        case data.display_name {
                          None | Some("") -> dtpg
                          Some(dn) -> {
                            let row =
                              field_display_row_get(
                                dtpg.field_display_names,
                                fw.field,
                              )
                            case dict_string_get(row, fw.width, "") == "" {
                              False -> dtpg
                              True ->
                                DateTimePatternGenerator(
                                  ..dtpg,
                                  field_display_names: field_display_name_set(
                                    dtpg.field_display_names,
                                    fw.field,
                                    fw.width,
                                    dn,
                                  ),
                                )
                            }
                          }
                        }
                    }
                }
              })
          }
        })
      fill_field_display_name_defaults(dtpg)
    }
    _, _ -> dtpg
  }
}

fn fill_field_display_name_defaults(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  let field_display_names =
    fill_field_display_name_defaults_loop(dtpg.field_display_names, 0)
  DateTimePatternGenerator(..dtpg, field_display_names:)
}

fn fill_field_display_name_defaults_loop(
  rows: Dict(Int, Dict(Int, String)),
  i: Int,
) -> Dict(Int, Dict(Int, String)) {
  case i >= udatpg_field_count {
    True -> rows
    False -> {
      let row = field_display_row_get(rows, i)
      let row = case dict_string_get(row, 0, "") == "" {
        True -> dict.insert(row, 0, "F" <> int.to_string(i))
        False -> row
      }
      let row = fill_width_defaults_loop(row, 1)
      fill_field_display_name_defaults_loop(dict.insert(rows, i, row), i + 1)
    }
  }
}

fn fill_width_defaults_loop(
  row: Dict(Int, String),
  j: Int,
) -> Dict(Int, String) {
  case j >= udatpg_width_count {
    True -> row
    False -> {
      let row = case dict_string_get(row, j, "") == "" {
        True -> dict.insert(row, j, dict_string_get(row, j - 1, ""))
        False -> row
      }
      fill_width_defaults_loop(row, j + 1)
    }
  }
}

fn dtpg_add_cldr_data_available_formats(
  dtpg: DateTimePatternGenerator,
  cal_type: String,
) -> DateTimePatternGenerator {
  case dtpg.bundle, dtpg.chain {
    Some(bundle), Some(chain) -> {
      let locales = bundle.date_interval_data_by_locale.locales
      let formats =
        merge_calendar_field(locales, chain, cal_type, fn(data) {
          data.available_formats
        })
      formats
      |> dict.to_list
      |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
      |> list.fold(dtpg, fn(dtpg, entry) {
        let #(key, value) = entry
        let dtpg =
          DateTimePatternGenerator(..dtpg, available_format_keys: [
            key,
            ..dtpg.available_format_keys
          ])
        case value {
          resource.AvailableFormatUnavailable -> dtpg
          resource.AvailableFormatPattern(pattern) ->
            dtpg_add_pattern_with_optional_skeleton(
              dtpg,
              pattern,
              Some(key),
              True,
            ).dtpg
        }
      })
    }
    _, _ -> dtpg
  }
}

pub fn dtpg_add_cldr_data(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  let cal_type = dtpg_get_calendar_type_to_use(dtpg)
  let dtpg = dtpg_add_cldr_data_append_items(dtpg, cal_type)
  let dtpg = dtpg_add_cldr_data_field_names(dtpg)
  dtpg_add_cldr_data_available_formats(dtpg, cal_type)
}

fn dtpg_set_date_time_from_calendar(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  case dtpg.bundle, dtpg.chain {
    Some(bundle), Some(chain) -> {
      let cal_type = dtpg_get_calendar_type_to_use(dtpg)
      let locales = bundle.date_interval_data_by_locale.locales
      let at_time =
        find_date_time_patterns(locales, chain, cal_type, fn(data) {
          data.date_time_patterns_at_time
        })
      case at_time {
        Some(patterns) ->
          case list.length(patterns) >= 4 {
            True -> apply_date_time_patterns(dtpg, patterns, 0)
            False ->
              set_date_time_from_full_patterns(dtpg, locales, chain, cal_type)
          }
        _ -> {
          set_date_time_from_full_patterns(dtpg, locales, chain, cal_type)
        }
      }
    }
    _, _ -> dtpg
  }
}

fn set_date_time_from_full_patterns(
  dtpg: DateTimePatternGenerator,
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
) -> DateTimePatternGenerator {
  let full =
    find_date_time_patterns(locales, chain, cal_type, fn(data) {
      data.date_time_patterns
    })
  case full {
    None -> dtpg
    Some(patterns) ->
      case list.length(patterns) > 12 {
        True -> apply_date_time_patterns(dtpg, patterns, 9)
        False -> dtpg
      }
  }
}

fn find_date_time_patterns(
  locales: Dict(String, Dict(String, resource.DateIntervalCalendarData)),
  chain: List(String),
  cal_type: String,
  select: fn(resource.DateIntervalCalendarData) ->
    Option(resource.CalendarField(List(String))),
) -> Option(List(String)) {
  let found = case cal_type == "gregorian" {
    True -> None
    False -> find_calendar_field(locales, chain, chain, cal_type, select, 0)
  }
  case found {
    Some(_) -> found
    None -> find_calendar_field(locales, chain, chain, "gregorian", select, 0)
  }
}

fn apply_date_time_patterns(
  dtpg: DateTimePatternGenerator,
  patterns: List(String),
  offset: Int,
) -> DateTimePatternGenerator {
  let date_time_format =
    apply_date_time_patterns_loop(
      dtpg.date_time_format,
      list.drop(patterns, offset),
      0,
    )
  DateTimePatternGenerator(..dtpg, date_time_format:)
}

fn apply_date_time_patterns_loop(
  date_time_format: Dict(Int, String),
  patterns: List(String),
  style: Int,
) -> Dict(Int, String) {
  case patterns, style > 3 {
    _, True -> date_time_format
    [], False -> date_time_format
    [pattern, ..rest], False ->
      apply_date_time_patterns_loop(
        date_time_format_set(date_time_format, style, pattern),
        rest,
        style + 1,
      )
  }
}

fn dtpg_set_decimal_symbols(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  case dtpg.bundle {
    Some(bundle) -> {
      let ns = numsys.create_instance_for_locale(bundle, dtpg.locale_id)
      let ns_name = numsys.numbering_system_get_name(ns)
      let found = case ns_name != "latn" {
        True -> decimfmt.load_decimal_separator(bundle, dtpg.locale_id, ns_name)
        False -> None
      }
      let found = case found {
        Some(_) -> found
        None -> decimfmt.load_decimal_separator(bundle, dtpg.locale_id, "latn")
      }
      case found {
        None -> dtpg
        Some(decimal) -> DateTimePatternGenerator(..dtpg, decimal:)
      }
    }
    None -> dtpg
  }
}

fn maximize_language_script_region(
  bundle: Bundle,
  language: String,
  script: String,
  region: String,
) -> #(String, String) {
  case loclikelysubtags.create_likely_subtags(bundle) {
    Error(_) -> #(language, region)
    Ok(state) -> {
      let lsr =
        loclikelysubtags.maximize(state, language, script, region, False)
      #(lsr.language, lsr.region)
    }
  }
}

fn dtpg_get_allowed_hour_formats(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  case dtpg.bundle {
    None -> dtpg
    Some(bundle) -> {
      let language0 = uloc.get_language(Some(dtpg.locale_id))
      let country0 = uloc.get_region(Some(dtpg.locale_id))
      let #(language, country) = case language0 == "" || country0 == "" {
        False -> #(language0, country0)
        True -> {
          let script = uloc.get_script(Some(dtpg.locale_id))
          maximize_language_script_region(bundle, language0, script, country0)
        }
      }
      let language = case language == "" {
        True -> "und"
        False -> language
      }
      let country = case country == "" {
        True -> "001"
        False -> country
      }

      let supplemental_data = bundle.supplemental_data

      let time_data = case
        dict.get(supplemental_data.time_data, language <> "_" <> country)
      {
        Ok(entry) -> Ok(entry)
        _ -> dict.get(supplemental_data.time_data, country)
      }

      let hours_kw = uloc.get_keyword_value(Some(dtpg.locale_id), "hours")
      let default_hour_format_char = case hours_kw {
        "h24" -> "k"
        "h23" -> "H"
        "h12" -> "h"
        "h11" -> "K"
        _ -> "\u{0}"
      }

      case time_data {
        Error(_) ->
          finish_allowed_hour_formats(dtpg, default_hour_format_char, None, [])
        Ok(time_data) -> {
          finish_allowed_hour_formats(
            dtpg,
            default_hour_format_char,
            time_data.preferred,
            time_data.allowed,
          )
        }
      }
    }
  }
}

fn finish_allowed_hour_formats(
  dtpg: DateTimePatternGenerator,
  default_hour_format_char: String,
  preferred: Option(String),
  allowed_list: List(String),
) -> DateTimePatternGenerator {
  case allowed_list {
    [] -> {
      let default_hour_format_char = case default_hour_format_char == "\u{0}" {
        True -> "H"
        False -> default_hour_format_char
      }
      DateTimePatternGenerator(
        ..dtpg,
        default_hour_format_char:,
        allowed_hour_formats: ["H"],
      )
    }
    _ -> {
      let preferred_value = case preferred {
        Some(p) -> p
        None -> list_first(allowed_list, "")
      }
      let default_hour_format_char = case default_hour_format_char == "\u{0}" {
        False -> default_hour_format_char
        True ->
          case preferred_value {
            "h" -> "h"
            "H" -> "H"
            "K" -> "K"
            "k" -> "k"
            _ -> "H"
          }
      }
      DateTimePatternGenerator(
        ..dtpg,
        default_hour_format_char:,
        allowed_hour_formats: allowed_list,
      )
    }
  }
}

pub fn dtpg_init_data(
  dtpg_in: DateTimePatternGenerator,
  bundle: Bundle,
  locale_id: String,
  skip_std_patterns: Bool,
) -> DateTimePatternGenerator {
  let base_name = uloc.get_base_name(Some(locale_id))
  let dtpg =
    DateTimePatternGenerator(
      ..dtpg_in,
      bundle: Some(bundle),
      locale_id:,
      base_name:,
    )
  let chain = localechain.locale_chain(bundle.locale_parents, base_name)
  let dtpg = DateTimePatternGenerator(..dtpg, chain: Some(chain))
  let dtpg = dtpg_add_canonical_items(dtpg)
  let dtpg = case skip_std_patterns {
    True -> dtpg
    False -> dtpg_add_icu_patterns(dtpg)
  }
  let dtpg = dtpg_add_cldr_data(dtpg)
  let dtpg = dtpg_set_date_time_from_calendar(dtpg)
  let dtpg = dtpg_set_decimal_symbols(dtpg)
  dtpg_get_allowed_hour_formats(dtpg)
}

pub fn dtpg_create_instance(
  bundle: Bundle,
  locale_id: String,
) -> DateTimePatternGenerator {
  dtpg_init_data(create_date_time_pattern_generator(), bundle, locale_id, False)
}

pub fn dtpg_detach_source_data(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  // These fields are only needed while initializing the pattern generator.
  // Removing them prevents every encoded DTPG from embedding the whole Bundle.
  DateTimePatternGenerator(
    ..dtpg,
    pattern_map: PatternMap(..dtpg.pattern_map, all_elems: []),
    bundle: None,
    locale_id: "",
    base_name: "",
    chain: None,
  )
}

pub fn dtpg_prepare_for_runtime(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  DateTimePatternGenerator(
    ..dtpg,
    pattern_map: finalize_pattern_map(dtpg.pattern_map),
  )
}

@external(erlang, "intldate_loader_ffi", "constructor_name")
fn constructor_name(_value: Dynamic) -> Result(String, Nil) {
  panic as "unsupported Target"
}

pub fn dtpg_decode(data: BitArray) -> Result(DateTimePatternGenerator, String) {
  use value <- result.try(loader.decode_etf(data))
  decode.run(value, date_time_pattern_generator_decoder())
  |> result.map_error(fn(_) { "invalid pattern generator data" })
}

fn option_decoder(inner: decode.Decoder(a)) -> decode.Decoder(Option(a)) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("none") -> decode.success(None)
    Ok("some") -> {
      use value <- decode.field(1, inner)
      decode.success(Some(value))
    }
    _ -> decode.failure(None, "Option")
  }
}

fn none_bundle_decoder() -> decode.Decoder(Option(Bundle)) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("none") -> decode.success(None)
    _ -> decode.failure(None, "Bundle")
  }
}

fn field_types_decoder() -> decode.Decoder(FieldTypes) {
  let fallback = field_types_of(dict.new())
  let decoder = {
    use era <- decode.field(1, decode.int)
    use year <- decode.field(2, decode.int)
    use quarter <- decode.field(3, decode.int)
    use month <- decode.field(4, decode.int)
    use week_of_year <- decode.field(5, decode.int)
    use week_of_month <- decode.field(6, decode.int)
    use weekday <- decode.field(7, decode.int)
    use day_of_year <- decode.field(8, decode.int)
    use day_of_week_in_month <- decode.field(9, decode.int)
    use day <- decode.field(10, decode.int)
    use dayperiod <- decode.field(11, decode.int)
    use hour <- decode.field(12, decode.int)
    use minute <- decode.field(13, decode.int)
    use second <- decode.field(14, decode.int)
    use fractional_second <- decode.field(15, decode.int)
    use zone <- decode.field(16, decode.int)
    decode.success(FieldTypes(
      era:,
      year:,
      quarter:,
      month:,
      week_of_year:,
      week_of_month:,
      weekday:,
      day_of_year:,
      day_of_week_in_month:,
      day:,
      dayperiod:,
      hour:,
      minute:,
      second:,
      fractional_second:,
      zone:,
    ))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("field_types") -> decoder
    _ -> decode.failure(fallback, "FieldTypes")
  }
}

fn skeleton_fields_decoder() -> decode.Decoder(SkeletonFields) {
  let fallback = create_skeleton_fields()
  let decoder = {
    use chars <- decode.field(1, decode.dict(decode.int, decode.string))
    use lengths <- decode.field(2, decode.dict(decode.int, decode.int))
    decode.success(SkeletonFields(chars:, lengths:))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("skeleton_fields") -> decoder
    _ -> decode.failure(fallback, "SkeletonFields")
  }
}

fn ptn_skeleton_decoder() -> decode.Decoder(PtnSkeleton) {
  let fallback = create_ptn_skeleton()
  let decoder = {
    use type_ <- decode.field(1, decode.dict(decode.int, decode.int))
    use type_vector <- decode.field(2, field_types_decoder())
    use original <- decode.field(3, skeleton_fields_decoder())
    use base_original <- decode.field(4, skeleton_fields_decoder())
    use added_default_day_period <- decode.field(5, decode.bool)
    decode.success(PtnSkeleton(
      type_:,
      type_vector:,
      original:,
      base_original:,
      added_default_day_period:,
    ))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("ptn_skeleton") -> decoder
    _ -> decode.failure(fallback, "PtnSkeleton")
  }
}

fn distance_info_decoder() -> decode.Decoder(DistanceInfo) {
  let fallback = create_distance_info()
  let decoder = {
    use missing_field_mask <- decode.field(1, decode.int)
    use extra_field_mask <- decode.field(2, decode.int)
    decode.success(DistanceInfo(missing_field_mask:, extra_field_mask:))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("distance_info") -> decoder
    _ -> decode.failure(fallback, "DistanceInfo")
  }
}

fn date_time_matcher_decoder() -> decode.Decoder(DateTimeMatcher) {
  let fallback = create_date_time_matcher()
  let decoder = {
    use skeleton <- decode.field(1, ptn_skeleton_decoder())
    decode.success(DateTimeMatcher(skeleton:))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("date_time_matcher") -> decoder
    _ -> decode.failure(fallback, "DateTimeMatcher")
  }
}

fn ptn_elem_decoder() -> decode.Decoder(PtnElem) {
  let fallback = PtnElem("", create_ptn_skeleton(), "", False)
  let decoder = {
    use base_pattern <- decode.field(1, decode.string)
    use skeleton <- decode.field(2, ptn_skeleton_decoder())
    use pattern <- decode.field(3, decode.string)
    use skeleton_was_specified <- decode.field(4, decode.bool)
    decode.success(PtnElem(
      base_pattern:,
      skeleton:,
      pattern:,
      skeleton_was_specified:,
    ))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("ptn_elem") -> decoder
    _ -> decode.failure(fallback, "PtnElem")
  }
}

fn pattern_map_decoder() -> decode.Decoder(PatternMap) {
  let fallback = create_pattern_map()
  let decoder = {
    use boot <- decode.field(
      1,
      decode.dict(decode.int, decode.list(ptn_elem_decoder())),
    )
    use all_elems <- decode.field(2, decode.list(ptn_elem_decoder()))
    decode.success(PatternMap(boot:, all_elems:))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("pattern_map") -> decoder
    _ -> decode.failure(fallback, "PatternMap")
  }
}

fn format_parser_decoder() -> decode.Decoder(FormatParser) {
  let fallback = create_format_parser()
  let decoder = {
    use items <- decode.field(1, decode.list(decode.string))
    use item_number <- decode.field(2, decode.int)
    use index <- decode.field(3, decode.dict(decode.int, decode.string))
    decode.success(FormatParser(items:, item_number:, index:))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("format_parser") -> decoder
    _ -> decode.failure(fallback, "FormatParser")
  }
}

fn date_time_pattern_generator_decoder() -> decode.Decoder(
  DateTimePatternGenerator,
) {
  let fallback = create_date_time_pattern_generator()
  let decoder = {
    use fp <- decode.field(1, format_parser_decoder())
    use dt_matcher <- decode.field(2, date_time_matcher_decoder())
    use distance_info <- decode.field(3, distance_info_decoder())
    use pattern_map <- decode.field(4, pattern_map_decoder())
    use append_item_formats <- decode.field(
      5,
      decode.dict(decode.int, decode.string),
    )
    use field_display_names <- decode.field(
      6,
      decode.dict(decode.int, decode.dict(decode.int, decode.string)),
    )
    use date_time_format <- decode.field(
      7,
      decode.dict(decode.int, decode.string),
    )
    use decimal <- decode.field(8, decode.string)
    use skip_matcher <- decode.field(
      9,
      option_decoder(date_time_matcher_decoder()),
    )
    use available_format_keys <- decode.field(10, decode.list(decode.string))
    use default_hour_format_char <- decode.field(11, decode.string)
    use allowed_hour_formats <- decode.field(12, decode.list(decode.string))
    use bundle <- decode.field(13, none_bundle_decoder())
    use locale_id <- decode.field(14, decode.string)
    use base_name <- decode.field(15, decode.string)
    use chain <- decode.field(16, option_decoder(decode.list(decode.string)))
    decode.success(DateTimePatternGenerator(
      fp:,
      dt_matcher:,
      distance_info:,
      pattern_map:,
      append_item_formats:,
      field_display_names:,
      date_time_format:,
      decimal:,
      skip_matcher:,
      available_format_keys:,
      default_hour_format_char:,
      allowed_hour_formats:,
      bundle:,
      locale_id:,
      base_name:,
      chain:,
    ))
  }
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("date_time_pattern_generator") -> decoder
    _ -> decode.failure(fallback, "DateTimePatternGenerator")
  }
}

pub type MapSkeletonResult {
  MapSkeletonResult(mapped: String, flags: Int)
}

pub fn dtpg_map_skeleton_metacharacters(
  dtpg: DateTimePatternGenerator,
  pattern_form: String,
) -> MapSkeletonResult {
  map_skeleton_loop(
    dtpg,
    string.to_graphemes(pattern_form),
    False,
    "",
    kdtpg_no_flags,
  )
}

fn map_skeleton_loop(
  dtpg: DateTimePatternGenerator,
  chars: List(String),
  in_quoted: Bool,
  mapped: String,
  flags: Int,
) -> MapSkeletonResult {
  case chars {
    [] -> MapSkeletonResult(mapped, flags)
    [pat_chr, ..rest] ->
      case pat_chr == "'" {
        True -> map_skeleton_loop(dtpg, rest, !in_quoted, mapped, flags)
        False ->
          case in_quoted {
            True -> map_skeleton_loop(dtpg, rest, in_quoted, mapped, flags)
            False ->
              case pat_chr == "j" || pat_chr == "C" {
                True -> {
                  let #(extra_len, rest_after) = count_repeat(rest, pat_chr, 0)
                  let hour_len = 1 + int.bitwise_and(extra_len, 1)
                  let day_period_len0 = case extra_len < 2 {
                    True -> 1
                    False -> 3 + int.bitwise_shift_right(extra_len, 1)
                  }
                  let #(hour_char, day_period_char, day_period_len) = case
                    pat_chr == "j"
                  {
                    True -> #(
                      dtpg.default_hour_format_char,
                      "a",
                      day_period_len0,
                    )
                    False -> {
                      let best_allowed =
                        list_first(dtpg.allowed_hour_formats, "")
                      let hour_char = case best_allowed {
                        "H" | "HB" | "Hb" -> "H"
                        "K" | "KB" | "Kb" -> "K"
                        "k" -> "k"
                        _ -> "h"
                      }
                      let day_period_char = case best_allowed {
                        "HB" | "hB" | "KB" -> "B"
                        "Hb" | "hb" | "Kb" -> "b"
                        _ -> "a"
                      }
                      #(hour_char, day_period_char, day_period_len0)
                    }
                  }
                  let day_period_len = case
                    hour_char == "H" || hour_char == "k"
                  {
                    True -> 0
                    False -> day_period_len
                  }
                  let mapped =
                    mapped
                    <> string.repeat(day_period_char, times: day_period_len)
                    <> string.repeat(hour_char, times: hour_len)
                  map_skeleton_loop(dtpg, rest_after, in_quoted, mapped, flags)
                }
                False ->
                  case pat_chr == "J" {
                    True ->
                      map_skeleton_loop(
                        dtpg,
                        rest,
                        in_quoted,
                        mapped <> "H",
                        int.bitwise_or(flags, kdtpg_skeleton_uses_cap_j),
                      )
                    False ->
                      map_skeleton_loop(
                        dtpg,
                        rest,
                        in_quoted,
                        mapped <> pat_chr,
                        flags,
                      )
                  }
              }
          }
      }
  }
}

fn count_repeat(
  chars: List(String),
  pat_chr: String,
  extra_len: Int,
) -> #(Int, List(String)) {
  case chars {
    [c, ..rest] if c == pat_chr -> count_repeat(rest, pat_chr, extra_len + 1)
    _ -> #(extra_len, chars)
  }
}

pub fn dtpg_adjust_field_types(
  dtpg_in: DateTimePatternGenerator,
  pattern: String,
  specified_skeleton: Option(PtnSkeleton),
  flags: Int,
  options: Int,
) -> String {
  let fp = format_parser_set(pattern)
  adjust_field_types_loop(
    dtpg_in,
    fp,
    specified_skeleton,
    flags,
    options,
    0,
    "",
  )
}

fn adjust_field_types_loop(
  dtpg: DateTimePatternGenerator,
  fp: FormatParser,
  specified_skeleton: Option(PtnSkeleton),
  flags: Int,
  options: Int,
  i: Int,
  new_pattern: String,
) -> String {
  case i >= fp.item_number {
    True -> new_pattern
    False -> {
      let field = format_parser_item_at(fp, i)
      case is_quote_literal(field) {
        True -> {
          let r = format_parser_get_quote_literal(fp, i)
          adjust_field_types_loop(
            dtpg,
            fp,
            specified_skeleton,
            flags,
            options,
            r.item_index + 1,
            new_pattern <> r.quote,
          )
        }
        False ->
          case format_parser_is_pattern_separator(fp, field) {
            True ->
              adjust_field_types_loop(
                dtpg,
                fp,
                specified_skeleton,
                flags,
                options,
                i + 1,
                new_pattern <> field,
              )
            False -> {
              let canonical_index = get_canonical_index(field, True)
              case canonical_index < 0 {
                True ->
                  adjust_field_types_loop(
                    dtpg,
                    fp,
                    specified_skeleton,
                    flags,
                    options,
                    i + 1,
                    new_pattern <> field,
                  )
                False -> {
                  let field_out =
                    adjust_one_field(
                      dtpg,
                      field,
                      canonical_index,
                      specified_skeleton,
                      flags,
                      options,
                    )
                  adjust_field_types_loop(
                    dtpg,
                    fp,
                    specified_skeleton,
                    flags,
                    options,
                    i + 1,
                    new_pattern <> field_out,
                  )
                }
              }
            }
          }
      }
    }
  }
}

fn adjust_one_field(
  dtpg: DateTimePatternGenerator,
  field_in: String,
  canonical_index: Int,
  specified_skeleton: Option(PtnSkeleton),
  flags: Int,
  options: Int,
) -> String {
  let row = dt_type_at(canonical_index)
  case row {
    None -> field_in
    Some(row) -> {
      let type_value = row.field
      case
        int.bitwise_and(flags, kdtpg_fix_fractional_seconds) != 0
        && type_value == udatpg_second_field
      {
        True ->
          skeleton_fields_append_field_to(
            dtpg.dt_matcher.skeleton.original,
            udatpg_fractional_second_field,
            field_in <> dtpg.decimal,
          )
        False ->
          case
            dict_int_get(dtpg.dt_matcher.skeleton.type_, type_value, 0) != 0
          {
            False -> field_in
            True -> {
              let req_field_char =
                skeleton_fields_get_field_char(
                  dtpg.dt_matcher.skeleton.original,
                  type_value,
                )
              let req_field_len0 =
                skeleton_fields_get_field_length(
                  dtpg.dt_matcher.skeleton.original,
                  type_value,
                )
              let req_field_len = case
                req_field_char == "E" && req_field_len0 < 3
              {
                True -> 3
                False -> req_field_len0
              }
              let field_len = char_len(field_in)
              let adj_field_len =
                compute_adj_field_len(
                  dtpg,
                  type_value,
                  options,
                  specified_skeleton,
                  req_field_char,
                  req_field_len,
                  field_len,
                  row,
                )
              let c0 = case
                type_value != udatpg_hour_field
                && type_value != udatpg_month_field
                && type_value != udatpg_weekday_field
                && { type_value != udatpg_year_field || req_field_char == "Y" }
              {
                True -> req_field_char
                False -> char_at(field_in, 0)
              }
              let c1 = case c0 == "E" && adj_field_len < 3 {
                True -> "e"
                False -> c0
              }
              let c2 = case
                type_value == udatpg_hour_field
                && dtpg.default_hour_format_char != "\u{0}"
              {
                False -> c1
                True -> adjust_hour_char(dtpg, req_field_char, flags, c1)
              }
              string.repeat(c2, times: adj_field_len)
            }
          }
      }
    }
  }
}

fn adjust_hour_char(
  dtpg: DateTimePatternGenerator,
  req_field_char: String,
  flags: Int,
  current: String,
) -> String {
  case
    int.bitwise_and(flags, kdtpg_skeleton_uses_cap_j) != 0
    || req_field_char == dtpg.default_hour_format_char
  {
    True -> dtpg.default_hour_format_char
    False ->
      case req_field_char == "h" && dtpg.default_hour_format_char == "K" {
        True -> "K"
        False ->
          case req_field_char == "H" && dtpg.default_hour_format_char == "k" {
            True -> "k"
            False ->
              case
                req_field_char == "k" && dtpg.default_hour_format_char == "H"
              {
                True -> "H"
                False ->
                  case
                    req_field_char == "K"
                    && dtpg.default_hour_format_char == "h"
                  {
                    True -> "h"
                    False -> current
                  }
              }
          }
      }
  }
}

fn compute_adj_field_len(
  dtpg: DateTimePatternGenerator,
  type_value: Int,
  options: Int,
  specified_skeleton: Option(PtnSkeleton),
  req_field_char: String,
  req_field_len: Int,
  field_len: Int,
  row: DtType,
) -> Int {
  case
    {
      type_value == udatpg_hour_field
      && int.bitwise_and(options, udatpg_match_hour_field_length()) == 0
    }
    || {
      type_value == udatpg_minute_field
      && int.bitwise_and(options, udatpg_match_minute_field_length()) == 0
    }
    || {
      type_value == udatpg_second_field
      && int.bitwise_and(options, udatpg_match_second_field_length()) == 0
    }
  {
    True -> field_len
    False ->
      case specified_skeleton {
        None -> req_field_len
        Some(spec) ->
          case req_field_char == "c" || req_field_char == "e" {
            True -> req_field_len
            False -> {
              let skel_field_len =
                skeleton_fields_get_field_length(spec.original, type_value)
              let pat_field_is_numeric = row.type_ > 0
              let req_field_is_numeric =
                dict_int_get(dtpg.dt_matcher.skeleton.type_, type_value, 0) > 0
              case
                skel_field_len == req_field_len
                || { pat_field_is_numeric && !req_field_is_numeric }
                || { req_field_is_numeric && !pat_field_is_numeric }
              {
                True -> field_len
                False -> req_field_len
              }
            }
          }
      }
  }
}

pub type GetBestRawResult {
  GetBestRawResult(
    pattern: Option(String),
    specified_skeleton: Option(PtnSkeleton),
    missing_fields: DistanceInfo,
  )
}

fn dtpg_get_top_bit_number(found_mask: Int) -> Int {
  case found_mask == 0 {
    True -> 0
    False -> {
      let i = top_bit_number_loop(found_mask, 0)
      case i - 1 > udatpg_zone_field {
        True -> udatpg_zone_field
        False -> i - 1
      }
    }
  }
}

fn top_bit_number_loop(found_mask: Int, i: Int) -> Int {
  case found_mask == 0 {
    True -> i
    False -> top_bit_number_loop(int.bitwise_shift_right(found_mask, 1), i + 1)
  }
}

pub type BestAppendingResult {
  BestAppendingResult(dtpg: DateTimePatternGenerator, result_pattern: String)
}

pub fn dtpg_get_best_appending(
  dtpg: DateTimePatternGenerator,
  missing_fields: Int,
  flags: Int,
  options: Int,
) -> BestAppendingResult {
  case missing_fields == 0 {
    True -> BestAppendingResult(dtpg, "")
    False -> {
      let r =
        dtpg_get_best_raw(
          dtpg,
          dtpg.dt_matcher,
          missing_fields,
          dtpg.distance_info,
        )
      let dtpg =
        DateTimePatternGenerator(..dtpg, distance_info: r.missing_fields)
      let result_pattern =
        dtpg_adjust_field_types(
          dtpg,
          option.unwrap(r.pattern, ""),
          r.specified_skeleton,
          flags,
          options,
        )
      case dtpg.distance_info.missing_field_mask == 0 {
        True -> BestAppendingResult(dtpg, result_pattern)
        False ->
          best_appending_loop(
            dtpg,
            missing_fields,
            flags,
            options,
            result_pattern,
            r.specified_skeleton,
            0,
          )
      }
    }
  }
}

fn best_appending_loop(
  dtpg: DateTimePatternGenerator,
  missing_fields: Int,
  flags: Int,
  options: Int,
  result_pattern: String,
  specified_skeleton: Option(PtnSkeleton),
  last_missing_field_mask: Int,
) -> BestAppendingResult {
  case dtpg.distance_info.missing_field_mask == 0 {
    True -> BestAppendingResult(dtpg, result_pattern)
    False ->
      case last_missing_field_mask == dtpg.distance_info.missing_field_mask {
        True -> BestAppendingResult(dtpg, result_pattern)
        False ->
          case
            int.bitwise_and(
              dtpg.distance_info.missing_field_mask,
              udatpg_second_and_fractional_mask(),
            )
            == udatpg_fractional_mask()
            && int.bitwise_and(
              missing_fields,
              udatpg_second_and_fractional_mask(),
            )
            == udatpg_second_and_fractional_mask()
          {
            True -> {
              let result_pattern =
                dtpg_adjust_field_types(
                  dtpg,
                  result_pattern,
                  specified_skeleton,
                  int.bitwise_or(flags, kdtpg_fix_fractional_seconds),
                  options,
                )
              let distance_info =
                DistanceInfo(
                  ..dtpg.distance_info,
                  missing_field_mask: int.bitwise_and(
                    dtpg.distance_info.missing_field_mask,
                    int.bitwise_not(udatpg_fractional_mask()),
                  ),
                )
              let dtpg = DateTimePatternGenerator(..dtpg, distance_info:)
              best_appending_loop(
                dtpg,
                missing_fields,
                flags,
                options,
                result_pattern,
                specified_skeleton,
                last_missing_field_mask,
              )
            }
            False -> {
              let starting_mask = dtpg.distance_info.missing_field_mask
              let r =
                dtpg_get_best_raw(
                  dtpg,
                  dtpg.dt_matcher,
                  starting_mask,
                  dtpg.distance_info,
                )
              let dtpg =
                DateTimePatternGenerator(
                  ..dtpg,
                  distance_info: r.missing_fields,
                )
              let specified_skeleton = r.specified_skeleton
              let temp_pattern =
                dtpg_adjust_field_types(
                  dtpg,
                  option.unwrap(r.pattern, ""),
                  specified_skeleton,
                  flags,
                  options,
                )
              let found_mask =
                int.bitwise_and(
                  starting_mask,
                  int.bitwise_not(dtpg.distance_info.missing_field_mask),
                )
              let top_field = dtpg_get_top_bit_number(found_mask)

              let append_format =
                dict_string_get(dtpg.append_item_formats, top_field, "")
              let result_pattern = case append_format != "" {
                False -> result_pattern
                True -> {
                  let append_name =
                    "'"
                    <> field_display_name_get(
                      dtpg.field_display_names,
                      top_field,
                      udatpg_width_appenditem,
                    )
                    <> "'"
                  simple_format(append_format, [
                    result_pattern,
                    temp_pattern,
                    append_name,
                  ])
                }
              }
              best_appending_loop(
                dtpg,
                missing_fields,
                flags,
                options,
                result_pattern,
                specified_skeleton,
                dtpg.distance_info.missing_field_mask,
              )
            }
          }
      }
  }
}

fn list_first(items: List(a), default: a) -> a {
  case items {
    [item, ..] -> item
    [] -> default
  }
}

pub type BestPatternResult {
  BestPatternResult(dtpg: DateTimePatternGenerator, result: String)
}

pub fn dtpg_get_best_pattern(
  dtpg: DateTimePatternGenerator,
  skeleton: String,
  options: Int,
) -> BestPatternResult {
  let date_mask = int.bitwise_shift_left(1, udatpg_dayperiod_field) - 1
  let time_mask = int.bitwise_shift_left(1, udatpg_field_count) - 1 - date_mask

  let map_result = dtpg_map_skeleton_metacharacters(dtpg, skeleton)
  let pattern_form_mapped = map_result.mapped
  let flags = map_result.flags

  let #(matcher, new_fp, _skeleton) =
    date_time_matcher_set(pattern_form_mapped, dtpg.fp)
  let dtpg = DateTimePatternGenerator(..dtpg, dt_matcher: matcher, fp: new_fp)

  let best = dtpg_get_best_raw(dtpg, dtpg.dt_matcher, -1, dtpg.distance_info)
  let dtpg =
    DateTimePatternGenerator(..dtpg, distance_info: best.missing_fields)

  case
    dtpg.distance_info.missing_field_mask == 0
    && dtpg.distance_info.extra_field_mask == 0
  {
    True ->
      BestPatternResult(
        dtpg,
        dtpg_adjust_field_types(
          dtpg,
          option.unwrap(best.pattern, ""),
          best.specified_skeleton,
          flags,
          options,
        ),
      )
    False -> {
      let needed_fields = date_time_matcher_get_field_mask(dtpg.dt_matcher)
      let date_result =
        dtpg_get_best_appending(
          dtpg,
          int.bitwise_and(needed_fields, date_mask),
          flags,
          options,
        )
      let dtpg = date_result.dtpg
      let date_pattern = date_result.result_pattern
      let time_result =
        dtpg_get_best_appending(
          dtpg,
          int.bitwise_and(needed_fields, time_mask),
          flags,
          options,
        )
      let dtpg = time_result.dtpg
      let time_pattern = time_result.result_pattern
      case date_pattern == "", time_pattern == "" {
        True, True -> BestPatternResult(dtpg, "")
        True, False -> BestPatternResult(dtpg, time_pattern)
        False, True -> BestPatternResult(dtpg, date_pattern)
        False, False -> {
          let req_skeleton = date_time_matcher_get_skeleton_ptr(dtpg.dt_matcher)
          let style = get_date_time_format_style(req_skeleton)
          let dt_format = date_time_format_get(dtpg.date_time_format, style)
          BestPatternResult(
            dtpg,
            simple_format(dt_format, [time_pattern, date_pattern]),
          )
        }
      }
    }
  }
}

pub fn dtpg_get_best_pattern_with_options(
  dtpg: DateTimePatternGenerator,
  skeleton: String,
  options: Int,
) -> BestPatternResult {
  dtpg_get_best_pattern(dtpg, skeleton, options)
}

pub fn dtpg_get_default_hour_cycle(
  dtpg: DateTimePatternGenerator,
) -> Result(Int, String) {
  case dtpg.default_hour_format_char == "\u{0}" {
    True -> Error("U_UNSUPPORTED_ERROR")
    False ->
      case dtpg.default_hour_format_char {
        "K" -> Ok(udat_hour_cycle_11)
        "h" -> Ok(udat_hour_cycle_12)
        "H" -> Ok(udat_hour_cycle_23)
        "k" -> Ok(udat_hour_cycle_24)
        _ -> Ok(udat_hour_cycle_23)
      }
  }
}

pub type RedundantsResult {
  RedundantsResult(
    dtpg: DateTimePatternGenerator,
    output: DtRedundantEnumeration,
  )
}

pub fn dtpg_get_best_raw(
  dtpg: DateTimePatternGenerator,
  source: DateTimeMatcher,
  include_mask: Int,
  missing_fields: DistanceInfo,
) -> GetBestRawResult {
  let elems = pattern_map_all_elems(dtpg.pattern_map)
  dtpg_get_best_raw_loop(
    dtpg,
    source,
    include_mask,
    elems,
    0x7fffffff,
    -1,
    None,
    None,
    missing_fields,
  )
}

fn dtpg_get_best_raw_loop(
  dtpg: DateTimePatternGenerator,
  source: DateTimeMatcher,
  include_mask: Int,
  elems: List(PtnElem),
  best_distance: Int,
  best_missing_field_mask: Int,
  best_pattern: Option(String),
  specified_skeleton: Option(PtnSkeleton),
  result_missing_fields: DistanceInfo,
) -> GetBestRawResult {
  case elems {
    [] ->
      GetBestRawResult(best_pattern, specified_skeleton, result_missing_fields)
    [elem, ..rest] -> {
      let trial = DateTimeMatcher(skeleton: elem.skeleton)
      case date_time_matcher_equals(trial, dtpg.skip_matcher) {
        True ->
          dtpg_get_best_raw_loop(
            dtpg,
            source,
            include_mask,
            rest,
            best_distance,
            best_missing_field_mask,
            best_pattern,
            specified_skeleton,
            result_missing_fields,
          )
        False -> {
          let #(distance, distance_info) =
            date_time_matcher_get_distance_bounded(
              source,
              trial,
              include_mask,
              best_distance,
            )
          case
            distance < best_distance
            || {
              distance == best_distance
              && best_missing_field_mask < distance_info.missing_field_mask
            }
          {
            False ->
              dtpg_get_best_raw_loop(
                dtpg,
                source,
                include_mask,
                rest,
                best_distance,
                best_missing_field_mask,
                best_pattern,
                specified_skeleton,
                result_missing_fields,
              )
            True -> {
              let specified_skeleton = case elem.skeleton_was_specified {
                True -> Some(elem.skeleton)
                False -> None
              }
              case distance == 0 {
                True ->
                  GetBestRawResult(
                    Some(elem.pattern),
                    specified_skeleton,
                    distance_info_set_to(distance_info),
                  )
                False ->
                  dtpg_get_best_raw_loop(
                    dtpg,
                    source,
                    include_mask,
                    rest,
                    distance,
                    distance_info.missing_field_mask,
                    Some(elem.pattern),
                    specified_skeleton,
                    distance_info_set_to(distance_info),
                  )
              }
            }
          }
        }
      }
    }
  }
}
