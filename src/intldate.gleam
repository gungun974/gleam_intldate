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
//// ## Time zone database on Erlang
////
//// On Erlang, resolving a time zone requires an IANA `TzDatabase`. By default this
//// library tries to load one from the operating system (typically
//// `/usr/share/zoneinfo`). If the OS has no such data, formatting fails with
//// `FailedToLoadTimeZone`.
////
//// You can avoid depending on the OS entirely by calling `set_time_zone_database`
//// once at startup with a database of your choice, for example the one bundled by the
//// [`zones`](https://hex.pm/packages/zones) package, which ships a full copy of the IANA
//// time zone database so it works the same on every machine.

import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import intldate/internal/chronology
import intldate/internal/locale
import intldate/internal/renderer
import intldate/internal/time
import tzif/database

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

/// Set the global time zone database used to resolve time zones on Erlang.
///
/// By default, on Erlang, this library tries to load a `TzDatabase` from the
/// operating system (typically `/usr/share/zoneinfo`). If no such data is
/// found there, formatting fails with `FailedToLoadTimeZone`.
///
/// Call this function once at startup to provide your own `TzDatabase`
/// instead, for example the one bundled by the
/// [`zones`](https://hex.pm/packages/zones) package, so time zone resolution
/// no longer depends on what is installed on the host machine.
///
/// This has no effect on JavaScript, where time zones are resolved by the
/// native `Intl.DateTimeFormat()`.
///
/// ## Example
///
/// ```gleam
/// import intldate
/// import zones
///
/// pub fn main() {
///   intldate.set_time_zone_database(zones.database())
///
///   // ... the rest of your application
/// }
/// ```
///
pub fn set_time_zone_database(db: database.TzDatabase) -> Nil {
  time.set_default_time_zone_database(db)
}

@external(javascript, "./intldate.ffi.mjs", "formatTimestamp")
fn raw_format(
  date: timestamp.Timestamp,
  time_zone: Option(String),
  locale: Option(String),
  config: DateTimeFormatConfig,
) -> Result(String, IntlError) {
  case locale.load_locale(locale) {
    Error(_) -> Error(FailedToLoadLocale(locale |> option.unwrap("en")))
    Ok(locale) ->
      case time.resolve(date, time_zone) {
        Error(_) ->
          Error(case time_zone {
            Some(zone_name) -> FailedToLoadTimeZone(zone_name)
            None -> SystemTimeZoneUnavailable
          })
        Ok(#(date, time, is_dst, offset, zone_name)) ->
          case
            renderer.render(
              locale,
              renderer.DateTimeFormatConfig(
                calendar: option.map(config.calendar, fn(calendar_value) {
                  case calendar_value {
                    CalendarBuddhist -> chronology.CalendarBuddhist
                    CalendarChinese -> chronology.CalendarChinese
                    CalendarCoptic -> chronology.CalendarCoptic
                    CalendarDangi -> chronology.CalendarDangi
                    CalendarEthioaa -> chronology.CalendarEthioaa
                    CalendarEthiopic -> chronology.CalendarEthiopic
                    CalendarGregory -> chronology.CalendarGregory
                    CalendarHebrew -> chronology.CalendarHebrew
                    CalendarIndian -> chronology.CalendarIndian
                    CalendarIslamic -> chronology.CalendarIslamic
                    CalendarIslamicUmalqura ->
                      chronology.CalendarIslamicUmalqura
                    CalendarIslamicTbla -> chronology.CalendarIslamicTbla
                    CalendarIslamicCivil -> chronology.CalendarIslamicCivil
                    CalendarIslamicRgsa -> chronology.CalendarIslamicRgsa
                    CalendarIso8601 -> chronology.CalendarIso8601
                    CalendarJapanese -> chronology.CalendarJapanese
                    CalendarPersian -> chronology.CalendarPersian
                    CalendarRoc -> chronology.CalendarRoc
                  }
                }),
                weekday: option.map(config.weekday, fn(weekday_value) {
                  case weekday_value {
                    WeekdayLong -> renderer.StyleLong
                    WeekdayShort -> renderer.StyleShort
                    WeekdayNarrow -> renderer.StyleNarrow
                  }
                }),
                era: option.map(config.era, fn(era_value) {
                  case era_value {
                    EraLong -> renderer.StyleLong
                    EraShort -> renderer.StyleShort
                    EraNarrow -> renderer.StyleNarrow
                  }
                }),
                year: option.map(config.year, fn(year_variant) {
                  case year_variant {
                    YearNumeric -> renderer.StyleNumeric
                    Year2Digit -> renderer.StyleTwoDigit
                  }
                }),
                month: option.map(config.month, fn(month_variant) {
                  case month_variant {
                    MonthNumeric -> renderer.StyleNumeric
                    Month2Digit -> renderer.StyleTwoDigit
                    MonthLong -> renderer.StyleLong
                    MonthShort -> renderer.StyleShort
                    MonthNarrow -> renderer.StyleNarrow
                  }
                }),
                day: option.map(config.day, fn(day_variant) {
                  case day_variant {
                    DayNumeric -> renderer.StyleNumeric
                    Day2Digit -> renderer.StyleTwoDigit
                  }
                }),
                hour: option.map(config.hour, fn(hour_variant) {
                  case hour_variant {
                    HourNumeric -> renderer.StyleNumeric
                    Hour2Digit -> renderer.StyleTwoDigit
                  }
                }),
                minute: option.map(config.minute, fn(minute_variant) {
                  case minute_variant {
                    MinuteNumeric -> renderer.StyleNumeric
                    Minute2Digit -> renderer.StyleTwoDigit
                  }
                }),
                second: option.map(config.second, fn(second_variant) {
                  case second_variant {
                    SecondNumeric -> renderer.StyleNumeric
                    Second2Digit -> renderer.StyleTwoDigit
                  }
                }),
                time_zone_name: option.map(
                  config.time_zone_name,
                  fn(time_zone_name_value) {
                    case time_zone_name_value {
                      TimeZoneNameShort -> renderer.TimeZoneNameShort
                      TimeZoneNameLong -> renderer.TimeZoneNameLong
                      TimeZoneNameShortOffset ->
                        renderer.TimeZoneNameShortOffset
                      TimeZoneNameLongOffset -> renderer.TimeZoneNameLongOffset
                      TimeZoneNameShortGeneric ->
                        renderer.TimeZoneNameShortGeneric
                      TimeZoneNameLongGeneric ->
                        renderer.TimeZoneNameLongGeneric
                    }
                  },
                ),
                format_matcher: option.map(
                  config.format_matcher,
                  fn(format_matcher_value) {
                    case format_matcher_value {
                      FormatMatcherBestFit -> renderer.FormatMatcherBestFit
                      FormatMatcherBasic -> renderer.FormatMatcherBasic
                    }
                  },
                ),
                hour12: config.hour12,
              ),
              date,
              time,
              is_dst,
              offset,
              zone_name,
            )
          {
            Ok(formatted) -> Ok(formatted)
            Error(_) ->
              Error(FailedToLoadCalendar(calendar_name(config.calendar)))
          }
      }
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
