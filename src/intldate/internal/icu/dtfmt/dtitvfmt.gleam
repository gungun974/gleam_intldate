import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/calendar/calendar
import intldate/internal/icu/calendar/gregocal.{type CalendarFields}
import intldate/internal/icu/calendar/timezone
import intldate/internal/icu/dtfmt/dtitvinf.{type DateIntervalInfo}
import intldate/internal/icu/dtfmt/smpdtfmt
import intldate/internal/icu/dtptngen/udatpg
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/zonemeta

pub type DateIntervalSide {
  DateIntervalSide(
    fields: CalendarFields,
    raw_offset: Int,
    dst_offset: Int,
    tz: String,
    epoch_millis: Int,
  )
}

pub type DateTimeSkeletonParts {
  DateTimeSkeletonParts(
    date_skeleton: String,
    normalized_date_skeleton: String,
    time_skeleton: String,
    normalized_time_skeleton: String,
  )
}

pub type IntervalPatternEntry {
  IntervalPatternEntry(
    first_part: Option(String),
    second_part: String,
    later_date_first: Bool,
  )
}

type IntervalPatternMap =
  Dict(String, IntervalPatternEntry)

pub type DateIntervalFormat {
  DateIntervalFormat(
    bundle: Bundle,
    locale_id: String,
    cal_type: String,
    skeleton: String,
    info: DateIntervalInfo,
    patterns: IntervalPatternMap,
    date_pattern: Option(String),
    time_pattern: Option(String),
    date_time_combining_pattern: Option(String),
    f_capitalization_context: Int,
    time_zone: Option(String),
    full_pattern: Option(String),
  )
}

pub type SetIntervalPatternForFieldResult {
  SetIntervalPatternForFieldResult(
    patterns: IntervalPatternMap,
    extended: Bool,
    extended_skeleton: Option(String),
    extended_best_skeleton: Option(String),
  )
}

pub type SetSeparateDateTimePtnResult {
  SetSeparateDateTimePtnResult(fmt: DateIntervalFormat, found: Bool)
}

pub type SourcedFormatPart {
  SourcedFormatPart(
    type_: String,
    ch: Option(String),
    value: String,
    start: Int,
    end: Int,
    source: String,
  )
}

pub type DateIntervalFormatResult {
  DateIntervalFormatResult(formatted: String, parts: List(SourcedFormatPart))
}

pub type DateIntervalFormatResultWithIndex {
  DateIntervalFormatResultWithIndex(
    formatted: String,
    parts: List(SourcedFormatPart),
    first_index: Int,
  )
}

pub type DtInterval {
  DtInterval(tz: String, from_millis: Int, to_millis: Int)
}

pub type FormattedDateInterval {
  FormattedDateInterval(
    f_data: Option(DateIntervalFormatResult),
    f_error_code: Int,
  )
}

pub type FormattedDateIntervalResultWrapper {
  FormattedDateIntervalResultWrapper(value: Option(DateIntervalFormatResult))
}

fn zonemeta_bundle(bundle: Bundle) -> zonemeta.Bundle {
  zonemeta.Bundle(data_path: bundle.data_path, open_direct: fn(name) {
    resbund.open_direct_or_panic(bundle, name)
  })
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

fn is_ascii_letter(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn graphemes(s: String) -> List(String) {
  string.to_graphemes(s)
}

fn hour_chars() -> List(String) {
  ["h", "H", "K", "k"]
}

fn is_hour_char(c: String) -> Bool {
  list.contains(hour_chars(), c)
}

fn extract_hour_char(skeleton: String) -> Option(String) {
  extract_hour_char_loop(graphemes(skeleton))
}

fn extract_hour_char_loop(chars: List(String)) -> Option(String) {
  case chars {
    [] -> None
    [c, ..rest] ->
      case is_hour_char(c) {
        True -> Some(c)
        False -> extract_hour_char_loop(rest)
      }
  }
}

pub fn preserve_requested_hour_char(
  skeleton: String,
  pattern: String,
) -> String {
  case extract_hour_char(skeleton) {
    None -> pattern
    Some(requested) ->
      preserve_requested_hour_char_loop(
        graphemes(pattern),
        requested,
        False,
        "",
      )
  }
}

fn preserve_requested_hour_char_loop(
  chars: List(String),
  requested: String,
  in_quote: Bool,
  out: String,
) -> String {
  case chars {
    [] -> out
    ["'", ..rest] ->
      preserve_requested_hour_char_loop(rest, requested, !in_quote, out <> "'")
    [c, ..rest] ->
      case !in_quote && is_hour_char(c) && c != requested {
        True -> {
          let #(run_length, rest_after) = count_run(rest, c, 1)
          preserve_requested_hour_char_loop(
            rest_after,
            requested,
            in_quote,
            out <> string.repeat(requested, run_length),
          )
        }
        False ->
          preserve_requested_hour_char_loop(rest, requested, in_quote, out <> c)
      }
  }
}

fn count_run(
  chars: List(String),
  target: String,
  acc: Int,
) -> #(Int, List(String)) {
  case chars {
    [c, ..rest] if c == target -> count_run(rest, target, acc + 1)
    _ -> #(acc, chars)
  }
}

fn level_by_letter(letter: String) -> Option(Int) {
  case letter {
    "G" -> Some(0)
    "y" | "Y" | "u" | "U" | "r" -> Some(10)
    "Q" | "q" | "M" | "L" | "D" | "w" -> Some(20)
    "E" | "e" | "c" | "d" | "F" | "W" -> Some(30)
    "a" -> Some(40)
    "h" | "H" | "k" | "K" -> Some(50)
    "m" -> Some(60)
    "s" -> Some(70)
    "S" -> Some(80)
    "z" | "Z" | "v" | "V" | "O" | "X" | "x" -> Some(0)
    _ -> None
  }
}

fn field_level(field: String) -> Int {
  case field {
    "era" -> 0
    "year" -> 10
    "month" -> 20
    "date" -> 30
    "ampm" -> 40
    "hour" -> 50
    "minute" -> 60
    "second" -> 70
    "millisecond" -> 80
    _ -> -1
  }
}

fn field_letter(field: String) -> String {
  case field {
    "era" -> "G"
    "year" -> "y"
    "month" -> "M"
    "date" -> "d"
    "ampm" -> "a"
    "hour" -> "h"
    "minute" -> "m"
    _ -> ""
  }
}

pub type LetterRun {
  LetterRun(ch: Option(String), count: Int)
}

pub fn letter_runs(pattern: String) -> List(LetterRun) {
  let #(runs, prev_ch, count, _in_quote) =
    letter_runs_loop(graphemes(pattern), [], None, 0, False)
  case count > 0 {
    True -> list.reverse([LetterRun(prev_ch, count), ..runs])
    False -> list.reverse(runs)
  }
}

fn letter_runs_loop(
  chars: List(String),
  runs: List(LetterRun),
  prev_ch: Option(String),
  count: Int,
  in_quote: Bool,
) -> #(List(LetterRun), Option(String), Int, Bool) {
  case chars {
    [] -> #(runs, prev_ch, count, in_quote)
    [c, ..rest] -> {
      let #(runs, count) = case Some(c) != prev_ch && count > 0 {
        True -> #([LetterRun(prev_ch, count), ..runs], 0)
        False -> #(runs, count)
      }
      case c == "'" {
        True ->
          case rest {
            ["'", ..rest2] ->
              letter_runs_loop(rest2, runs, None, count, in_quote)
            _ -> letter_runs_loop(rest, runs, None, count, !in_quote)
          }
        False ->
          case !in_quote && is_ascii_letter(c) {
            True -> letter_runs_loop(rest, runs, Some(c), count + 1, in_quote)
            False -> letter_runs_loop(rest, runs, None, count, in_quote)
          }
      }
    }
  }
}

pub fn is_field_unit_ignored(
  skeleton_or_pattern: String,
  field_level_value: Int,
) -> Bool {
  is_field_unit_ignored_loop(
    letter_runs(skeleton_or_pattern),
    field_level_value,
  )
}

fn is_field_unit_ignored_loop(
  runs: List(LetterRun),
  field_level_value: Int,
) -> Bool {
  case runs {
    [] -> True
    [run, ..rest] ->
      case run.ch {
        None -> is_field_unit_ignored_loop(rest, field_level_value)
        Some(ch) ->
          case level_by_letter(ch) {
            None -> is_field_unit_ignored_loop(rest, field_level_value)
            Some(level) ->
              case field_level_value <= level {
                True -> False
                False -> is_field_unit_ignored_loop(rest, field_level_value)
              }
          }
      }
  }
}

pub fn split_pattern_into_2part(pattern: String) -> Int {
  let #(i, count, found_repetition, seen, prev_ch, _in_quote) =
    split_pattern_loop(graphemes(pattern), 0, [], None, 0, False, False)
  case count > 0 && !found_repetition {
    True ->
      case list.contains(seen, prev_ch) {
        True -> i - count
        False -> i
      }
    False -> i - count
  }
}

fn split_pattern_loop(
  chars: List(String),
  i: Int,
  seen: List(Option(String)),
  prev_ch: Option(String),
  count: Int,
  in_quote: Bool,
  found_repetition: Bool,
) -> #(Int, Int, Bool, List(Option(String)), Option(String), Bool) {
  case found_repetition {
    True -> #(i, count, found_repetition, seen, prev_ch, in_quote)
    False ->
      case chars {
        [] -> #(i, count, found_repetition, seen, prev_ch, in_quote)
        [c, ..rest] -> {
          let #(seen, count, found_repetition) = case
            Some(c) != prev_ch && count > 0
          {
            True ->
              case list.contains(seen, prev_ch) {
                True -> #(seen, count, True)
                False -> #([prev_ch, ..seen], 0, False)
              }
            False -> #(seen, count, found_repetition)
          }
          case found_repetition {
            True -> #(i, count, found_repetition, seen, prev_ch, in_quote)
            False ->
              case c == "'" {
                True ->
                  case rest {
                    ["'", ..rest2] ->
                      split_pattern_loop(
                        rest2,
                        i + 2,
                        seen,
                        prev_ch,
                        count,
                        in_quote,
                        found_repetition,
                      )
                    _ ->
                      split_pattern_loop(
                        rest,
                        i + 1,
                        seen,
                        prev_ch,
                        count,
                        !in_quote,
                        found_repetition,
                      )
                  }
                False ->
                  case !in_quote && is_ascii_letter(c) {
                    True ->
                      split_pattern_loop(
                        rest,
                        i + 1,
                        seen,
                        Some(c),
                        count + 1,
                        in_quote,
                        found_repetition,
                      )
                    False ->
                      split_pattern_loop(
                        rest,
                        i + 1,
                        seen,
                        prev_ch,
                        count,
                        in_quote,
                        found_repetition,
                      )
                  }
              }
          }
        }
      }
  }
}

pub fn assign_span_sources(
  parts: List(SourcedFormatPart),
  first_side_name: String,
  second_side_name: String,
) -> List(SourcedFormatPart) {
  let fields = list.filter(parts, fn(p) { p.type_ != "literal" })
  let spans = find_overlap_spans(fields)
  case spans {
    None -> list.map(parts, fn(p) { SourcedFormatPart(..p, source: "shared") })
    Some(#(s1a, s1b, s2a, s2b)) ->
      list.map(parts, fn(p) {
        case p.start >= s1a && p.end <= s1b {
          True -> SourcedFormatPart(..p, source: first_side_name)
          False ->
            case p.start >= s2a && p.end <= s2b {
              True -> SourcedFormatPart(..p, source: second_side_name)
              False -> SourcedFormatPart(..p, source: "shared")
            }
        }
      })
  }
}

fn find_overlap_spans(
  fields: List(SourcedFormatPart),
) -> Option(#(Int, Int, Int, Int)) {
  find_overlap_spans_loop(fields, None)
}

fn find_overlap_spans_loop(
  fields: List(SourcedFormatPart),
  acc: Option(#(Int, Int, Int, Int)),
) -> Option(#(Int, Int, Int, Int)) {
  case fields {
    [] -> acc
    [field_i, ..rest] -> {
      let acc = case find_first_match_type(field_i, rest) {
        None -> acc
        Some(field_j) ->
          case acc {
            None ->
              Some(#(field_i.start, field_i.end, field_j.start, field_j.end))
            Some(#(s1a, s1b, s2a, s2b)) ->
              Some(#(
                int.min(s1a, field_i.start),
                int.max(s1b, field_i.end),
                int.min(s2a, field_j.start),
                int.max(s2b, field_j.end),
              ))
          }
      }
      find_overlap_spans_loop(rest, acc)
    }
  }
}

fn find_first_match_type(
  field_i: SourcedFormatPart,
  rest: List(SourcedFormatPart),
) -> Option(SourcedFormatPart) {
  case rest {
    [] -> None
    [field_j, ..tail] ->
      case field_i.type_ == field_j.type_ {
        True -> Some(field_j)
        False -> find_first_match_type(field_i, tail)
      }
  }
}

pub fn merge_adjacent_shared_literals(
  parts: List(SourcedFormatPart),
) -> List(SourcedFormatPart) {
  list.reverse(merge_adjacent_shared_literals_loop(parts, []))
}

fn merge_adjacent_shared_literals_loop(
  parts: List(SourcedFormatPart),
  out: List(SourcedFormatPart),
) -> List(SourcedFormatPart) {
  case parts {
    [] -> out
    [p, ..rest] ->
      case out {
        [last, ..out_rest] ->
          case
            last.type_ == "literal"
            && p.type_ == "literal"
            && last.source == "shared"
            && p.source == "shared"
          {
            True ->
              merge_adjacent_shared_literals_loop(rest, [
                SourcedFormatPart(
                  ..last,
                  value: last.value <> p.value,
                  end: p.end,
                ),
                ..out_rest
              ])
            False -> merge_adjacent_shared_literals_loop(rest, [p, ..out])
          }
        [] -> merge_adjacent_shared_literals_loop(rest, [p])
      }
  }
}

pub fn find_replace_in_pattern(
  target_string: String,
  str_to_replace: String,
  str_to_replace_with: String,
) -> String {
  case string_index_of(target_string, "'", 0) {
    None -> string.replace(target_string, str_to_replace, str_to_replace_with)
    Some(_) ->
      find_replace_in_pattern_loop(
        target_string,
        str_to_replace,
        str_to_replace_with,
        "",
      )
  }
}

fn find_replace_in_pattern_loop(
  source: String,
  str_to_replace: String,
  str_to_replace_with: String,
  result: String,
) -> String {
  case string_index_of(source, "'", 0) {
    None ->
      result <> string.replace(source, str_to_replace, str_to_replace_with)
    Some(first_quote_index) -> {
      let second_quote_index = case
        string_index_of(source, "'", first_quote_index + 1)
      {
        Some(idx) -> idx
        None -> string.length(source) - 1
      }
      let unquoted_text = string.slice(source, 0, first_quote_index)
      let quoted_text =
        string.slice(
          source,
          first_quote_index,
          second_quote_index + 1 - first_quote_index,
        )
      let unquoted_text =
        string.replace(unquoted_text, str_to_replace, str_to_replace_with)
      let result = result <> unquoted_text <> quoted_text
      let rest_len = string.length(source) - { second_quote_index + 1 }
      let new_source = string.slice(source, second_quote_index + 1, rest_len)
      find_replace_in_pattern_loop(
        new_source,
        str_to_replace,
        str_to_replace_with,
        result,
      )
    }
  }
}

fn string_index_of(haystack: String, needle: String, from: Int) -> Option(Int) {
  case from > string.length(haystack) {
    True -> None
    False -> {
      let tail = string.slice(haystack, from, string.length(haystack) - from)
      case string.split_once(tail, needle) {
        Error(_) -> None
        Ok(#(before, _after)) -> Some(from + string.length(before))
      }
    }
  }
}

pub fn collapse_hour_runs(skeleton: String) -> String {
  collapse_hour_runs_loop(graphemes(skeleton), None, "")
}

fn collapse_hour_runs_loop(
  chars: List(String),
  prev: Option(String),
  out: String,
) -> String {
  case chars {
    [] -> out
    [c, ..rest] ->
      case is_hour_char(c) && Some(c) == prev {
        True -> collapse_hour_runs_loop(rest, prev, out)
        False -> collapse_hour_runs_loop(rest, Some(c), out <> c)
      }
  }
}

pub fn field_exists_in_skeleton(
  field_letter_value: String,
  skeleton: String,
) -> Bool {
  string.contains(skeleton, field_letter_value)
}

pub fn adjust_field_width(
  input_skeleton: String,
  best_match_skeleton: String,
  best_interval_pattern: String,
  difference_info: Int,
  suppress_day_period_field: Bool,
) -> String {
  let adjusted_ptn = case suppress_day_period_field {
    False -> best_interval_pattern
    True ->
      best_interval_pattern
      |> find_replace_in_pattern("\u{00a0}a", "")
      |> find_replace_in_pattern("\u{202f}a", "")
      |> find_replace_in_pattern("a\u{00a0}", "")
      |> find_replace_in_pattern("a\u{202f}", "")
      |> find_replace_in_pattern("a", "")
      |> find_replace_in_pattern("  ", " ")
      |> string.trim
  }

  let adjusted_ptn = case difference_info == 2 {
    False -> adjusted_ptn
    True ->
      adjusted_ptn
      |> apply_when(
        string.contains(input_skeleton, "z"),
        find_replace_in_pattern(_, "v", "z"),
      )
      |> apply_when(
        string.contains(input_skeleton, "K"),
        find_replace_in_pattern(_, "h", "K"),
      )
      |> apply_when(
        string.contains(input_skeleton, "k"),
        find_replace_in_pattern(_, "H", "k"),
      )
      |> apply_when(
        string.contains(input_skeleton, "b"),
        find_replace_in_pattern(_, "a", "b"),
      )
  }

  let input_width = char_counts(input_skeleton)
  let best_width = char_counts(best_match_skeleton)
  let best_width = case
    string.contains(adjusted_ptn, "a") && !dict.has_key(best_width, "a")
  {
    True -> dict.insert(best_width, "a", 1)
    False -> best_width
  }
  let best_width = case
    string.contains(adjusted_ptn, "b") && !dict.has_key(best_width, "b")
  {
    True -> dict.insert(best_width, "b", 1)
    False -> best_width
  }

  adjust_field_width_render(adjusted_ptn, input_width, best_width)
}

fn apply_when(value: a, condition: Bool, f: fn(a) -> a) -> a {
  case condition {
    True -> f(value)
    False -> value
  }
}

fn char_counts(s: String) -> Dict(String, Int) {
  char_counts_loop(graphemes(s), dict.new())
}

fn char_counts_loop(
  chars: List(String),
  acc: Dict(String, Int),
) -> Dict(String, Int) {
  case chars {
    [] -> acc
    [c, ..rest] -> {
      let count = case dict.get(acc, c) {
        Ok(n) -> n
        Error(_) -> 0
      }
      char_counts_loop(rest, dict.insert(acc, c, count + 1))
    }
  }
}

fn adjust_field_width_render(
  pattern: String,
  input_width: Dict(String, Int),
  best_width: Dict(String, Int),
) -> String {
  let #(out, prev_ch, count, _in_quote) =
    adjust_field_width_loop(
      graphemes(pattern),
      "",
      None,
      0,
      False,
      input_width,
      best_width,
    )
  out <> flush_run(prev_ch, count, input_width, best_width)
}

fn adjust_field_width_loop(
  chars: List(String),
  out: String,
  prev_ch: Option(String),
  count: Int,
  in_quote: Bool,
  input_width: Dict(String, Int),
  best_width: Dict(String, Int),
) -> #(String, Option(String), Int, Bool) {
  case chars {
    [] -> #(out, prev_ch, count, in_quote)
    [c, ..rest] -> {
      let #(out, count) = case Some(c) != prev_ch && count > 0 {
        True -> #(out <> flush_run(prev_ch, count, input_width, best_width), 0)
        False -> #(out, count)
      }
      case c == "'" {
        True ->
          case rest {
            ["'", ..rest2] ->
              adjust_field_width_loop(
                rest2,
                out <> "''",
                None,
                count,
                in_quote,
                input_width,
                best_width,
              )
            _ ->
              adjust_field_width_loop(
                rest,
                out <> "'",
                None,
                count,
                !in_quote,
                input_width,
                best_width,
              )
          }
        False ->
          case !in_quote && is_ascii_letter(c) {
            True ->
              adjust_field_width_loop(
                rest,
                out,
                Some(c),
                count + 1,
                in_quote,
                input_width,
                best_width,
              )
            False ->
              adjust_field_width_loop(
                rest,
                out <> c,
                None,
                count,
                in_quote,
                input_width,
                best_width,
              )
          }
      }
    }
  }
}

fn flush_run(
  prev_ch: Option(String),
  count: Int,
  input_width: Dict(String, Int),
  best_width: Dict(String, Int),
) -> String {
  case count > 0, prev_ch {
    True, Some(ch) -> {
      let skeleton_char = case ch == "L" {
        True -> "M"
        False -> ch
      }
      let field_count = case dict.get(best_width, skeleton_char) {
        Ok(n) -> n
        Error(_) -> 0
      }
      let input_field_count = case dict.get(input_width, skeleton_char) {
        Ok(n) -> n
        Error(_) -> 0
      }
      let extra = case field_count == count && input_field_count > field_count {
        True -> input_field_count - field_count
        False -> 0
      }
      string.repeat(ch, count + extra)
    }
    _, _ -> ""
  }
}

pub fn get_date_time_skeleton(skeleton: String) -> DateTimeSkeletonParts {
  get_date_time_skeleton_loop(
    graphemes(skeleton),
    "",
    "",
    "",
    "",
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    "",
  )
}

fn get_date_time_skeleton_loop(
  chars: List(String),
  date_skeleton: String,
  normalized_date_skeleton: String,
  time_skeleton: String,
  normalized_time_skeleton: String,
  e_count: Int,
  d_count: Int,
  m_count: Int,
  y_count: Int,
  m_minute_count: Int,
  v_count: Int,
  z_count: Int,
  hour_char: String,
) -> DateTimeSkeletonParts {
  case chars {
    [] -> {
      let normalized_date_skeleton = case y_count != 0 {
        True -> normalized_date_skeleton <> string.repeat("y", y_count)
        False -> normalized_date_skeleton
      }
      let normalized_date_skeleton = case m_count != 0 {
        True ->
          normalized_date_skeleton
          <> case m_count < 3 {
            True -> "M"
            False -> string.repeat("M", int.min(m_count, 5))
          }
        False -> normalized_date_skeleton
      }
      let normalized_date_skeleton = case e_count != 0 {
        True ->
          normalized_date_skeleton
          <> case e_count <= 3 {
            True -> "E"
            False -> string.repeat("E", int.min(e_count, 5))
          }
        False -> normalized_date_skeleton
      }
      let normalized_date_skeleton = case d_count != 0 {
        True -> normalized_date_skeleton <> "d"
        False -> normalized_date_skeleton
      }
      let normalized_time_skeleton = case hour_char != "" {
        True -> normalized_time_skeleton <> hour_char
        False -> normalized_time_skeleton
      }
      let normalized_time_skeleton = case m_minute_count != 0 {
        True -> normalized_time_skeleton <> "m"
        False -> normalized_time_skeleton
      }
      let normalized_time_skeleton = case z_count != 0 {
        True -> normalized_time_skeleton <> "z"
        False -> normalized_time_skeleton
      }
      let normalized_time_skeleton = case v_count != 0 {
        True -> normalized_time_skeleton <> "v"
        False -> normalized_time_skeleton
      }
      DateTimeSkeletonParts(
        date_skeleton:,
        normalized_date_skeleton:,
        time_skeleton:,
        normalized_time_skeleton:,
      )
    }
    [ch, ..rest] ->
      case ch {
        "E" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton <> ch,
            normalized_date_skeleton,
            time_skeleton,
            normalized_time_skeleton,
            e_count + 1,
            d_count,
            m_count,
            y_count,
            m_minute_count,
            v_count,
            z_count,
            hour_char,
          )
        "d" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton <> ch,
            normalized_date_skeleton,
            time_skeleton,
            normalized_time_skeleton,
            e_count,
            d_count + 1,
            m_count,
            y_count,
            m_minute_count,
            v_count,
            z_count,
            hour_char,
          )
        "M" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton <> ch,
            normalized_date_skeleton,
            time_skeleton,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count + 1,
            y_count,
            m_minute_count,
            v_count,
            z_count,
            hour_char,
          )
        "y" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton <> ch,
            normalized_date_skeleton,
            time_skeleton,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count,
            y_count + 1,
            m_minute_count,
            v_count,
            z_count,
            hour_char,
          )
        "h" | "H" | "k" | "K" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton,
            normalized_date_skeleton,
            time_skeleton <> ch,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count,
            y_count,
            m_minute_count,
            v_count,
            z_count,
            case hour_char == "" {
              True -> ch
              False -> hour_char
            },
          )
        "m" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton,
            normalized_date_skeleton,
            time_skeleton <> ch,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count,
            y_count,
            m_minute_count + 1,
            v_count,
            z_count,
            hour_char,
          )
        "z" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton,
            normalized_date_skeleton,
            time_skeleton <> ch,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count,
            y_count,
            m_minute_count,
            v_count,
            z_count + 1,
            hour_char,
          )
        "v" ->
          get_date_time_skeleton_loop(
            rest,
            date_skeleton,
            normalized_date_skeleton,
            time_skeleton <> ch,
            normalized_time_skeleton,
            e_count,
            d_count,
            m_count,
            y_count,
            m_minute_count,
            v_count + 1,
            z_count,
            hour_char,
          )
        _ ->
          case string.contains("GYuQqLlWwDFgecUr", ch) {
            True ->
              get_date_time_skeleton_loop(
                rest,
                date_skeleton <> ch,
                normalized_date_skeleton <> ch,
                time_skeleton,
                normalized_time_skeleton,
                e_count,
                d_count,
                m_count,
                y_count,
                m_minute_count,
                v_count,
                z_count,
                hour_char,
              )
            False ->
              case string.contains("aVZjsSAbB", ch) {
                True ->
                  get_date_time_skeleton_loop(
                    rest,
                    date_skeleton,
                    normalized_date_skeleton,
                    time_skeleton <> ch,
                    normalized_time_skeleton <> ch,
                    e_count,
                    d_count,
                    m_count,
                    y_count,
                    m_minute_count,
                    v_count,
                    z_count,
                    hour_char,
                  )
                False ->
                  get_date_time_skeleton_loop(
                    rest,
                    date_skeleton,
                    normalized_date_skeleton,
                    time_skeleton,
                    normalized_time_skeleton,
                    e_count,
                    d_count,
                    m_count,
                    y_count,
                    m_minute_count,
                    v_count,
                    z_count,
                    hour_char,
                  )
              }
          }
      }
  }
}

pub fn get_best_pattern(fmt: DateIntervalFormat, skeleton: String) -> String {
  let dtpg = udatpg.udatpg_open_memo(fmt.bundle, fmt.locale_id)
  let result = udatpg.udatpg_get_best_pattern_with_options(dtpg, skeleton, 0)
  preserve_requested_hour_char(skeleton, result.pattern)
}

pub fn normalize_hour_metacharacters(
  fmt: DateIntervalFormat,
  skeleton: String,
) -> String {
  let #(
    hour_metachar,
    day_period_char,
    hour_field_start,
    hour_field_length,
    day_period_start,
    day_period_length,
  ) = scan_hour_metacharacters(graphemes(skeleton), 0, "", "", 0, 0, 0, 0)

  case hour_metachar == "" {
    True -> skeleton
    False -> {
      let converted_pattern = get_best_pattern(fmt, hour_metachar)
      let stripped_pattern = strip_quoted(converted_pattern)

      let hour_char = case string.contains(stripped_pattern, "h") {
        True -> "h"
        False ->
          case string.contains(stripped_pattern, "K") {
            True -> "K"
            False ->
              case string.contains(stripped_pattern, "k") {
                True -> "k"
                False -> "H"
              }
          }
      }

      let day_period_char = case string.contains(stripped_pattern, "b") {
        True -> "b"
        False ->
          case string.contains(stripped_pattern, "B") {
            True -> "B"
            False ->
              case day_period_char == "" {
                True -> "a"
                False -> day_period_char
              }
          }
      }

      let hour_and_day_period = case hour_char != "H" && hour_char != "k" {
        False -> hour_char
        True -> {
          let new_day_period_length = case
            day_period_length >= 5 || hour_field_length >= 5
          {
            True -> 5
            False ->
              case day_period_length >= 3 || hour_field_length >= 3 {
                True -> 3
                False -> 1
              }
          }
          hour_char <> string.repeat(day_period_char, new_day_period_length)
        }
      }

      let before_hour = string.slice(skeleton, 0, hour_field_start)
      let after_hour_len =
        string.length(skeleton) - { hour_field_start + hour_field_length }
      let after_hour =
        string.slice(
          skeleton,
          hour_field_start + hour_field_length,
          after_hour_len,
        )
      let result = before_hour <> hour_and_day_period <> after_hour

      let day_period_start = case day_period_start > hour_field_start {
        True ->
          day_period_start
          + { string.length(hour_and_day_period) - hour_field_length }
        False -> day_period_start
      }

      let before_dp = string.slice(result, 0, day_period_start)
      let after_dp_len =
        string.length(result) - { day_period_start + day_period_length }
      let after_dp =
        string.slice(result, day_period_start + day_period_length, after_dp_len)
      before_dp <> after_dp
    }
  }
}

fn strip_quoted(pattern: String) -> String {
  case string_index_of(pattern, "'", 0) {
    None -> pattern
    Some(first_quote_pos) -> {
      let second_quote_pos = case
        string_index_of(pattern, "'", first_quote_pos + 1)
      {
        Some(idx) -> idx
        None -> first_quote_pos
      }
      let before = string.slice(pattern, 0, first_quote_pos)
      let after_len = string.length(pattern) - { second_quote_pos + 1 }
      let after = string.slice(pattern, second_quote_pos + 1, after_len)
      strip_quoted(before <> after)
    }
  }
}

fn scan_hour_metacharacters(
  chars: List(String),
  i: Int,
  hour_metachar: String,
  day_period_char: String,
  hour_field_start: Int,
  hour_field_length: Int,
  day_period_start: Int,
  day_period_length: Int,
) -> #(String, String, Int, Int, Int, Int) {
  case chars {
    [] -> #(
      hour_metachar,
      day_period_char,
      hour_field_start,
      hour_field_length,
      day_period_start,
      day_period_length,
    )
    [c, ..rest] ->
      case string.contains("jJChHkK", c) {
        True -> {
          let #(hour_metachar, hour_field_start) = case hour_metachar == "" {
            True -> #(c, i)
            False -> #(hour_metachar, hour_field_start)
          }
          scan_hour_metacharacters(
            rest,
            i + 1,
            hour_metachar,
            day_period_char,
            hour_field_start,
            hour_field_length + 1,
            day_period_start,
            day_period_length,
          )
        }
        False ->
          case c == "a" || c == "b" || c == "B" {
            True -> {
              let #(day_period_char, day_period_start) = case
                day_period_char == ""
              {
                True -> #(c, i)
                False -> #(day_period_char, day_period_start)
              }
              scan_hour_metacharacters(
                rest,
                i + 1,
                hour_metachar,
                day_period_char,
                hour_field_start,
                hour_field_length,
                day_period_start,
                day_period_length + 1,
              )
            }
            False ->
              case hour_metachar != "" && day_period_char != "" {
                True -> #(
                  hour_metachar,
                  day_period_char,
                  hour_field_start,
                  hour_field_length,
                  day_period_start,
                  day_period_length,
                )
                False ->
                  scan_hour_metacharacters(
                    rest,
                    i + 1,
                    hour_metachar,
                    day_period_char,
                    hour_field_start,
                    hour_field_length,
                    day_period_start,
                    day_period_length,
                  )
              }
          }
      }
  }
}

fn set_pattern_info(
  patterns: IntervalPatternMap,
  field: String,
  first_part: Option(String),
  second_part: Option(String),
  later_date_first: Bool,
) -> IntervalPatternMap {
  let existing = case dict.get(patterns, field) {
    Ok(entry) -> entry
    Error(_) ->
      IntervalPatternEntry(
        first_part: None,
        second_part: "",
        later_date_first: later_date_first,
      )
  }
  let first_part = case first_part {
    Some(_) -> first_part
    None -> existing.first_part
  }
  let second_part = case second_part {
    Some(v) -> v
    None -> existing.second_part
  }
  dict.insert(
    patterns,
    field,
    IntervalPatternEntry(first_part:, second_part:, later_date_first:),
  )
}

pub fn set_interval_pattern(
  patterns: IntervalPatternMap,
  info: DateIntervalInfo,
  field: String,
  interval_pattern: String,
) -> IntervalPatternMap {
  let #(order, pattern) = case
    string.starts_with(interval_pattern, "latestFirst:")
  {
    True -> #(
      True,
      string.drop_start(interval_pattern, string.length("latestFirst:")),
    )
    False ->
      case string.starts_with(interval_pattern, "earliestFirst:") {
        True -> #(
          False,
          string.drop_start(interval_pattern, string.length("earliestFirst:")),
        )
        False -> #(dtitvinf.get_default_order(info), interval_pattern)
      }
  }
  let split_point = split_pattern_into_2part(pattern)
  let first_part = string.slice(pattern, 0, split_point)
  let second_part = case split_point < string.length(pattern) {
    True ->
      string.slice(pattern, split_point, string.length(pattern) - split_point)
    False -> ""
  }
  set_pattern_info(patterns, field, Some(first_part), Some(second_part), order)
}

pub fn set_fallback_pattern(
  fmt: DateIntervalFormat,
  patterns: IntervalPatternMap,
  field: String,
  skeleton: String,
) -> IntervalPatternMap {
  let pattern = get_best_pattern(fmt, skeleton)
  set_pattern_info(
    patterns,
    field,
    None,
    Some(pattern),
    dtitvinf.get_default_order(fmt.info),
  )
}

pub fn set_fallback_pattern_for_time_skeleton(
  fmt: DateIntervalFormat,
  patterns: IntervalPatternMap,
  field: String,
  skeleton: String,
) -> IntervalPatternMap {
  let pattern = get_best_pattern(fmt, collapse_hour_runs(skeleton))
  set_pattern_info(
    patterns,
    field,
    None,
    Some(pattern),
    dtitvinf.get_default_order(fmt.info),
  )
}

pub fn set_interval_pattern_for_field(
  fmt: DateIntervalFormat,
  patterns: IntervalPatternMap,
  field: String,
  skeleton: String,
  best_skeleton: String,
  difference_info: Int,
  want_extended: Bool,
) -> SetIntervalPatternForFieldResult {
  let pattern = dtitvinf.get_interval_pattern(fmt.info, best_skeleton, field)
  let suppress_day_period_field = string.contains(fmt.skeleton, "J")

  case pattern == "" {
    True ->
      case is_field_unit_ignored(best_skeleton, field_level(field)) {
        True ->
          SetIntervalPatternForFieldResult(
            patterns:,
            extended: False,
            extended_skeleton: None,
            extended_best_skeleton: None,
          )
        False ->
          case field == "ampm" {
            True -> {
              let hour_pattern =
                dtitvinf.get_interval_pattern(fmt.info, best_skeleton, "hour")
              let patterns = case hour_pattern == "" {
                True -> patterns
                False -> {
                  let adjusted =
                    adjust_field_width(
                      skeleton,
                      best_skeleton,
                      hour_pattern,
                      difference_info,
                      suppress_day_period_field,
                    )
                  set_interval_pattern(patterns, fmt.info, "ampm", adjusted)
                }
              }
              SetIntervalPatternForFieldResult(
                patterns:,
                extended: False,
                extended_skeleton: None,
                extended_best_skeleton: None,
              )
            }
            False ->
              set_interval_pattern_for_field_extended(
                fmt,
                patterns,
                field,
                skeleton,
                best_skeleton,
                difference_info,
                want_extended,
                suppress_day_period_field,
              )
          }
      }
    False ->
      finish_interval_pattern_for_field(
        patterns,
        fmt.info,
        field,
        pattern,
        best_skeleton,
        difference_info,
        skeleton,
        suppress_day_period_field,
        None,
        None,
      )
  }
}

fn set_interval_pattern_for_field_extended(
  fmt: DateIntervalFormat,
  patterns: IntervalPatternMap,
  field: String,
  skeleton: String,
  best_skeleton: String,
  difference_info: Int,
  want_extended: Bool,
  suppress_day_period_field: Bool,
) -> SetIntervalPatternForFieldResult {
  let field_letter_value = field_letter(field)
  case want_extended {
    False ->
      SetIntervalPatternForFieldResult(
        patterns:,
        extended: False,
        extended_skeleton: None,
        extended_best_skeleton: None,
      )
    True -> {
      let extended_skeleton = field_letter_value <> skeleton
      let extended_best_skeleton = field_letter_value <> best_skeleton
      let pattern =
        dtitvinf.get_interval_pattern(fmt.info, extended_best_skeleton, field)
      case pattern == "" && difference_info == 0 {
        True -> {
          let best =
            dtitvinf.get_best_skeleton(fmt.info, extended_best_skeleton)
          case best.best_skeleton, best.difference_info != -1 {
            Some(tmp_best), True -> {
              let pattern =
                dtitvinf.get_interval_pattern(fmt.info, tmp_best, field)
              case pattern == "" {
                True ->
                  SetIntervalPatternForFieldResult(
                    patterns:,
                    extended: False,
                    extended_skeleton: Some(extended_skeleton),
                    extended_best_skeleton: Some(extended_best_skeleton),
                  )
                False ->
                  finish_interval_pattern_for_field(
                    patterns,
                    fmt.info,
                    field,
                    pattern,
                    tmp_best,
                    best.difference_info,
                    skeleton,
                    suppress_day_period_field,
                    Some(extended_skeleton),
                    Some(extended_best_skeleton),
                  )
              }
            }
            _, _ ->
              SetIntervalPatternForFieldResult(
                patterns:,
                extended: False,
                extended_skeleton: Some(extended_skeleton),
                extended_best_skeleton: Some(extended_best_skeleton),
              )
          }
        }
        False ->
          case pattern == "" {
            True ->
              SetIntervalPatternForFieldResult(
                patterns:,
                extended: False,
                extended_skeleton: Some(extended_skeleton),
                extended_best_skeleton: Some(extended_best_skeleton),
              )
            False ->
              finish_interval_pattern_for_field(
                patterns,
                fmt.info,
                field,
                pattern,
                extended_best_skeleton,
                difference_info,
                skeleton,
                suppress_day_period_field,
                Some(extended_skeleton),
                Some(extended_best_skeleton),
              )
          }
      }
    }
  }
}

fn finish_interval_pattern_for_field(
  patterns: IntervalPatternMap,
  info: DateIntervalInfo,
  field: String,
  pattern: String,
  used_best_skeleton: String,
  used_difference_info: Int,
  skeleton: String,
  suppress_day_period_field: Bool,
  extended_skeleton: Option(String),
  extended_best_skeleton: Option(String),
) -> SetIntervalPatternForFieldResult {
  let next_patterns = case
    used_difference_info != 0 || suppress_day_period_field
  {
    True -> {
      let adjusted =
        adjust_field_width(
          skeleton,
          used_best_skeleton,
          pattern,
          used_difference_info,
          suppress_day_period_field,
        )
      set_interval_pattern(patterns, info, field, adjusted)
    }
    False -> set_interval_pattern(patterns, info, field, pattern)
  }
  let extended = option.is_some(extended_skeleton)
  SetIntervalPatternForFieldResult(
    patterns: next_patterns,
    extended:,
    extended_skeleton:,
    extended_best_skeleton:,
  )
}

pub fn set_separate_date_time_ptn(
  fmt: DateIntervalFormat,
  date_skeleton: String,
  time_skeleton: String,
) -> SetSeparateDateTimePtnResult {
  let skeleton = case string.length(time_skeleton) != 0 {
    True -> time_skeleton
    False -> date_skeleton
  }
  let best = dtitvinf.get_best_skeleton(fmt.info, skeleton)

  case best.best_skeleton {
    None -> SetSeparateDateTimePtnResult(fmt:, found: False)
    Some(best_skeleton) -> {
      let next_fmt = case string.length(date_skeleton) != 0 {
        True ->
          DateIntervalFormat(
            ..fmt,
            date_pattern: Some(get_best_pattern(fmt, date_skeleton)),
          )
        False -> fmt
      }
      let next_fmt = case string.length(time_skeleton) != 0 {
        True ->
          DateIntervalFormat(
            ..next_fmt,
            time_pattern: Some(get_best_pattern(next_fmt, time_skeleton)),
          )
        False -> next_fmt
      }

      case best.difference_info == -1 {
        True -> SetSeparateDateTimePtnResult(fmt: next_fmt, found: False)
        False ->
          case string.length(time_skeleton) == 0 {
            True -> {
              let date_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "date",
                  skeleton,
                  best_skeleton,
                  best.difference_info,
                  True,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: date_result.patterns)
              let month_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "month",
                  skeleton,
                  best_skeleton,
                  best.difference_info,
                  True,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: month_result.patterns)
              let #(effective_skeleton, effective_best_skeleton) = case
                month_result.extended
              {
                True -> #(
                  option.unwrap(month_result.extended_skeleton, skeleton),
                  option.unwrap(
                    month_result.extended_best_skeleton,
                    best_skeleton,
                  ),
                )
                False -> #(skeleton, best_skeleton)
              }
              let year_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "year",
                  effective_skeleton,
                  effective_best_skeleton,
                  best.difference_info,
                  True,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: year_result.patterns)
              let era_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "era",
                  effective_skeleton,
                  effective_best_skeleton,
                  best.difference_info,
                  True,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: era_result.patterns)
              SetSeparateDateTimePtnResult(fmt: next_fmt, found: True)
            }
            False -> {
              let minute_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "minute",
                  skeleton,
                  best_skeleton,
                  best.difference_info,
                  False,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: minute_result.patterns)
              let hour_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "hour",
                  skeleton,
                  best_skeleton,
                  best.difference_info,
                  False,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: hour_result.patterns)
              let ampm_result =
                set_interval_pattern_for_field(
                  next_fmt,
                  next_fmt.patterns,
                  "ampm",
                  skeleton,
                  best_skeleton,
                  best.difference_info,
                  False,
                )
              let next_fmt =
                DateIntervalFormat(..next_fmt, patterns: ampm_result.patterns)
              SetSeparateDateTimePtnResult(fmt: next_fmt, found: True)
            }
          }
      }
    }
  }
}

pub fn concat_single_date_2_time_interval(
  fmt: DateIntervalFormat,
  date_pattern: String,
  field: String,
) -> DateIntervalFormat {
  case dict.get(fmt.patterns, field) {
    Error(_) -> fmt
    Ok(time_itv_ptn_info) ->
      case time_itv_ptn_info.first_part {
        None -> fmt
        Some(first_part) -> {
          let time_interval_pattern =
            first_part <> time_itv_ptn_info.second_part
          let combining = option.unwrap(fmt.date_time_combining_pattern, "")
          let idx0 = case string_index_of(combining, "{0}", 0) {
            Some(idx) -> idx
            None -> 0
          }
          let idx1 = case string_index_of(combining, "{1}", 0) {
            Some(idx) -> idx
            None -> 0
          }
          let min_idx = int.min(idx0, idx1)
          let max_idx = int.max(idx0, idx1)
          let combined_pattern =
            string.slice(combining, 0, min_idx)
            <> case idx0 < idx1 {
              True -> time_interval_pattern
              False -> date_pattern
            }
            <> string.slice(combining, min_idx + 3, max_idx - { min_idx + 3 })
            <> case idx0 < idx1 {
              True -> date_pattern
              False -> time_interval_pattern
            }
            <> string.slice(
              combining,
              max_idx + 3,
              string.length(combining) - { max_idx + 3 },
            )
          let patterns =
            set_interval_pattern(
              fmt.patterns,
              fmt.info,
              field,
              combined_pattern,
            )
          let patterns = case dict.get(patterns, field) {
            Ok(entry) ->
              dict.insert(
                patterns,
                field,
                IntervalPatternEntry(
                  ..entry,
                  later_date_first: time_itv_ptn_info.later_date_first,
                ),
              )
            Error(_) -> patterns
          }
          DateIntervalFormat(..fmt, patterns:)
        }
      }
  }
}

pub fn set_date_time_combined_pattern(
  fmt: DateIntervalFormat,
  date_skeleton: String,
  _time_skeleton: String,
) -> DateIntervalFormat {
  let skeleton = fmt.skeleton
  let #(skeleton, next_fmt) = case
    field_exists_in_skeleton("d", date_skeleton)
  {
    True -> #(skeleton, fmt)
    False -> {
      let skeleton = "d" <> skeleton
      #(
        skeleton,
        DateIntervalFormat(
          ..fmt,
          patterns: set_fallback_pattern(fmt, fmt.patterns, "date", skeleton),
        ),
      )
    }
  }
  let #(skeleton, next_fmt) = case
    field_exists_in_skeleton("M", date_skeleton)
  {
    True -> #(skeleton, next_fmt)
    False -> {
      let skeleton = "M" <> skeleton
      #(
        skeleton,
        DateIntervalFormat(
          ..next_fmt,
          patterns: set_fallback_pattern(
            next_fmt,
            next_fmt.patterns,
            "month",
            skeleton,
          ),
        ),
      )
    }
  }
  let #(skeleton, next_fmt) = case
    field_exists_in_skeleton("y", date_skeleton)
  {
    True -> #(skeleton, next_fmt)
    False -> {
      let skeleton = "y" <> skeleton
      #(
        skeleton,
        DateIntervalFormat(
          ..next_fmt,
          patterns: set_fallback_pattern(
            next_fmt,
            next_fmt.patterns,
            "year",
            skeleton,
          ),
        ),
      )
    }
  }
  let #(_skeleton, next_fmt) = case
    field_exists_in_skeleton("G", date_skeleton)
  {
    True -> #(skeleton, next_fmt)
    False -> {
      let skeleton = "G" <> skeleton
      #(
        skeleton,
        DateIntervalFormat(
          ..next_fmt,
          patterns: set_fallback_pattern(
            next_fmt,
            next_fmt.patterns,
            "era",
            skeleton,
          ),
        ),
      )
    }
  }

  case next_fmt.date_time_combining_pattern {
    None -> next_fmt
    Some(_) -> {
      let date_pattern = get_best_pattern(next_fmt, date_skeleton)
      let next_fmt =
        concat_single_date_2_time_interval(next_fmt, date_pattern, "ampm")
      let next_fmt =
        concat_single_date_2_time_interval(next_fmt, date_pattern, "hour")
      concat_single_date_2_time_interval(next_fmt, date_pattern, "minute")
    }
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

pub fn initialize_pattern(fmt: DateIntervalFormat) -> DateIntervalFormat {
  let converted_skeleton = normalize_hour_metacharacters(fmt, fmt.skeleton)
  let parts = get_date_time_skeleton(converted_skeleton)

  let has_both =
    string.length(parts.time_skeleton) > 0
    && string.length(parts.date_skeleton) > 0

  let next_fmt = case has_both {
    False -> fmt
    True -> {
      let chain =
        resbund.open_locale_chain(
          fmt.bundle,
          uloc.get_base_name(Some(fmt.locale_id)),
        )
      case
        resbund.get_by_path(
          fmt.bundle,
          chain,
          "calendar/gregorian/DateTimePatterns",
          0,
        )
      {
        None -> fmt
        Some(found) -> {
          let arr = resource.get_array(found.res_data, found.res)
          case arr.length > 8, arr.get_res {
            True, Some(get_res) ->
              case resource_string_text(found.res_data, get_res(8)) {
                Some(text) ->
                  DateIntervalFormat(
                    ..fmt,
                    date_time_combining_pattern: Some(text),
                  )
                None -> fmt
              }
            _, _ -> fmt
          }
        }
      }
    }
  }

  let separate_result =
    set_separate_date_time_ptn(
      next_fmt,
      parts.normalized_date_skeleton,
      parts.normalized_time_skeleton,
    )
  let next_fmt = separate_result.fmt

  case separate_result.found {
    False ->
      case
        string.length(parts.time_skeleton) != 0
        && string.length(parts.date_skeleton) == 0
      {
        True ->
          initialize_pattern_time_only_fallback(next_fmt, parts.time_skeleton)
        False -> next_fmt
      }
    True ->
      case string.length(parts.time_skeleton) == 0 {
        True -> next_fmt
        False ->
          case string.length(parts.date_skeleton) == 0 {
            True ->
              initialize_pattern_time_only_fallback(
                next_fmt,
                parts.time_skeleton,
              )
            False ->
              set_date_time_combined_pattern(
                next_fmt,
                parts.date_skeleton,
                parts.time_skeleton,
              )
          }
      }
  }
}

fn initialize_pattern_time_only_fallback(
  fmt: DateIntervalFormat,
  time_skeleton: String,
) -> DateIntervalFormat {
  let with_date = "yMd" <> time_skeleton
  let patterns =
    set_fallback_pattern_for_time_skeleton(fmt, fmt.patterns, "date", with_date)
  let fmt = DateIntervalFormat(..fmt, patterns:)
  let patterns =
    set_fallback_pattern_for_time_skeleton(
      fmt,
      fmt.patterns,
      "month",
      with_date,
    )
  let fmt = DateIntervalFormat(..fmt, patterns:)
  let patterns =
    set_fallback_pattern_for_time_skeleton(fmt, fmt.patterns, "year", with_date)
  let fmt = DateIntervalFormat(..fmt, patterns:)
  let patterns =
    set_fallback_pattern_for_time_skeleton(
      fmt,
      fmt.patterns,
      "era",
      "G" <> with_date,
    )
  DateIntervalFormat(..fmt, patterns:)
}

pub fn greatest_differing_field(
  from_fields: CalendarFields,
  to_fields: CalendarFields,
) -> Option(String) {
  case from_fields.era != to_fields.era {
    True -> Some("era")
    False ->
      case from_fields.year != to_fields.year {
        True -> Some("year")
        False ->
          case from_fields.common.month != to_fields.common.month {
            True -> Some("month")
            False ->
              case
                from_fields.common.day_of_month != to_fields.common.day_of_month
              {
                True -> Some("date")
                False ->
                  case from_fields.common.am_pm != to_fields.common.am_pm {
                    True -> Some("ampm")
                    False ->
                      case from_fields.common.hour != to_fields.common.hour {
                        True -> Some("hour")
                        False ->
                          case
                            from_fields.common.minute != to_fields.common.minute
                          {
                            True -> Some("minute")
                            False ->
                              case
                                from_fields.common.second
                                != to_fields.common.second
                              {
                                True -> Some("second")
                                False ->
                                  case
                                    from_fields.common.millisecond
                                    != to_fields.common.millisecond
                                  {
                                    True -> Some("millisecond")
                                    False -> None
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
}

fn render_single(
  fmt: DateIntervalFormat,
  pattern: String,
  side: DateIntervalSide,
  append_offset: Int,
  has_date_anchor_field_override: Option(Bool),
) -> smpdtfmt.FormatResult {
  let formatter =
    smpdtfmt.udat_open(
      fmt.bundle,
      fmt.locale_id,
      fmt.cal_type,
      side.tz,
      pattern,
    )
  let r =
    smpdtfmt.format(
      formatter,
      side.fields,
      side.raw_offset,
      side.dst_offset,
      side.epoch_millis,
      has_date_anchor_field_override,
    )
  smpdtfmt.FormatResult(
    formatted: r.formatted,
    parts: list.map(r.parts, fn(p) {
      smpdtfmt.RenderedFormatPart(
        ..p,
        start: p.start + append_offset,
        end: p.end + append_offset,
      )
    }),
  )
}

fn to_sourced_parts(
  parts: List(smpdtfmt.RenderedFormatPart),
  source: String,
) -> List(SourcedFormatPart) {
  list.map(parts, fn(p) {
    SourcedFormatPart(
      type_: p.type_,
      ch: p.ch,
      value: p.value,
      start: p.start,
      end: p.end,
      source:,
    )
  })
}

fn has_date_anchor_field_in_skeleton(skeleton: String) -> Bool {
  has_date_anchor_field_loop(graphemes(skeleton))
}

fn has_date_anchor_field_loop(chars: List(String)) -> Bool {
  case chars {
    [] -> False
    [c, ..rest] ->
      case c == "y" || c == "Y" || c == "u" || c == "d" {
        True -> True
        False -> has_date_anchor_field_loop(rest)
      }
  }
}

fn render_combined(
  fmt: DateIntervalFormat,
  from_side: DateIntervalSide,
  to_side: DateIntervalSide,
  order: IntervalPatternEntry,
) -> DateIntervalFormatResult {
  let first = case order.later_date_first {
    True -> to_side
    False -> from_side
  }
  let second = case order.later_date_first {
    True -> from_side
    False -> to_side
  }
  let first_side_name = case order.later_date_first {
    True -> "end"
    False -> "start"
  }
  let second_side_name = case order.later_date_first {
    True -> "start"
    False -> "end"
  }

  let has_date_anchor_field = has_date_anchor_field_in_skeleton(fmt.skeleton)
  let first_part = option.unwrap(order.first_part, "")

  let first_rendered =
    render_single(fmt, first_part, first, 0, Some(has_date_anchor_field))
  let text = first_rendered.formatted
  let parts = to_sourced_parts(first_rendered.parts, "")

  case order.second_part == "" {
    True -> {
      let parts = assign_span_sources(parts, first_side_name, second_side_name)
      DateIntervalFormatResult(formatted: text, parts:)
    }
    False -> {
      let second_rendered =
        render_single(
          fmt,
          order.second_part,
          second,
          string.length(text),
          Some(has_date_anchor_field),
        )
      case second_rendered.formatted == "" {
        True -> {
          let r =
            render_single(
              fmt,
              option.unwrap(fmt.full_pattern, ""),
              from_side,
              0,
              Some(has_date_anchor_field),
            )
          DateIntervalFormatResult(
            formatted: r.formatted,
            parts: to_sourced_parts(r.parts, "shared"),
          )
        }
        False -> {
          let text = text <> second_rendered.formatted
          let parts =
            list.append(parts, to_sourced_parts(second_rendered.parts, ""))
          let parts =
            assign_span_sources(parts, first_side_name, second_side_name)
          DateIntervalFormatResult(formatted: text, parts:)
        }
      }
    }
  }
}

fn fallback_format(
  fmt: DateIntervalFormat,
  from_side: DateIntervalSide,
  to_side: DateIntervalSide,
  pattern: String,
) -> DateIntervalFormatResult {
  let later_date_first = dtitvinf.get_default_order(fmt.info)
  let first = case later_date_first {
    True -> to_side
    False -> from_side
  }
  let second = case later_date_first {
    True -> from_side
    False -> to_side
  }
  let first_side_name = case later_date_first {
    True -> "end"
    False -> "start"
  }
  let second_side_name = case later_date_first {
    True -> "start"
    False -> "end"
  }

  let first_rendered = render_single(fmt, pattern, first, 0, None)
  let second_rendered = render_single(fmt, pattern, second, 0, None)

  let fallback = dtitvinf.get_fallback_interval_pattern(fmt.info)
  let idx0 = option.unwrap(string_index_of(fallback, "{0}", 0), 0)
  let idx1 = option.unwrap(string_index_of(fallback, "{1}", 0), 0)

  let #(
    first_idx,
    second_idx,
    first_text,
    second_text,
    earlier_side_name,
    later_side_name,
  ) = case idx0 < idx1 {
    True -> #(
      idx0,
      idx1,
      first_rendered,
      second_rendered,
      first_side_name,
      second_side_name,
    )
    False -> #(
      idx1,
      idx0,
      second_rendered,
      first_rendered,
      second_side_name,
      first_side_name,
    )
  }
  let before_first = string.slice(fallback, 0, first_idx)
  let between =
    string.slice(fallback, first_idx + 3, second_idx - { first_idx + 3 })
  let after_second =
    string.slice(
      fallback,
      second_idx + 3,
      string.length(fallback) - { second_idx + 3 },
    )

  let #(text, parts) = push_literal("", [], before_first)
  let #(text, parts) = push_block(text, parts, first_text, None)
  let #(text, parts) = push_literal(text, parts, between)
  let #(text, parts) = push_block(text, parts, second_text, None)
  let #(text, parts) = push_literal(text, parts, after_second)

  let parts = assign_span_sources(parts, earlier_side_name, later_side_name)
  DateIntervalFormatResult(formatted: text, parts:)
}

fn push_literal(
  text: String,
  parts: List(SourcedFormatPart),
  value: String,
) -> #(String, List(SourcedFormatPart)) {
  case value == "" {
    True -> #(text, parts)
    False -> {
      let part =
        SourcedFormatPart(
          type_: "literal",
          ch: None,
          value:,
          start: string.length(text),
          end: string.length(text) + string.length(value),
          source: "shared",
        )
      #(text <> value, list.append(parts, [part]))
    }
  }
}

fn push_block(
  text: String,
  parts: List(SourcedFormatPart),
  block: smpdtfmt.FormatResult,
  source_override: Option(String),
) -> #(String, List(SourcedFormatPart)) {
  let off = string.length(text)
  let block_parts =
    list.map(block.parts, fn(p) {
      let base =
        SourcedFormatPart(
          type_: p.type_,
          ch: p.ch,
          value: p.value,
          start: p.start + off,
          end: p.end + off,
          source: "",
        )
      case source_override {
        Some(s) -> SourcedFormatPart(..base, source: s)
        None -> base
      }
    })
  #(text <> block.formatted, list.append(parts, block_parts))
}

fn fallback_format_date_plus_time_range(
  fmt: DateIntervalFormat,
  from_side: DateIntervalSide,
  to_side: DateIntervalSide,
) -> DateIntervalFormatResult {
  let combining = option.unwrap(fmt.date_time_combining_pattern, "")
  let idx0 = option.unwrap(string_index_of(combining, "{0}", 0), 0)
  let idx1 = option.unwrap(string_index_of(combining, "{1}", 0), 0)

  let date_rendered =
    render_single(fmt, option.unwrap(fmt.date_pattern, ""), from_side, 0, None)
  let time_range_rendered =
    fallback_format(
      fmt,
      from_side,
      to_side,
      option.unwrap(fmt.time_pattern, ""),
    )

  case idx0 < idx1 {
    True -> {
      let #(text, parts) =
        push_literal("", [], string.slice(combining, 0, idx0))
      let #(text, parts) =
        push_sourced_block(
          text,
          parts,
          time_range_rendered.formatted,
          time_range_rendered.parts,
        )
      let #(text, parts) =
        push_literal(
          text,
          parts,
          string.slice(combining, idx0 + 3, idx1 - { idx0 + 3 }),
        )
      let #(text, parts) =
        push_block(text, parts, date_rendered, Some("shared"))
      let #(text, parts) =
        push_literal(
          text,
          parts,
          string.slice(
            combining,
            idx1 + 3,
            string.length(combining) - { idx1 + 3 },
          ),
        )
      DateIntervalFormatResult(formatted: text, parts:)
    }
    False -> {
      let #(text, parts) =
        push_literal("", [], string.slice(combining, 0, idx1))
      let #(text, parts) =
        push_block(text, parts, date_rendered, Some("shared"))
      let #(text, parts) =
        push_literal(
          text,
          parts,
          string.slice(combining, idx1 + 3, idx0 - { idx1 + 3 }),
        )
      let #(text, parts) =
        push_sourced_block(
          text,
          parts,
          time_range_rendered.formatted,
          time_range_rendered.parts,
        )
      let #(text, parts) =
        push_literal(
          text,
          parts,
          string.slice(
            combining,
            idx0 + 3,
            string.length(combining) - { idx0 + 3 },
          ),
        )
      DateIntervalFormatResult(formatted: text, parts:)
    }
  }
}

fn push_sourced_block(
  text: String,
  parts: List(SourcedFormatPart),
  formatted: String,
  block_parts: List(SourcedFormatPart),
) -> #(String, List(SourcedFormatPart)) {
  let off = string.length(text)
  let mapped =
    list.map(block_parts, fn(p) {
      SourcedFormatPart(..p, start: p.start + off, end: p.end + off)
    })
  #(text <> formatted, list.append(parts, mapped))
}

pub fn format(
  fmt: DateIntervalFormat,
  from_side: DateIntervalSide,
  to_side: DateIntervalSide,
) -> DateIntervalFormatResult {
  case greatest_differing_field(from_side.fields, to_side.fields) {
    None -> {
      let r =
        render_single(
          fmt,
          option.unwrap(fmt.full_pattern, ""),
          from_side,
          0,
          None,
        )
      DateIntervalFormatResult(
        formatted: r.formatted,
        parts: to_sourced_parts(r.parts, "shared"),
      )
    }
    Some(field) -> {
      let pattern_info = dict.get(fmt.patterns, field)
      case pattern_info {
        Ok(info) if info.first_part != None -> {
          let r = render_combined(fmt, from_side, to_side, info)
          DateIntervalFormatResult(
            formatted: r.formatted,
            parts: merge_adjacent_shared_literals(r.parts),
          )
        }
        _ ->
          case
            pattern_info,
            is_field_unit_ignored(
              option.unwrap(fmt.full_pattern, ""),
              field_level(field),
            )
          {
            Error(_), True -> {
              let r =
                render_single(
                  fmt,
                  option.unwrap(fmt.full_pattern, ""),
                  from_side,
                  0,
                  None,
                )
              DateIntervalFormatResult(
                formatted: r.formatted,
                parts: to_sourced_parts(r.parts, "shared"),
              )
            }
            _, _ -> {
              let from_to_on_same_day =
                field == "ampm"
                || field == "hour"
                || field == "minute"
                || field == "second"
                || field == "millisecond"
              case
                from_to_on_same_day
                && option.is_some(fmt.date_pattern)
                && option.is_some(fmt.time_pattern)
                && option.is_some(fmt.date_time_combining_pattern)
              {
                True -> {
                  let r =
                    fallback_format_date_plus_time_range(
                      fmt,
                      from_side,
                      to_side,
                    )
                  DateIntervalFormatResult(
                    formatted: r.formatted,
                    parts: merge_adjacent_shared_literals(r.parts),
                  )
                }
                False -> {
                  let field_specific_full_pattern = case pattern_info {
                    Ok(info) if info.second_part != "" -> Some(info.second_part)
                    _ -> None
                  }
                  let pattern =
                    option.unwrap(
                      field_specific_full_pattern,
                      option.unwrap(fmt.full_pattern, ""),
                    )
                  let r = fallback_format(fmt, from_side, to_side, pattern)
                  DateIntervalFormatResult(
                    formatted: r.formatted,
                    parts: merge_adjacent_shared_literals(r.parts),
                  )
                }
              }
            }
          }
      }
    }
  }
}

fn build_side(
  bundle: Bundle,
  locale_id: String,
  tz: String,
  epoch_millis: Int,
  cal_type: String,
) -> DateIntervalSide {
  let off = timezone.get_offset(zonemeta_bundle(bundle), tz, epoch_millis)
  let fields =
    calendar.compute_fields_for_calendar(
      cal_type,
      bundle,
      locale_id,
      epoch_millis,
      off.raw_offset + off.dst_offset,
    )
  DateIntervalSide(
    fields:,
    raw_offset: off.raw_offset,
    dst_offset: off.dst_offset,
    tz:,
    epoch_millis:,
  )
}

pub fn create_date_interval_format(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
  skeleton: String,
) -> DateIntervalFormat {
  let base =
    DateIntervalFormat(
      bundle:,
      locale_id:,
      cal_type:,
      skeleton:,
      info: dtitvinf.create_date_interval_info(bundle, locale_id, cal_type),
      patterns: dict.new(),
      date_pattern: None,
      time_pattern: None,
      date_time_combining_pattern: None,
      f_capitalization_context: 0,
      time_zone: None,
      full_pattern: None,
    )
  let with_pattern =
    DateIntervalFormat(
      ..base,
      full_pattern: Some(get_best_pattern(base, skeleton)),
    )
  initialize_pattern(with_pattern)
}

pub fn date_interval_format_set_time_zone(
  fmt: DateIntervalFormat,
  zone: Option(String),
) -> DateIntervalFormat {
  DateIntervalFormat(..fmt, time_zone: zone)
}

pub fn date_interval_format_get_time_zone(
  fmt: DateIntervalFormat,
) -> Option(String) {
  fmt.time_zone
}

pub fn udtitvfmt_open(
  bundle: Bundle,
  locale_id: String,
  skeleton: String,
  tz: String,
  cal_type: String,
) -> DateIntervalFormat {
  let fmt = create_date_interval_format(bundle, locale_id, cal_type, skeleton)
  date_interval_format_set_time_zone(fmt, Some(tz))
}

pub fn udtitvfmt_open_result() -> FormattedDateIntervalResultWrapper {
  FormattedDateIntervalResultWrapper(value: None)
}

pub fn udtitvfmt_result_as_value(
  result: FormattedDateIntervalResultWrapper,
) -> Option(DateIntervalFormatResult) {
  result.value
}

pub fn udtitvfmt_format_to_result(
  formatter: DateIntervalFormat,
  from_millis: Int,
  to_millis: Int,
  _result: FormattedDateIntervalResultWrapper,
) -> FormattedDateIntervalResultWrapper {
  let tz = option.unwrap(date_interval_format_get_time_zone(formatter), "")
  let from_side =
    build_side(
      formatter.bundle,
      formatter.locale_id,
      tz,
      from_millis,
      formatter.cal_type,
    )
  let to_side =
    build_side(
      formatter.bundle,
      formatter.locale_id,
      tz,
      to_millis,
      formatter.cal_type,
    )
  FormattedDateIntervalResultWrapper(
    value: Some(format(formatter, from_side, to_side)),
  )
}
