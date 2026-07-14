import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import intldate/internal/icu

pub type NumericStyle {
  StyleNumeric
  StyleTwoDigit
}

pub type TextStyle {
  StyleLong
  StyleShort
  StyleNarrow
}

pub type MonthStyle {
  MonthNumeric
  MonthTwoDigit
  MonthLong
  MonthShort
  MonthNarrow
}

pub type TimeZoneStyle {
  TimeZoneShort
  TimeZoneLong
  TimeZoneShortOffset
  TimeZoneLongOffset
  TimeZoneShortGeneric
  TimeZoneLongGeneric
}

pub type Config {
  Config(
    calendar: String,
    weekday: Option(TextStyle),
    era: Option(TextStyle),
    year: Option(NumericStyle),
    month: Option(MonthStyle),
    day: Option(NumericStyle),
    hour: Option(NumericStyle),
    minute: Option(NumericStyle),
    second: Option(NumericStyle),
    time_zone_name: Option(TimeZoneStyle),
    hour12: Option(Bool),
  )
}

pub type DateTimePart {
  DateTimePart(kind: String, value: String, source: String)
}

pub type RelativeTimePart {
  RelativeTimePart(kind: String, value: String, unit: Option(String))
}

pub fn format(
  date: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: Config,
) -> Result(String, icu.IcuError) {
  use #(pattern, _, _) <- result.try(prepare(locale, config))
  use formatted <- result.map(icu.format(
    to_milliseconds(date),
    time_zone,
    locale |> option.unwrap(""),
    config.calendar,
    pattern,
  ))
  normalize_spaces(formatted)
}

pub fn format_to_parts(
  date: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: Config,
) -> Result(List(DateTimePart), icu.IcuError) {
  use #(pattern, _, _) <- result.try(prepare(locale, config))
  use parts <- result.map(icu.format_to_parts(
    to_milliseconds(date),
    time_zone,
    locale |> option.unwrap(""),
    config.calendar,
    pattern,
  ))
  list.map(parts, fn(part) {
    let #(kind, value) = part
    DateTimePart(kind, value, "none")
  })
}

pub fn format_range(
  date_start: timestamp.Timestamp,
  date_end: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: Config,
) -> Result(String, icu.IcuError) {
  use #(pattern, _, _) <- result.try(prepare(locale, config))
  icu.format_range(
    to_milliseconds(date_start),
    to_milliseconds(date_end),
    time_zone,
    locale |> option.unwrap(""),
    config.calendar,
    pattern,
  )
}

pub fn format_range_to_parts(
  date_start: timestamp.Timestamp,
  date_end: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: Config,
) -> Result(List(DateTimePart), icu.IcuError) {
  use #(pattern, _, _) <- result.try(prepare(locale, config))
  use parts <- result.map(icu.format_range_to_parts(
    to_milliseconds(date_start),
    to_milliseconds(date_end),
    time_zone,
    locale |> option.unwrap(""),
    config.calendar,
    pattern,
  ))
  list.map(parts, fn(part) {
    let #(kind, value, source) = part
    DateTimePart(kind, value, range_source(source))
  })
}

fn range_source(source: Option(String)) -> String {
  case source {
    Some("start") -> "startRange"
    Some("end") -> "endRange"
    Some("shared") -> "shared"
    _ -> "none"
  }
}

pub fn resolved_options(
  locale: Option(String),
  config: Config,
) -> Result(#(String, String, String), icu.IcuError) {
  prepare(locale, config)
}

fn prepare(
  locale: Option(String),
  config: Config,
) -> Result(#(String, String, String), icu.IcuError) {
  let skeleton = build_skeleton(config)
  use #(pattern, hour_cycle, region, numbering_system) <- result.map(
    icu.analyze(locale |> option.unwrap(""), config.calendar, skeleton),
  )
  let #(adjusted, hour_cycle_keyword) =
    adjust_pattern(pattern, skeleton, hour_cycle, region)
  // adjust_pattern/desired_hour only produces a keyword when hour12 was
  // explicitly requested (skeleton carries a literal "h"/"H", not the
  // locale-default "j"). When hour12 was left unset but hour *was*
  // requested, the resolved hour cycle is still well-defined - it's exactly
  // `hour_cycle` (icu.analyze's locale-default UDateFormatHourCycle) - even
  // if dtptng's pattern matching happens to drop the hour field from the
  // final pattern for unrelated reasons (same class of issue as the
  // explicit-hour12 case already fixed; this is the "j" counterpart).
  let resolved_keyword = case hour_cycle_keyword, config.hour {
    "", Some(_) -> hour_cycle_to_keyword(hour_cycle)
    keyword, _ -> keyword
  }
  #(adjusted, resolved_keyword, numbering_system)
}

fn hour_cycle_to_keyword(hour_cycle: Int) -> String {
  case hour_cycle {
    0 -> "h11"
    1 -> "h12"
    2 -> "h23"
    _ -> "h24"
  }
}

fn to_milliseconds(date: timestamp.Timestamp) -> Int {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(date)
  seconds * 1000 + nanoseconds / 1_000_000
}

fn build_skeleton(config: Config) -> String {
  let has_fields =
    option.is_some(config.weekday)
    || option.is_some(config.year)
    || option.is_some(config.month)
    || option.is_some(config.day)
    || option.is_some(config.hour)
    || option.is_some(config.minute)
    || option.is_some(config.second)
  let config = case has_fields {
    True -> config
    False ->
      Config(
        ..config,
        year: Some(StyleNumeric),
        month: Some(MonthNumeric),
        day: Some(StyleNumeric),
      )
  }
  let hour_symbol = case config.hour12 {
    Some(True) -> "h"
    Some(False) -> "H"
    None -> "j"
  }
  [
    case config.weekday {
      Some(StyleLong) -> "EEEE"
      Some(StyleShort) -> "EEE"
      Some(StyleNarrow) -> "EEEEE"
      None -> ""
    },
    case config.era {
      Some(StyleLong) -> "GGGG"
      Some(StyleShort) -> "GGG"
      Some(StyleNarrow) -> "GGGGG"
      None -> ""
    },
    case config.year {
      Some(StyleNumeric) -> "y"
      Some(StyleTwoDigit) -> "yy"
      None -> ""
    },
    case config.month {
      Some(MonthNumeric) -> "M"
      Some(MonthTwoDigit) -> "MM"
      Some(MonthLong) -> "MMMM"
      Some(MonthShort) -> "MMM"
      Some(MonthNarrow) -> "MMMMM"
      None -> ""
    },
    case config.day {
      Some(StyleNumeric) -> "d"
      Some(StyleTwoDigit) -> "dd"
      None -> ""
    },
    case config.hour {
      Some(StyleNumeric) -> hour_symbol
      Some(StyleTwoDigit) -> hour_symbol <> hour_symbol
      None -> ""
    },
    case config.minute {
      Some(StyleNumeric) -> "m"
      Some(StyleTwoDigit) -> "mm"
      None -> ""
    },
    case config.second {
      Some(StyleNumeric) -> "s"
      Some(StyleTwoDigit) -> "ss"
      None -> ""
    },
    case config.time_zone_name {
      Some(TimeZoneShort) -> "z"
      Some(TimeZoneLong) -> "zzzz"
      Some(TimeZoneShortOffset) -> "O"
      Some(TimeZoneLongOffset) -> "OOOO"
      Some(TimeZoneShortGeneric) -> "v"
      Some(TimeZoneLongGeneric) -> "vvvv"
      None -> ""
    },
  ]
  |> string.concat
}

fn adjust_pattern(
  pattern: String,
  skeleton: String,
  hour_cycle: Int,
  region: String,
) -> #(String, String) {
  case desired_hour(skeleton, hour_cycle, region) {
    "" -> #(pattern, "")
    desired -> {
      let adjusted =
        replace_hours(string.to_graphemes(pattern), desired, True, "", [])
      let keyword = case desired {
        "h" -> "h12"
        "H" -> "h23"
        "K" -> "h11"
        _ -> "h24"
      }
      #(adjusted, keyword)
    }
  }
}

fn desired_hour(skeleton: String, hour_cycle: Int, region: String) -> String {
  case requested_hour(string.to_graphemes(skeleton)) {
    "h" ->
      case hour_cycle == 0 || { region == "JP" && hour_cycle != 1 } {
        True -> "K"
        False -> "h"
      }
    "H" ->
      case hour_cycle == 3 {
        True -> "k"
        False -> "H"
      }
    _ -> ""
  }
}

fn requested_hour(graphemes: List(String)) -> String {
  case graphemes {
    [] -> ""
    ["h", ..] -> "h"
    ["H", ..] -> "H"
    [_, ..rest] -> requested_hour(rest)
  }
}

fn replace_hours(
  graphemes: List(String),
  desired: String,
  replace: Bool,
  last: String,
  acc: List(String),
) -> String {
  case graphemes {
    [] ->
      acc
      |> list.reverse
      |> string.concat
    ["'", ..rest] -> replace_hours(rest, desired, !replace, "'", ["'", ..acc])
    [char, ..rest] ->
      case char {
        "h" | "H" | "K" | "k" -> {
          let acc = case replace && last == "d" {
            True -> [" ", ..acc]
            False -> acc
          }
          let out = case replace {
            True -> desired
            False -> char
          }
          replace_hours(rest, desired, replace, char, [out, ..acc])
        }
        _ -> replace_hours(rest, desired, replace, char, [char, ..acc])
      }
  }
}

fn normalize_spaces(text: String) -> String {
  text
  |> string.replace("\u{00A0}", " ")
  |> string.replace("\u{202F}", " ")
  |> string.replace("\u{2009}", " ")
}

pub type RelativeUnit {
  Second
  Minute
  Hour
  Day
  Week
  Month
  Quarter
  Year
}

pub type RelativeNumeric {
  NumericAlways
  NumericAuto
}

pub fn format_relative(
  duration: duration.Duration,
  unit: RelativeUnit,
  locale: Option(String),
  style: TextStyle,
  numeric: RelativeNumeric,
) -> Result(String, icu.IcuError) {
  let value = duration.to_seconds(duration) /. unit_seconds(unit)
  icu.format_relative(
    value,
    unit_name(unit),
    locale |> option.unwrap(""),
    style_name(style),
    numeric == NumericAlways,
  )
}

pub fn format_relative_to_parts(
  duration: duration.Duration,
  unit: RelativeUnit,
  locale: Option(String),
  style: TextStyle,
  numeric: RelativeNumeric,
) -> Result(List(RelativeTimePart), icu.IcuError) {
  let value = duration.to_seconds(duration) /. unit_seconds(unit)
  use parts <- result.map(icu.format_relative_to_parts(
    value,
    unit_name(unit),
    locale |> option.unwrap(""),
    style_name(style),
    numeric == NumericAlways,
  ))
  list.map(parts, fn(part) {
    let #(kind, text) = part
    case kind {
      "literal" -> RelativeTimePart("literal", text, None)
      _ -> RelativeTimePart(kind, text, Some(unit_name(unit)))
    }
  })
}

fn unit_seconds(unit: RelativeUnit) -> Float {
  case unit {
    Second -> 1.0
    Minute -> 60.0
    Hour -> 3600.0
    Day -> 86_400.0
    Week -> 604_800.0
    Month -> 2_629_746.0
    Quarter -> 7_889_238.0
    Year -> 31_556_952.0
  }
}

fn unit_name(unit: RelativeUnit) -> String {
  case unit {
    Second -> "second"
    Minute -> "minute"
    Hour -> "hour"
    Day -> "day"
    Week -> "week"
    Month -> "month"
    Quarter -> "quarter"
    Year -> "year"
  }
}

fn style_name(style: TextStyle) -> String {
  case style {
    StyleLong -> "long"
    StyleShort -> "short"
    StyleNarrow -> "narrow"
  }
}
