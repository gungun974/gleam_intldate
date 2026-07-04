import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/pattern

pub type Weekday {
  WeekdayNarrow
  WeekdayShort
  WeekdayLong
}

pub type Era {
  EraNarrow
  EraShort
  EraLong
}

pub type Year {
  YearTwoDigit
  YearNumeric
}

pub type Month {
  MonthTwoDigit
  MonthNumeric
  MonthNarrow
  MonthShort
  MonthLong
}

pub type Day {
  DayTwoDigit
  DayNumeric
}

pub type DayPeriod {
  DayPeriodNarrow
  DayPeriodShort
  DayPeriodLong
}

pub type HourFormat {
  HourTwoDigit
  HourNumeric
}

pub type MinuteFormat {
  MinuteTwoDigit
  MinuteNumeric
}

pub type SecondFormat {
  SecondTwoDigit
  SecondNumeric
}

pub type TimeZoneName {
  TimeZoneShort
  TimeZoneLong
  TimeZoneShortOffset
  TimeZoneLongOffset
  TimeZoneShortGeneric
  TimeZoneLongGeneric
}

pub type FractionalSecondDigits {
  OneDigit
  TwoDigits
  ThreeDigits
}

pub type Table2Key {
  Table2Era
  Table2Year
  Table2Month
  Table2Day
  Table2DayPeriod
  Table2AmPm
  Table2Hour
  Table2Minute
  Table2Second
  Table2FractionalSecondDigits
  Table2Default
}

pub type RangePatternType {
  StartRange
  Shared
  EndRange
}

pub type RangePatternPart {
  RangePatternPart(source: RangePatternType, pattern: String)
}

pub type RangePatterns {
  RangePatterns(
    weekday: Option(Weekday),
    era: Option(Era),
    year: Option(Year),
    month: Option(Month),
    day: Option(Day),
    hour: Option(HourFormat),
    minute: Option(MinuteFormat),
    second: Option(SecondFormat),
    time_zone_name: Option(TimeZoneName),
    hour12: Option(Bool),
    pattern_parts: List(RangePatternPart),
  )
}

pub type PatternStyles {
  PatternStyles(
    weekday: Option(Weekday),
    era: Option(Era),
    year: Option(Year),
    month: Option(Month),
    day: Option(Day),
    hour: Option(HourFormat),
    minute: Option(MinuteFormat),
    second: Option(SecondFormat),
  )
}

pub type Formats {
  Formats(
    weekday: Option(Weekday),
    era: Option(Era),
    year: Option(Year),
    month: Option(Month),
    day: Option(Day),
    day_period: Option(DayPeriod),
    hour: Option(HourFormat),
    minute: Option(MinuteFormat),
    second: Option(SecondFormat),
    time_zone_name: Option(TimeZoneName),
    fractional_second_digits: Option(FractionalSecondDigits),
    hour12: Option(Bool),
    pattern: List(pattern.Node),
    pattern12: List(pattern.Node),
    skeleton: String,
    canonical: Bool,
    raw_pattern: String,
    pattern_styles: PatternStyles,
    range_patterns: Dict(Table2Key, RangePatterns),
    range_patterns12: Dict(Table2Key, RangePatterns),
  )
}

type MatchResult {
  MatchResult(
    weekday: Option(Weekday),
    era: Option(Era),
    year: Option(Year),
    month: Option(Month),
    day: Option(Day),
    hour: Option(HourFormat),
    minute: Option(MinuteFormat),
    second: Option(SecondFormat),
    time_zone_name: Option(TimeZoneName),
    hour12: Option(Bool),
  )
}

fn empty_match_result() -> MatchResult {
  MatchResult(
    weekday: None,
    era: None,
    year: None,
    month: None,
    day: None,
    hour: None,
    minute: None,
    second: None,
    time_zone_name: None,
    hour12: None,
  )
}

fn match_skeleton_result(
  field: pattern.Pattern,
  len: Int,
  match_result: MatchResult,
) -> MatchResult {
  case field {
    pattern.Era ->
      MatchResult(
        ..match_result,
        era: Some(case len {
          4 -> EraLong
          5 -> EraNarrow
          _ -> EraShort
        }),
      )

    pattern.CalendarYear
    | pattern.WeekYear
    | pattern.ExtendedYear
    | pattern.CyclicYearName
    | pattern.RelatedGregorianYear ->
      MatchResult(
        ..match_result,
        year: Some(case len {
          2 -> YearTwoDigit
          _ -> YearNumeric
        }),
      )

    pattern.Quarter | pattern.StandAloneQuarter ->
      panic as "`w/Q` (quarter) patterns are not supported"

    pattern.Month | pattern.StandAloneMonth ->
      MatchResult(
        ..match_result,
        month: Some(case len {
          1 -> MonthNumeric
          2 -> MonthTwoDigit
          3 -> MonthShort
          4 -> MonthLong
          _ -> MonthNarrow
        }),
      )

    pattern.WeekOfYear | pattern.WeekOfMonth ->
      panic as "`w/W` (week of year) patterns are not supported"

    pattern.DayOfMonth ->
      MatchResult(
        ..match_result,
        day: Some(case len {
          2 -> DayTwoDigit
          _ -> DayNumeric
        }),
      )

    pattern.DayOfYear | pattern.DayOfWeekInMonth | pattern.ModifiedJulianDay ->
      MatchResult(..match_result, day: Some(DayNumeric))

    pattern.DayOfWeek ->
      MatchResult(
        ..match_result,
        weekday: Some(case len {
          4 -> WeekdayLong
          5 -> WeekdayNarrow
          _ -> WeekdayShort
        }),
      )

    pattern.LocalDayOfWeek | pattern.StandAloneDayOfWeek ->
      MatchResult(..match_result, weekday: case len {
        3 -> Some(WeekdayShort)
        4 -> Some(WeekdayLong)
        5 -> Some(WeekdayNarrow)
        6 -> Some(WeekdayShort)
        _ -> None
      })

    pattern.AmPm | pattern.AmPmNoonMidnight | pattern.FlexibleDayPeriod ->
      MatchResult(..match_result, hour12: Some(True))

    pattern.Hour12 ->
      MatchResult(
        ..match_result,
        hour: Some(case len {
          2 -> HourTwoDigit
          _ -> HourNumeric
        }),
        hour12: Some(True),
      )

    pattern.Hour24 ->
      MatchResult(
        ..match_result,
        hour: Some(case len {
          2 -> HourTwoDigit
          _ -> HourNumeric
        }),
      )

    pattern.Hour11 ->
      MatchResult(
        ..match_result,
        hour: Some(case len {
          2 -> HourTwoDigit
          _ -> HourNumeric
        }),
        hour12: Some(True),
      )

    pattern.Hour24From1 ->
      MatchResult(
        ..match_result,
        hour: Some(case len {
          2 -> HourTwoDigit
          _ -> HourNumeric
        }),
      )

    pattern.PreferredHour
    | pattern.PreferredHourNoPeriod
    | pattern.FlexibleHour ->
      panic as "`j/J/C` (hour) patterns are not supported, use `h/H/K/k` instead"

    pattern.Minute ->
      MatchResult(
        ..match_result,
        minute: Some(case len {
          2 -> MinuteTwoDigit
          _ -> MinuteNumeric
        }),
      )

    pattern.Second ->
      MatchResult(
        ..match_result,
        second: Some(case len {
          2 -> SecondTwoDigit
          _ -> SecondNumeric
        }),
      )

    pattern.FractionalSecond | pattern.MillisecondsInDay ->
      MatchResult(..match_result, second: Some(SecondNumeric))

    pattern.ShortSpecificZone
    | pattern.IsoBasicZone
    | pattern.ShortLocalizedGmt
    | pattern.ShortGenericZone
    | pattern.TimeZoneId
    | pattern.IsoBasicZoneX
    | pattern.IsoBasicZonex ->
      MatchResult(
        ..match_result,
        time_zone_name: Some(case len < 4 {
          True -> TimeZoneShort
          False -> TimeZoneLong
        }),
      )

    _ -> match_result
  }
}

fn match_skeleton_placeholder(field: pattern.Pattern) -> String {
  case field {
    pattern.Era -> "{era}"
    pattern.RelatedGregorianYear -> "{relatedYear}"
    pattern.CyclicYearName -> "{yearName}"
    pattern.CalendarYear | pattern.WeekYear | pattern.ExtendedYear -> "{year}"
    pattern.Quarter | pattern.StandAloneQuarter ->
      panic as "`w/Q` (quarter) patterns are not supported"
    pattern.Month | pattern.StandAloneMonth -> "{month}"
    pattern.WeekOfYear | pattern.WeekOfMonth ->
      panic as "`w/W` (week of year) patterns are not supported"
    pattern.DayOfMonth
    | pattern.DayOfYear
    | pattern.DayOfWeekInMonth
    | pattern.ModifiedJulianDay -> "{day}"
    pattern.DayOfWeek | pattern.LocalDayOfWeek | pattern.StandAloneDayOfWeek ->
      "{weekday}"
    pattern.AmPm | pattern.AmPmNoonMidnight | pattern.FlexibleDayPeriod ->
      "{ampm}"
    pattern.Hour12 | pattern.Hour24 | pattern.Hour11 | pattern.Hour24From1 ->
      "{hour}"
    pattern.PreferredHour
    | pattern.PreferredHourNoPeriod
    | pattern.FlexibleHour ->
      panic as "`j/J/C` (hour) patterns are not supported, use `h/H/K/k` instead"
    pattern.Minute -> "{minute}"
    pattern.Second | pattern.FractionalSecond | pattern.MillisecondsInDay ->
      "{second}"
    pattern.ShortSpecificZone
    | pattern.IsoBasicZone
    | pattern.ShortLocalizedGmt
    | pattern.ShortGenericZone
    | pattern.TimeZoneId
    | pattern.IsoBasicZoneX
    | pattern.IsoBasicZonex -> "{timeZoneName}"
    _ -> ""
  }
}

fn skeleton_token_to_table2(c: String) -> Table2Key {
  case c {
    "G" -> Table2Era
    "y" | "Y" | "u" | "U" | "r" -> Table2Year
    "M" | "L" -> Table2Month
    "d" | "D" | "F" | "g" -> Table2Day
    "a" | "b" | "B" -> Table2AmPm
    "h" | "H" | "K" | "k" -> Table2Hour
    "m" -> Table2Minute
    "s" | "S" | "A" -> Table2Second
    _ -> panic as "Invalid range pattern token"
  }
}

fn match_result_from_nodes(nodes: List(pattern.Node)) -> MatchResult {
  list.fold(nodes, empty_match_result(), fn(match_result, node) {
    case node {
      pattern.NodeField(pattern.Field(field, width)) ->
        match_skeleton_result(field, width, match_result)
      pattern.NodeText(_) -> match_result
    }
  })
}

fn collect_match_result(content: String) -> MatchResult {
  content
  |> pattern.parse
  |> match_result_from_nodes
}

pub type SkeletonInfo {
  SkeletonInfo(
    date_only: Bool,
    time_only: Bool,
    month_long: Bool,
    month_short: Bool,
    has_weekday: Bool,
  )
}

pub fn has_unsupported_field(text: String) -> Bool {
  scan_unsupported(string.to_graphemes(text), False)
}

fn scan_unsupported(graphemes: List(String), inquote: Bool) -> Bool {
  case graphemes {
    [] -> False
    ["'", ..rest] -> scan_unsupported(rest, !inquote)
    [character, ..rest] ->
      case inquote {
        True -> scan_unsupported(rest, True)
        False ->
          case character {
            "q" | "Q" | "w" | "W" | "j" | "J" | "C" -> True
            _ -> scan_unsupported(rest, False)
          }
      }
  }
}

pub fn skeleton_info(skeleton: String) -> SkeletonInfo {
  let match_result = collect_match_result(skeleton)
  SkeletonInfo(
    date_only: match_result.hour == None
      && match_result.minute == None
      && match_result.second == None
      && match_result.time_zone_name == None
      && match_result.hour12 == None,
    time_only: match_result.year == None
      && match_result.era == None
      && match_result.month == None
      && match_result.day == None
      && match_result.weekday == None,
    month_long: match_result.month == Some(MonthLong),
    month_short: match_result.month == Some(MonthShort),
    has_weekday: match_result.weekday != None,
  )
}

fn process_date_time_pattern(raw: String) -> #(String, String, MatchResult) {
  let nodes = pattern.parse(raw)

  let result = match_result_from_nodes(nodes)

  let pattern12 =
    nodes
    |> list.map(fn(node) {
      case node {
        pattern.NodeField(pattern.Field(field, _)) ->
          match_skeleton_placeholder(field)
        pattern.NodeText(text) -> text
      }
    })
    |> string.concat

  let pattern =
    pattern12
    |> strip_ampm
    |> trim_pattern_whitespace

  #(pattern, pattern12, result)
}

fn process_date_time_pattern_nodes(
  raw: String,
) -> #(List(pattern.Node), List(pattern.Node), MatchResult) {
  let pattern12 = pattern.parse(raw)

  let result = match_result_from_nodes(pattern12)

  let pattern =
    pattern12
    |> strip_ampm_nodes
    |> trim_pattern_whitespace_nodes

  #(pattern, pattern12, result)
}

fn is_ampm_pattern(p: pattern.Pattern) -> Bool {
  case p {
    pattern.AmPm | pattern.AmPmNoonMidnight | pattern.FlexibleDayPeriod -> True
    _ -> False
  }
}

fn strip_ampm_nodes(nodes: List(pattern.Node)) -> List(pattern.Node) {
  strip_ampm_nodes_loop(nodes, [])
  |> list.reverse
}

fn strip_ampm_nodes_loop(
  nodes: List(pattern.Node),
  acc: List(pattern.Node),
) -> List(pattern.Node) {
  case nodes {
    [] -> acc
    [node, ..rest] ->
      case node {
        pattern.NodeField(pattern.Field(p, _)) ->
          case is_ampm_pattern(p) {
            True -> {
              let rest = case acc_ends_with_whitespace(acc) {
                True -> drop_one_leading_whitespace(rest)
                False -> rest
              }
              strip_ampm_nodes_loop(rest, acc)
            }
            False -> strip_ampm_nodes_loop(rest, [node, ..acc])
          }
        _ -> strip_ampm_nodes_loop(rest, [node, ..acc])
      }
  }
}

fn acc_ends_with_whitespace(acc: List(pattern.Node)) -> Bool {
  case acc {
    [pattern.NodeText(text), ..] ->
      case list.last(string.to_graphemes(text)) {
        Ok(grapheme) -> is_pattern_whitespace_grapheme(grapheme)
        Error(_) -> False
      }
    _ -> False
  }
}

fn drop_one_leading_whitespace(
  nodes: List(pattern.Node),
) -> List(pattern.Node) {
  case nodes {
    [pattern.NodeText(text), ..rest] ->
      case string.pop_grapheme(text) {
        Ok(#(grapheme, tail)) ->
          case is_pattern_whitespace_grapheme(grapheme) {
            True -> [pattern.NodeText(tail), ..rest]
            False -> nodes
          }
        Error(_) -> nodes
      }
    _ -> nodes
  }
}

fn trim_pattern_whitespace_nodes(
  nodes: List(pattern.Node),
) -> List(pattern.Node) {
  nodes
  |> drop_leading_ws_nodes
  |> list.reverse
  |> drop_trailing_ws_nodes_reversed
  |> list.reverse
}

fn drop_leading_ws_nodes(nodes: List(pattern.Node)) -> List(pattern.Node) {
  case nodes {
    [pattern.NodeText(text), ..rest] -> {
      let trimmed =
        text
        |> string.to_graphemes
        |> drop_leading_whitespace
        |> string.concat
      case trimmed {
        "" -> drop_leading_ws_nodes(rest)
        _ -> [pattern.NodeText(trimmed), ..rest]
      }
    }
    _ -> nodes
  }
}

fn drop_trailing_ws_nodes_reversed(
  nodes: List(pattern.Node),
) -> List(pattern.Node) {
  case nodes {
    [pattern.NodeText(text), ..rest] -> {
      let trimmed =
        text
        |> string.to_graphemes
        |> list.reverse
        |> drop_leading_whitespace
        |> list.reverse
        |> string.concat
      case trimmed {
        "" -> drop_trailing_ws_nodes_reversed(rest)
        _ -> [pattern.NodeText(trimmed), ..rest]
      }
    }
    _ -> nodes
  }
}

fn strip_ampm(input: String) -> String {
  strip_ampm_loop(input, [])
  |> list.reverse
  |> string.concat
}

fn strip_ampm_loop(rest: String, acc: List(String)) -> List(String) {
  case rest {
    "" -> acc
    "{ampm}" <> tail -> {
      let prev_ws = case acc {
        [grapheme, ..] -> is_pattern_whitespace_grapheme(grapheme)
        [] -> False
      }
      case prev_ws, string.pop_grapheme(tail) {
        True, Ok(#(grapheme, rest_tail)) ->
          case is_pattern_whitespace_grapheme(grapheme) {
            True -> strip_ampm_loop(rest_tail, acc)
            False -> strip_ampm_loop(tail, acc)
          }
        _, _ -> strip_ampm_loop(tail, acc)
      }
    }
    _ ->
      case string.pop_grapheme(rest) {
        Ok(#(grapheme, rest2)) -> strip_ampm_loop(rest2, [grapheme, ..acc])
        Error(_) -> acc
      }
  }
}

fn trim_pattern_whitespace(input: String) -> String {
  input
  |> string.to_graphemes
  |> drop_leading_whitespace
  |> list.reverse
  |> drop_leading_whitespace
  |> list.reverse
  |> string.concat
}

fn drop_leading_whitespace(graphemes: List(String)) -> List(String) {
  case graphemes {
    [grapheme, ..rest] ->
      case is_pattern_whitespace_grapheme(grapheme) {
        True -> drop_leading_whitespace(rest)
        False -> graphemes
      }
    [] -> []
  }
}

fn is_pattern_whitespace_grapheme(grapheme: String) -> Bool {
  case string.to_utf_codepoints(grapheme) {
    [code_point] ->
      is_pattern_whitespace(string.utf_codepoint_to_int(code_point))
    _ -> False
  }
}

fn is_pattern_whitespace(code: Int) -> Bool {
  case code {
    9 | 10 | 11 | 12 | 13 | 32 -> True
    160 -> True
    5760 -> True
    8232 | 8233 -> True
    8239 -> True
    8287 -> True
    12_288 -> True
    65_279 -> True
    _ -> code >= 8192 && code <= 8202
  }
}

fn to_range_patterns(
  match_result: MatchResult,
  pattern_parts: List(RangePatternPart),
) -> RangePatterns {
  RangePatterns(
    weekday: match_result.weekday,
    era: match_result.era,
    year: match_result.year,
    month: match_result.month,
    day: match_result.day,
    hour: match_result.hour,
    minute: match_result.minute,
    second: match_result.second,
    time_zone_name: match_result.time_zone_name,
    hour12: match_result.hour12,
    pattern_parts:,
  )
}

fn build_range_patterns(
  range_patterns: Dict(String, String),
) -> #(Dict(Table2Key, RangePatterns), Dict(Table2Key, RangePatterns)) {
  dict.fold(
    range_patterns,
    #(dict.new(), dict.new()),
    fn(acc, field_key, raw_pattern) {
      let #(range_pats, range_pats12) = acc
      let key = skeleton_token_to_table2(field_key)
      let #(pattern, pattern12, interval) =
        process_date_time_pattern(raw_pattern)
      #(
        dict.insert(
          range_pats,
          key,
          to_range_patterns(interval, split_range_pattern(pattern)),
        ),
        dict.insert(
          range_pats12,
          key,
          to_range_patterns(interval, split_range_pattern(pattern12)),
        ),
      )
    },
  )
}

pub fn parse_date_time_skeleton(
  skeleton: String,
  raw_pattern: String,
  range_patterns: Option(Dict(String, String)),
  interval_format_fallback: Option(String),
) -> Formats {
  let base = collect_match_result(skeleton)
  let #(pattern, pattern12, pat) = process_date_time_pattern_nodes(raw_pattern)

  let #(range_pats, range_pats12) = case range_patterns {
    None -> #(dict.new(), dict.new())
    Some(range_patterns) -> build_range_patterns(range_patterns)
  }

  let #(range_pats, range_pats12) = case interval_format_fallback {
    None -> #(range_pats, range_pats12)
    Some(fallback) -> {
      let pattern_parts = split_fallback_range_pattern(fallback)
      let default =
        RangePatterns(
          weekday: None,
          era: None,
          year: None,
          month: None,
          day: None,
          hour: None,
          minute: None,
          second: None,
          time_zone_name: None,
          hour12: None,
          pattern_parts:,
        )
      #(
        dict.insert(range_pats, Table2Default, default),
        dict.insert(range_pats12, Table2Default, default),
      )
    }
  }

  Formats(
    weekday: base.weekday,
    era: base.era,
    year: base.year,
    month: base.month,
    day: base.day,
    day_period: None,
    hour: base.hour,
    minute: base.minute,
    second: base.second,
    time_zone_name: base.time_zone_name,
    fractional_second_digits: None,
    hour12: base.hour12,
    pattern:,
    pattern12:,
    skeleton:,
    canonical: is_canonical_skeleton(skeleton),
    raw_pattern:,
    pattern_styles: PatternStyles(
      weekday: pat.weekday,
      era: pat.era,
      year: pat.year,
      month: pat.month,
      day: pat.day,
      hour: pat.hour,
      minute: pat.minute,
      second: pat.second,
    ),
    range_patterns: range_pats,
    range_patterns12: range_pats12,
  )
}

fn is_canonical_skeleton(skeleton: String) -> Bool {
  case skeleton {
    "" -> False
    _ ->
      string.to_utf_codepoints(skeleton)
      |> list.all(fn(code_point) {
        is_canonical_skeleton_char(string.utf_codepoint_to_int(code_point))
      })
  }
}

fn is_canonical_skeleton_char(code: Int) -> Bool {
  code == 32
  || code == 44
  || { code >= 65 && code <= 90 }
  || { code >= 97 && code <= 122 }
}

pub fn split_fallback_range_pattern(pattern: String) -> List(RangePatternPart) {
  split_fallback_loop(pattern, "", [])
}

fn split_fallback_loop(
  rest: String,
  buffer: String,
  acc: List(RangePatternPart),
) -> List(RangePatternPart) {
  case rest {
    "" -> list.reverse(flush_shared(buffer, acc))
    "{0}" <> rest ->
      split_fallback_loop(rest, "", [
        RangePatternPart(StartRange, "{0}"),
        ..flush_shared(buffer, acc)
      ])
    "{1}" <> rest ->
      split_fallback_loop(rest, "", [
        RangePatternPart(EndRange, "{1}"),
        ..flush_shared(buffer, acc)
      ])
    "{|}" <> rest ->
      split_fallback_loop(rest, "", [
        RangePatternPart(Shared, "{|}"),
        ..flush_shared(buffer, acc)
      ])
    _ -> {
      let #(grapheme, rest) = case string.pop_grapheme(rest) {
        Ok(x) -> x
        Error(_) -> #("", "")
      }
      split_fallback_loop(rest, buffer <> grapheme, acc)
    }
  }
}

fn flush_shared(
  buffer: String,
  acc: List(RangePatternPart),
) -> List(RangePatternPart) {
  case buffer {
    "" -> acc
    _ -> [RangePatternPart(Shared, buffer), ..acc]
  }
}

pub fn split_range_pattern(pattern: String) -> List(RangePatternPart) {
  case find_repeat_index(pattern, 0, dict.new()) {
    0 -> [RangePatternPart(StartRange, pattern)]
    index -> [
      RangePatternPart(StartRange, string.slice(pattern, 0, index)),
      RangePatternPart(
        EndRange,
        string.slice(pattern, index, string.length(pattern) - index),
      ),
    ]
  }
}

fn find_repeat_index(
  rest: String,
  position: Int,
  seen: Dict(String, Int),
) -> Int {
  case rest {
    "" -> 0
    "{" <> _ ->
      case string.split_once(rest, "}") {
        Ok(#(head, tail)) -> {
          let token = head <> "}"
          case dict.has_key(seen, token) {
            True -> position
            False ->
              find_repeat_index(
                tail,
                position + string.length(token),
                dict.insert(seen, token, position),
              )
          }
        }
        Error(_) -> advance_char(rest, position, seen)
      }
    _ -> advance_char(rest, position, seen)
  }
}

fn advance_char(rest: String, position: Int, seen: Dict(String, Int)) -> Int {
  case string.pop_grapheme(rest) {
    Ok(#(_, remaining)) -> find_repeat_index(remaining, position + 1, seen)
    Error(_) -> 0
  }
}
