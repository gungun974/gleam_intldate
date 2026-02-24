//// Date formatting for `gleam_time` powered by JavaScript's `Intl.DateTimeFormat()`.
////
//// This module provides a type-safe wrapper around the Intl.DateTimeFormat API,
//// allowing you to format dates and times according to locale-specific conventions.
////
//// **Only works for JavaScript runtime**

import gleam/option.{type Option, None, Some}
import gleam/time/timestamp

@external(javascript, "./intldate.ffi.mjs", "formatTimestamp")
fn do_format_timestamp(
  unix_timestamp: Int,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> String

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
/// only represent time zones as offsets and does not take countries with daylight saving time into account. Since `Intl.DateTimeFormat`
/// works directly with a date in UTC and uses the browser internals to resolve the time zone display, it is more
/// logical to use a timestamp for this purpose.
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
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(date)

  do_format_timestamp(
    seconds * 1000 + nanoseconds / 1_000_000,
    time_zone,
    locale,
    config,
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
pub fn with_era(config: DateTimeFormatConfig, era: Era) -> DateTimeFormatConfig {
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
pub fn with_day(config: DateTimeFormatConfig, day: Day) -> DateTimeFormatConfig {
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
