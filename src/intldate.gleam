//// Date formatting for `gleam_time` following the JavaScript `Intl.DateTimeFormat()` API.
////
//// This module provides a type-safe wrapper around the `Intl.DateTimeFormat` API,
//// allowing you to format dates and times according to locale-specific conventions.
////
//// **Works on both the JavaScript and Erlang runtimes.** On JavaScript it delegates to
//// the native `Intl.DateTimeFormat()`, while on Erlang it uses a pure Gleam
//// reimplementation that mirrors the same behaviour, so the output stays consistent
//// whichever target you compile to.
////
//// ## Error handling
////
//// `format` never fails: if the time zone, locale, or calendar cannot be resolved, it
//// returns a human-readable, English-only message describing the error (via
//// `describe_error`), regardless of the requested locale.
////
//// If you'd rather handle the error yourself, use `try_format`, which returns a
//// `Result(String, IntlError)`.
////

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/timestamp
import intldate/internal/core
import intldate/internal/icu

/// Format a timestamp according to the specified locale and configuration.
///
/// ## Parameters
///
/// - `date`: The timestamp to format
/// - `time_zone`: The time zone to use (IANA time zone name like "America/New_York").
///   If `None`, uses the system's local time zone.
/// - `locale`: The locale to use for formatting (BCP 47 language tag like "en-US", "fr-FR").
///   If `None`, uses the system's default locale.
/// - `config`: The configuration object specifying which date/time components to include
///
/// ## Why Timestamp Instead of Calendar?
///
/// This function depends directly on the `timestamp` module and not `calendar` from `gleam_time` because Calendar
/// represents a day and time separately without any timezone information, and the built-in timestamp to calendar
/// conversion in `gleam_time` does not have complete support for time zones as described by IANA. Therefore, it can
/// only represent time zones as offsets and does not take countries with daylight saving time into account. Since the
/// `Intl.DateTimeFormat` model works directly with a date in UTC and resolves the time zone display from the IANA
/// database, it is more logical to use a timestamp for this purpose.
///
/// ## Example
///
/// ```gleam
/// import gleam/option
/// import gleam/time/timestamp
/// import intldate
///
/// let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")
///
/// intldate.format(
///   date:,
///   time_zone: option.Some("Indian/Reunion"),
///   locale: option.Some("fr-FR"),
///   config: intldate.new()
///     |> intldate.with_weekday(intldate.WeekdayLong)
///     |> intldate.with_year(intldate.YearNumeric)
///     |> intldate.with_month(intldate.MonthLong)
///     |> intldate.with_day(intldate.DayNumeric)
///     |> intldate.with_hour(intldate.HourNumeric)
///     |> intldate.with_minute(intldate.MinuteNumeric),
/// )
/// // -> "mardi 24 février 2026 à 17:48"
/// ```
///
pub fn format(
  date date: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> String {
  case raw_format(date, time_zone, locale, config) {
    Ok(formatted) -> formatted
    Error(error) -> describe_error(error)
  }
}

pub type IntlError {
  /// The requested time zone could not be loaded or resolved.
  FailedToLoadTimeZone(inner: String)
  /// The requested locale could not be loaded or resolved.
  FailedToLoadLocale(inner: String)
  /// The requested calendar could not be loaded or resolved.
  FailedToLoadCalendar(inner: String)
  /// The system local time zone could not be detected.
  SystemTimeZoneUnavailable
  /// Any error not accounted for by this type.
  Unknown(inner: String)
}

/// Convert an error into a human-readable description.
///
/// ## Example
/// ```gleam
/// let assert "Failed to load time zone: Invalid/TimeZone" =
///   describe_error(FailedToLoadTimeZone("Invalid/TimeZone"))
/// ```
///
pub fn describe_error(error: IntlError) -> String {
  case error {
    FailedToLoadTimeZone(inner) -> "Failed to load time zone: " <> inner
    FailedToLoadLocale(inner) -> "Failed to load locale: " <> inner
    FailedToLoadCalendar(inner) -> "Failed to load calendar: " <> inner
    SystemTimeZoneUnavailable -> "System time zone unavailable"
    Unknown(inner) -> "Unknown error: " <> inner
  }
}

/// Format a timestamp according to the specified locale and configuration,
/// returning a `Result` instead of falling back to an error message.
///
/// This is identical to `format`, except it lets you handle the `IntlError`
/// yourself instead of getting a human-readable string when resolution fails.
///
/// ## Example
///
/// ```gleam
/// import gleam/option
/// import gleam/time/timestamp
/// import intldate
///
/// let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")
///
/// intldate.try_format(
///   date:,
///   time_zone: option.Some("Invalid/TimeZone"),
///   locale: option.Some("fr-FR"),
///   config: intldate.new()
///     |> intldate.with_year(intldate.YearNumeric)
///     |> intldate.with_month(intldate.MonthLong)
///     |> intldate.with_day(intldate.DayNumeric),
/// )
/// // -> Error(intldate.FailedToLoadTimeZone("Invalid/TimeZone"))
/// ```
///
pub fn try_format(
  date date: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> Result(String, IntlError) {
  raw_format(date, time_zone, locale, config)
}

/// Format a timestamp and return the structured parts of the formatted output.
///
/// This mirrors `Intl.DateTimeFormat.prototype.formatToParts`.
pub fn format_to_parts(
  date date: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> List(DateTimeFormatPart) {
  case raw_format_to_parts(date, time_zone, locale, config) {
    Ok(parts) -> parts
    Error(error) -> [
      DateTimeFormatPart(
        kind: DateTimePartLiteral,
        value: describe_error(error),
        source: DateTimePartSourceNone,
      ),
    ]
  }
}

/// Format a timestamp to parts, returning a `Result`.
pub fn try_format_to_parts(
  date date: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> Result(List(DateTimeFormatPart), IntlError) {
  raw_format_to_parts(date, time_zone, locale, config)
}

/// Format a range between two timestamps according to the specified locale and
/// configuration, using the same options as `format`.
///
/// This mirrors the `Intl.DateTimeFormat.prototype.formatRange` API: it renders
/// the two dates together, collapsing the parts they have in common.
///
/// ## Parameters
///
/// - `date_start`: The timestamp marking the start of the range
/// - `date_end`: The timestamp marking the end of the range
/// - `time_zone`: The time zone to use (IANA time zone name like "America/New_York").
///   If `None`, uses the system's local time zone.
/// - `locale`: The locale to use for formatting (BCP 47 language tag like "en-US", "fr-FR").
///   If `None`, uses the system's default locale.
/// - `config`: The configuration object specifying which date/time components to include
///
/// Like `format`, this never fails: if the time zone, locale, or calendar cannot
/// be resolved, it returns a human-readable, English-only message describing the
/// error (via `describe_error`).
///
/// ## Example
///
/// ```gleam
/// import gleam/option
/// import gleam/time/timestamp
/// import intldate
///
/// let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")
/// let assert Ok(end) = timestamp.parse_rfc3339("2026-02-27T17:48:22+04:00")
///
/// intldate.format_range(
///   date_start: start,
///   date_end: end,
///   time_zone: option.Some("Indian/Reunion"),
///   locale: option.Some("fr-FR"),
///   config: intldate.new()
///     |> intldate.with_year(intldate.YearNumeric)
///     |> intldate.with_month(intldate.MonthLong)
///     |> intldate.with_day(intldate.DayNumeric),
/// )
/// // -> "24–27 février 2026"
/// ```
///
pub fn format_range(
  date_start date_start: timestamp.Timestamp,
  date_end date_end: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> String {
  case raw_format_range(date_start, date_end, time_zone, locale, config) {
    Ok(formatted) -> formatted
    Error(error) -> describe_error(error)
  }
}

/// Format a range between two timestamps according to the specified locale and
/// configuration, returning a `Result` instead of falling back to an error
/// message.
///
/// This is identical to `format_range`, except it lets you handle the
/// `IntlError` yourself instead of getting a human-readable string when
/// resolution fails.
///
pub fn try_format_range(
  date_start date_start: timestamp.Timestamp,
  date_end date_end: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> Result(String, IntlError) {
  raw_format_range(date_start, date_end, time_zone, locale, config)
}

/// Format a range and return the structured parts of the formatted output.
///
/// This mirrors `Intl.DateTimeFormat.prototype.formatRangeToParts`. Parts that
/// come from the start date, end date, or shared range text are marked with
/// `source`.
pub fn format_range_to_parts(
  date_start date_start: timestamp.Timestamp,
  date_end date_end: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> List(DateTimeFormatPart) {
  case
    raw_format_range_to_parts(date_start, date_end, time_zone, locale, config)
  {
    Ok(parts) -> parts
    Error(error) -> [
      DateTimeFormatPart(
        kind: DateTimePartLiteral,
        value: describe_error(error),
        source: DateTimePartSourceNone,
      ),
    ]
  }
}

/// Format a range to parts, returning a `Result`.
pub fn try_format_range_to_parts(
  date_start date_start: timestamp.Timestamp,
  date_end date_end: timestamp.Timestamp,
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> Result(List(DateTimeFormatPart), IntlError) {
  raw_format_range_to_parts(date_start, date_end, time_zone, locale, config)
}

/// Return the options resolved by the date/time formatter.
///
/// This mirrors `Intl.DateTimeFormat.prototype.resolvedOptions`.
pub fn resolved_options(
  time_zone time_zone: Option(String),
  locale locale: Option(String),
  config config: DateTimeFormatConfig,
) -> Result(DateTimeResolvedOptions, IntlError) {
  raw_resolved_options(time_zone, locale, config)
}

@external(javascript, "./intldate.ffi.mjs", "formatTimestamp")
fn raw_format(
  date: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(String, IntlError) {
  case core.format(date, time_zone, locale, to_icu_config(config)) {
    Ok(formatted) -> Ok(formatted)
    Error(error) -> Error(map_icu_error(error))
  }
}

@external(javascript, "./intldate.ffi.mjs", "formatTimestampToParts")
fn raw_format_to_parts(
  date: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(List(DateTimeFormatPart), IntlError) {
  case core.format_to_parts(date, time_zone, locale, to_icu_config(config)) {
    Ok(parts) -> Ok(list.map(parts, map_icu_date_part))
    Error(error) -> Error(map_icu_error(error))
  }
}

fn to_icu_config(config: DateTimeFormatConfig) -> core.Config {
  let calendar = case config.calendar {
    None -> ""
    Some(_) -> calendar_name(config.calendar)
  }
  core.Config(
    calendar: calendar,
    weekday: option.map(config.weekday, fn(weekday_value) {
      case weekday_value {
        WeekdayLong -> core.StyleLong
        WeekdayShort -> core.StyleShort
        WeekdayNarrow -> core.StyleNarrow
      }
    }),
    era: option.map(config.era, fn(era_value) {
      case era_value {
        EraLong -> core.StyleLong
        EraShort -> core.StyleShort
        EraNarrow -> core.StyleNarrow
      }
    }),
    year: option.map(config.year, fn(year_variant) {
      case year_variant {
        YearNumeric -> core.StyleNumeric
        Year2Digit -> core.StyleTwoDigit
      }
    }),
    month: option.map(config.month, fn(month_variant) {
      case month_variant {
        MonthNumeric -> core.MonthNumeric
        Month2Digit -> core.MonthTwoDigit
        MonthLong -> core.MonthLong
        MonthShort -> core.MonthShort
        MonthNarrow -> core.MonthNarrow
      }
    }),
    day: option.map(config.day, fn(day_variant) {
      case day_variant {
        DayNumeric -> core.StyleNumeric
        Day2Digit -> core.StyleTwoDigit
      }
    }),
    hour: option.map(config.hour, fn(hour_variant) {
      case hour_variant {
        HourNumeric -> core.StyleNumeric
        Hour2Digit -> core.StyleTwoDigit
      }
    }),
    minute: option.map(config.minute, fn(minute_variant) {
      case minute_variant {
        MinuteNumeric -> core.StyleNumeric
        Minute2Digit -> core.StyleTwoDigit
      }
    }),
    second: option.map(config.second, fn(second_variant) {
      case second_variant {
        SecondNumeric -> core.StyleNumeric
        Second2Digit -> core.StyleTwoDigit
      }
    }),
    time_zone_name: option.map(config.time_zone_name, fn(time_zone_name_value) {
      case time_zone_name_value {
        TimeZoneNameShort -> core.TimeZoneShort
        TimeZoneNameLong -> core.TimeZoneLong
        TimeZoneNameShortOffset -> core.TimeZoneShortOffset
        TimeZoneNameLongOffset -> core.TimeZoneLongOffset
        TimeZoneNameShortGeneric -> core.TimeZoneShortGeneric
        TimeZoneNameLongGeneric -> core.TimeZoneLongGeneric
      }
    }),
    hour12: config.hour12,
  )
}

fn map_icu_error(error: icu.IcuError) -> IntlError {
  case error {
    icu.FailedToLoadTimeZone(inner) -> FailedToLoadTimeZone(inner)
    icu.FailedToLoadLocale(inner) -> FailedToLoadLocale(inner)
    icu.FailedToLoadCalendar(inner) -> FailedToLoadCalendar(inner)
    icu.SystemTimeZoneUnavailable -> SystemTimeZoneUnavailable
    icu.Unknown(inner) -> Unknown(inner)
  }
}

@external(javascript, "./intldate.ffi.mjs", "formatRangeTimestamp")
fn raw_format_range(
  date_start: timestamp.Timestamp,
  date_end: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(String, IntlError) {
  case
    core.format_range(
      date_start,
      date_end,
      time_zone,
      locale,
      to_icu_config(config),
    )
  {
    Ok(formatted) -> Ok(formatted)
    Error(error) -> Error(map_icu_error(error))
  }
}

@external(javascript, "./intldate.ffi.mjs", "formatRangeTimestampToParts")
fn raw_format_range_to_parts(
  date_start: timestamp.Timestamp,
  date_end: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(List(DateTimeFormatPart), IntlError) {
  case
    core.format_range_to_parts(
      date_start,
      date_end,
      time_zone,
      locale,
      to_icu_config(config),
    )
  {
    Ok(parts) -> Ok(list.map(parts, map_icu_date_part))
    Error(error) -> Error(map_icu_error(error))
  }
}

@external(javascript, "./intldate.ffi.mjs", "dateTimeResolvedOptions")
fn raw_resolved_options(
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(DateTimeResolvedOptions, IntlError) {
  case core.resolved_options(locale, to_icu_config(config)) {
    Ok(#(pattern, hour_cycle_keyword, numbering_system)) ->
      Ok(pattern_resolved_options(
        pattern,
        hour_cycle_keyword,
        numbering_system,
        time_zone,
        locale,
        config,
      ))
    Error(error) -> Error(map_icu_error(error))
  }
}

fn pattern_resolved_options(
  pattern: String,
  hour_cycle_keyword: String,
  numbering_system: String,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> DateTimeResolvedOptions {
  // `hour_cycle_keyword` (core's adjust_pattern/desired_hour) reflects the
  // hour cycle actually requested via config.hour12 - it is authoritative
  // whenever non-empty, independent of whether the ICU-resolved pattern
  // still contains an hour field character (dtptng's skeleton matching can
  // drop "hour" from the final pattern for unrelated field-conflict reasons
  // while an explicit hour12 request still determines the reported
  // hourCycle/hour12, exactly as real ICU/V8 do - confirmed against
  // intldatenif's native ICU NIF directly). Only fall back to scanning the
  // resolved pattern text when no explicit hour cycle was requested (e.g.
  // hour12 left unset), where the locale's own default hour cycle choice is
  // only observable from what ICU actually put in the pattern.
  let #(hour_cycle, hour12) = case config.hour {
    None -> #(None, None)
    Some(_) ->
      case hour_cycle_keyword {
        "h12" -> #(Some("h12"), Some(True))
        "h23" -> #(Some("h23"), Some(False))
        "h11" -> #(Some("h11"), Some(True))
        "h24" -> #(Some("h24"), Some(False))
        _ -> pattern_hour_cycle(string.to_graphemes(pattern), False)
      }
  }

  DateTimeResolvedOptions(
    locale: option.unwrap(locale, ""),
    calendar: resolved_calendar_name(config.calendar),
    numbering_system:,
    time_zone: option.unwrap(time_zone, ""),
    hour_cycle:,
    hour12:,
    weekday: pattern_value(pattern, [
      #("EEEEE", "narrow"),
      #("EEEE", "long"),
      #("EEE", "short"),
      #("ccccc", "narrow"),
      #("cccc", "long"),
      #("ccc", "short"),
    ]),
    era: pattern_value(pattern, [
      #("GGGGG", "narrow"),
      #("GGGG", "long"),
      #("GGG", "short"),
    ]),
    year: pattern_value(pattern, [#("yy", "2-digit"), #("y", "numeric")]),
    month: pattern_value(pattern, [
      #("MMMMM", "narrow"),
      #("MMMM", "long"),
      #("MMM", "short"),
      #("MM", "2-digit"),
      #("M", "numeric"),
      #("LLLLL", "narrow"),
      #("LLLL", "long"),
      #("LLL", "short"),
      #("LL", "2-digit"),
      #("L", "numeric"),
    ]),
    day: pattern_value(pattern, [#("dd", "2-digit"), #("d", "numeric")]),
    hour: pattern_value(pattern, [
      #("HH", "2-digit"),
      #("H", "numeric"),
      #("hh", "2-digit"),
      #("h", "numeric"),
      #("kk", "2-digit"),
      #("k", "numeric"),
      #("KK", "2-digit"),
      #("K", "numeric"),
    ]),
    minute: pattern_value(pattern, [#("mm", "2-digit"), #("m", "numeric")]),
    second: pattern_value(pattern, [#("ss", "2-digit"), #("s", "numeric")]),
    time_zone_name: pattern_value(pattern, [
      #("zzzz", "long"),
      #("z", "short"),
      #("OOOO", "longOffset"),
      #("O", "shortOffset"),
      #("vvvv", "longGeneric"),
      #("v", "shortGeneric"),
    ]),
  )
}

fn pattern_value(
  pattern: String,
  pairs: List(#(String, String)),
) -> Option(String) {
  case pairs {
    [] -> None
    [#(symbol, value), ..rest] ->
      case string.contains(pattern, symbol) {
        True -> Some(value)
        False -> pattern_value(pattern, rest)
      }
  }
}

fn pattern_hour_cycle(
  graphemes: List(String),
  in_quote: Bool,
) -> #(Option(String), Option(Bool)) {
  case graphemes {
    [] -> #(None, None)
    ["'", ..rest] -> pattern_hour_cycle(rest, !in_quote)
    [char, ..rest] ->
      case in_quote {
        True -> pattern_hour_cycle(rest, True)
        False ->
          case char {
            "h" -> #(Some("h12"), Some(True))
            "K" -> #(Some("h11"), Some(True))
            "H" -> #(Some("h23"), Some(False))
            "k" -> #(Some("h24"), Some(False))
            _ -> pattern_hour_cycle(rest, False)
          }
      }
  }
}

fn resolved_calendar_name(calendar: Option(Calendar)) -> String {
  case calendar {
    None -> "gregory"
    Some(_) -> calendar_name(calendar)
  }
}

fn calendar_name(calendar: Option(Calendar)) -> String {
  case calendar {
    None -> "default"
    Some(CalendarBuddhist) -> "buddhist"
    Some(CalendarChinese) -> "chinese"
    Some(CalendarCoptic) -> "coptic"
    Some(CalendarDangi) -> "dangi"
    Some(CalendarEthioaa) -> "ethioaa"
    Some(CalendarEthiopic) -> "ethiopic"
    Some(CalendarGregory) -> "gregory"
    Some(CalendarHebrew) -> "hebrew"
    Some(CalendarIndian) -> "indian"
    Some(CalendarIslamic) -> "islamic"
    Some(CalendarIslamicUmalqura) -> "islamic-umalqura"
    Some(CalendarIslamicTbla) -> "islamic-tbla"
    Some(CalendarIslamicCivil) -> "islamic-civil"
    Some(CalendarIslamicRgsa) -> "islamic-rgsa"
    Some(CalendarIso8601) -> "iso8601"
    Some(CalendarJapanese) -> "japanese"
    Some(CalendarPersian) -> "persian"
    Some(CalendarRoc) -> "roc"
  }
}

fn map_icu_date_part(part: core.DateTimePart) -> DateTimeFormatPart {
  DateTimeFormatPart(
    kind: date_part_kind(part.kind),
    value: part.value,
    source: date_part_source(part.source),
  )
}

fn date_part_kind(kind: String) -> DateTimePartKind {
  case kind {
    "literal" -> DateTimePartLiteral
    "weekday" -> DateTimePartWeekday
    "era" -> DateTimePartEra
    "year" -> DateTimePartYear
    "relatedYear" -> DateTimePartRelatedYear
    "yearName" -> DateTimePartYearName
    "month" -> DateTimePartMonth
    "day" -> DateTimePartDay
    "dayPeriod" -> DateTimePartDayPeriod
    "hour" -> DateTimePartHour
    "minute" -> DateTimePartMinute
    "second" -> DateTimePartSecond
    "fractionalSecond" -> DateTimePartFractionalSecond
    "timeZoneName" -> DateTimePartTimeZoneName
    other -> DateTimePartUnknown(other)
  }
}

fn date_part_source(source: String) -> DateTimePartSource {
  case source {
    "startRange" -> DateTimePartSourceStartRange
    "shared" -> DateTimePartSourceShared
    "endRange" -> DateTimePartSourceEndRange
    _ -> DateTimePartSourceNone
  }
}

/// A part type returned by `format_to_parts` and `format_range_to_parts`.
pub type DateTimePartKind {
  DateTimePartLiteral
  DateTimePartWeekday
  DateTimePartEra
  DateTimePartYear
  DateTimePartRelatedYear
  DateTimePartYearName
  DateTimePartMonth
  DateTimePartDay
  DateTimePartDayPeriod
  DateTimePartHour
  DateTimePartMinute
  DateTimePartSecond
  DateTimePartFractionalSecond
  DateTimePartTimeZoneName
  DateTimePartUnknown(inner: String)
}

/// Where a range part came from.
pub type DateTimePartSource {
  DateTimePartSourceNone
  DateTimePartSourceStartRange
  DateTimePartSourceShared
  DateTimePartSourceEndRange
}

/// One structured part of a formatted date/time string.
pub type DateTimeFormatPart {
  DateTimeFormatPart(
    kind: DateTimePartKind,
    value: String,
    source: DateTimePartSource,
  )
}

/// Options resolved by a date/time formatter.
pub type DateTimeResolvedOptions {
  DateTimeResolvedOptions(
    locale: String,
    calendar: String,
    numbering_system: String,
    time_zone: String,
    hour_cycle: Option(String),
    hour12: Option(Bool),
    weekday: Option(String),
    era: Option(String),
    year: Option(String),
    month: Option(String),
    day: Option(String),
    hour: Option(String),
    minute: Option(String),
    second: Option(String),
    time_zone_name: Option(String),
  )
}

/// The locale matching algorithm to use.
///
/// - `LocaleMatcherBestFit`: The runtime is allowed to choose the best matching locale,
///   potentially considering extension keys and other options.
/// - `LocaleMatcherLookup`: Use the BCP 47 lookup algorithm to find the best matching locale.
///
pub type LocaleMatcher {
  LocaleMatcherBestFit
  LocaleMatcherLookup
}

/// The calendar system to use for date formatting.
///
/// - `CalendarBuddhist`: Buddhist calendar
/// - `CalendarChinese`: Chinese calendar
/// - `CalendarCoptic`: Coptic calendar
/// - `CalendarDangi`: Dangi calendar (Korean)
/// - `CalendarEthioaa`: Ethiopic Amete Alem calendar
/// - `CalendarEthiopic`: Ethiopic calendar
/// - `CalendarGregory`: Gregorian calendar
/// - `CalendarHebrew`: Hebrew calendar
/// - `CalendarIndian`: Indian national calendar
/// - `CalendarIslamic`: Islamic calendar
/// - `CalendarIslamicUmalqura`: Islamic calendar (Umm al-Qura)
/// - `CalendarIslamicTbla`: Islamic calendar (tabular, astronomical epoch)
/// - `CalendarIslamicCivil`: Islamic calendar (tabular, civil epoch)
/// - `CalendarIslamicRgsa`: Islamic calendar (Saudi Arabia sighting)
/// - `CalendarIso8601`: ISO 8601 calendar (Gregorian with ISO week numbering)
/// - `CalendarJapanese`: Japanese imperial calendar
/// - `CalendarPersian`: Persian calendar
/// - `CalendarRoc`: Republic of China calendar
///
pub type Calendar {
  CalendarBuddhist
  CalendarChinese
  CalendarCoptic
  CalendarDangi
  CalendarEthioaa
  CalendarEthiopic
  CalendarGregory
  CalendarHebrew
  CalendarIndian
  CalendarIslamic
  CalendarIslamicUmalqura
  CalendarIslamicTbla
  CalendarIslamicCivil
  CalendarIslamicRgsa
  CalendarIso8601
  CalendarJapanese
  CalendarPersian
  CalendarRoc
}

/// The representation of the weekday.
///
/// - `WeekdayLong`: Full weekday name (e.g., "Monday", "lundi")
/// - `WeekdayShort`: Abbreviated weekday name (e.g., "Mon", "lun")
/// - `WeekdayNarrow`: Narrow weekday name (e.g., "M", "L")
///
pub type Weekday {
  WeekdayLong
  WeekdayShort
  WeekdayNarrow
}

/// The representation of the era.
///
/// - `EraLong`: Full era name (e.g., "Anno Domini", "après Jésus-Christ")
/// - `EraShort`: Abbreviated era name (e.g., "AD", "ap. J.-C.")
/// - `EraNarrow`: Narrow era name (e.g., "A", "ap. J.-C.")
///
pub type Era {
  EraLong
  EraShort
  EraNarrow
}

/// The representation of the year.
///
/// - `YearNumeric`: Full numeric representation (e.g., "2026")
/// - `Year2Digit`: Two-digit numeric representation (e.g., "26")
///
pub type Year {
  YearNumeric
  Year2Digit
}

/// The representation of the month.
///
/// - `MonthNumeric`: Numeric representation (e.g., "2")
/// - `Month2Digit`: Two-digit numeric representation (e.g., "02")
/// - `MonthLong`: Full month name (e.g., "February", "février")
/// - `MonthShort`: Abbreviated month name (e.g., "Feb", "févr.")
/// - `MonthNarrow`: Narrow month name (e.g., "F", "F")
///
pub type Month {
  MonthNumeric
  Month2Digit
  MonthLong
  MonthShort
  MonthNarrow
}

/// The representation of the day.
///
/// - `DayNumeric`: Numeric representation (e.g., "5")
/// - `Day2Digit`: Two-digit numeric representation (e.g., "05")
///
pub type Day {
  DayNumeric
  Day2Digit
}

/// The representation of the hour.
///
/// - `HourNumeric`: Numeric representation (e.g., "5")
/// - `Hour2Digit`: Two-digit numeric representation (e.g., "05")
///
pub type Hour {
  HourNumeric
  Hour2Digit
}

/// The representation of the minute.
///
/// - `MinuteNumeric`: Numeric representation (e.g., "8")
/// - `Minute2Digit`: Two-digit numeric representation (e.g., "08")
///
pub type Minute {
  MinuteNumeric
  Minute2Digit
}

/// The representation of the second.
///
/// - `SecondNumeric`: Numeric representation (e.g., "3")
/// - `Second2Digit`: Two-digit numeric representation (e.g., "03")
///
pub type Second {
  SecondNumeric
  Second2Digit
}

/// The localized representation of the time zone name.
///
/// - `TimeZoneNameShort`: Short time zone name (e.g., "EST", "PST")
/// - `TimeZoneNameLong`: Long time zone name (e.g., "Eastern Standard Time")
/// - `TimeZoneNameShortOffset`: Short GMT offset (e.g., "GMT+9")
/// - `TimeZoneNameLongOffset`: Long GMT offset (e.g., "GMT+09:00")
/// - `TimeZoneNameShortGeneric`: Short generic non-location format (e.g., "ET", "PT")
/// - `TimeZoneNameLongGeneric`: Long generic non-location format (e.g., "Eastern Time")
///
pub type TimeZoneName {
  TimeZoneNameShort
  TimeZoneNameLong
  TimeZoneNameShortOffset
  TimeZoneNameLongOffset
  TimeZoneNameShortGeneric
  TimeZoneNameLongGeneric
}

/// The format matching algorithm to use.
///
/// - `FormatMatcherBestFit`: The runtime is allowed to choose the best format
///   based on the requested components and the locale.
/// - `FormatMatcherBasic`: Use a basic algorithm that prioritizes matching
///   the requested components in order.
///
pub type FormatMatcher {
  FormatMatcherBestFit
  FormatMatcherBasic
}

/// Configuration for date/time formatting.
///
/// This type allows you to specify which date and time components to include
/// in the formatted output and how they should be represented.
///
/// Create a new configuration with `new()` and customize it with the various
/// `with_*` functions.
///
pub type DateTimeFormatConfig {
  DateTimeFormatConfig(
    locale_matcher: Option(LocaleMatcher),
    calendar: Option(Calendar),
    weekday: Option(Weekday),
    era: Option(Era),
    year: Option(Year),
    month: Option(Month),
    day: Option(Day),
    hour: Option(Hour),
    minute: Option(Minute),
    second: Option(Second),
    time_zone_name: Option(TimeZoneName),
    format_matcher: Option(FormatMatcher),
    hour12: Option(Bool),
  )
}

/// Create a new date/time format configuration with all options unset.
///
/// Use the various `with_*` functions to customize the configuration.
///
/// ## Example
///
/// ```gleam
/// intldate.new()
///   |> intldate.with_year(intldate.YearNumeric)
///   |> intldate.with_month(intldate.MonthLong)
///   |> intldate.with_day(intldate.DayNumeric)
/// ```
///
pub fn new() -> DateTimeFormatConfig {
  DateTimeFormatConfig(
    locale_matcher: None,
    calendar: None,
    weekday: None,
    era: None,
    year: None,
    month: None,
    day: None,
    hour: None,
    minute: None,
    second: None,
    time_zone_name: None,
    format_matcher: None,
    hour12: None,
  )
}

/// Set the locale matching algorithm.
///
/// The locale matcher determines how the runtime selects the best matching
/// locale when the exact locale you requested isn't available.
///
pub fn with_locale_matcher(
  config: DateTimeFormatConfig,
  locale_matcher: LocaleMatcher,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, locale_matcher: Some(locale_matcher))
}

/// Set the calendar system to use for date formatting.
///
pub fn with_calendar(
  config: DateTimeFormatConfig,
  calendar: Calendar,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, calendar: Some(calendar))
}

/// Set the representation of the weekday.
///
pub fn with_weekday(
  config: DateTimeFormatConfig,
  weekday: Weekday,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, weekday: Some(weekday))
}

/// Set the representation of the era.
///
pub fn with_era(
  config: DateTimeFormatConfig,
  era: Era,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, era: Some(era))
}

/// Set the representation of the year.
///
pub fn with_year(
  config: DateTimeFormatConfig,
  year: Year,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, year: Some(year))
}

/// Set the representation of the month.
///
pub fn with_month(
  config: DateTimeFormatConfig,
  month: Month,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, month: Some(month))
}

/// Set the representation of the day.
///
pub fn with_day(
  config: DateTimeFormatConfig,
  day: Day,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, day: Some(day))
}

/// Set the representation of the hour.
///
pub fn with_hour(
  config: DateTimeFormatConfig,
  hour: Hour,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, hour: Some(hour))
}

/// Set the representation of the minute.
///
pub fn with_minute(
  config: DateTimeFormatConfig,
  minute: Minute,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, minute: Some(minute))
}

/// Set the representation of the second.
///
pub fn with_second(
  config: DateTimeFormatConfig,
  second: Second,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, second: Some(second))
}

/// Set the localized representation of the time zone name.
///
pub fn with_time_zone_name(
  config: DateTimeFormatConfig,
  time_zone_name: TimeZoneName,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, time_zone_name: Some(time_zone_name))
}

/// Set the format matching algorithm.
///
/// The format matcher determines how the runtime selects the best format
/// pattern based on the requested components and the locale.
///
pub fn with_format_matcher(
  config: DateTimeFormatConfig,
  format_matcher: FormatMatcher,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, format_matcher: Some(format_matcher))
}

/// Set whether to use 12-hour time format.
///
/// - `True`: Use 12-hour format with AM/PM (e.g., "5:48 PM")
/// - `False`: Use 24-hour format (e.g., "17:48")
///
/// If not set, the hour format is determined by the locale.
///
pub fn with_hour12(
  config: DateTimeFormatConfig,
  hour12: Bool,
) -> DateTimeFormatConfig {
  DateTimeFormatConfig(..config, hour12: Some(hour12))
}
