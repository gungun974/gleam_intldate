//// Relative time formatting for `gleam_time` following the JavaScript `Intl.RelativeTimeFormat()` API.
////
//// This module provides a type-safe wrapper around the `Intl.RelativeTimeFormat` API,
//// allowing you to format durations as human-readable relative times (like "in 3 hours"
//// or "il y a 5 secondes") according to locale-specific conventions.
////
//// **Works on both the JavaScript and Erlang runtimes.** On JavaScript it delegates to
//// the native `Intl.RelativeTimeFormat()`, while on Erlang it uses a pure Gleam
//// reimplementation that mirrors the same behaviour, so the output stays consistent
//// whichever target you compile to.
////
//// The duration is expressed relative to now: a negative duration is formatted as a time
//// in the past, and a positive duration as a time in the future. The `unit` you pass
//// selects which unit the duration is expressed in, and the duration is divided by that
//// unit to obtain the amount to display.
////
//// ## Error handling
////
//// `format` never fails: if the locale cannot be resolved, it returns a human-readable,
//// English-only message describing the error (via `describe_error`), regardless of the
//// requested locale.
////
//// If you'd rather handle the error yourself, use `try_format`, which returns a
//// `Result(String, IntlError)`.
////
//// This module also mirrors `formatToParts` and `resolvedOptions` from
//// `Intl.RelativeTimeFormat`, as `format_to_parts` and `resolved_options`.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/duration
import intldate/internal/core
import intldate/internal/icu

/// Format a duration as a relative time according to the specified locale and configuration.
///
/// ## Parameters
///
/// - `duration`: The duration relative to now. A negative duration is formatted as a time
///   in the past, and a positive duration as a time in the future.
/// - `unit`: The unit the duration is expressed in. The duration is divided by this unit
///   to obtain the amount to display.
/// - `locale`: The locale to use for formatting (BCP 47 language tag like "en-US", "fr-FR").
///   If `None`, uses the system's default locale.
/// - `config`: The configuration object specifying the style and numeric behaviour
///
/// ## Example
///
/// ```gleam
/// import gleam/option
/// import gleam/time/duration
/// import intlrelative
///
/// intlrelative.format(
///   duration: duration.seconds(-5),
///   unit: intlrelative.Second,
///   locale: option.Some("fr-FR"),
///   config: intlrelative.new(),
/// )
/// // -> "il y a 5 secondes"
/// ```
///
pub fn format(
  duration duration: duration.Duration,
  unit unit: Unit,
  locale locale: Option(String),
  config config: RelativeTimeFormatConfig,
) -> String {
  case raw_format(duration, unit, locale, config) {
    Ok(formatted) -> formatted
    Error(error) -> describe_error(error)
  }
}

pub type IntlError {
  /// The requested locale could not be loaded or resolved.
  FailedToLoadLocale(inner: String)
  /// The bundled locale data could not be loaded or validated.
  FailedToLoadData(inner: String)
  /// Any error not accounted for by this type.
  Unknown(inner: String)
}

/// Convert an error into a human-readable description.
///
/// ## Example
/// ```gleam
/// let assert "Failed to load locale: fr-FR" =
///   describe_error(FailedToLoadLocale("fr-FR"))
/// ```
///
pub fn describe_error(error: IntlError) -> String {
  case error {
    FailedToLoadLocale(inner) -> "Failed to load locale: " <> inner
    FailedToLoadData(inner) -> "Failed to load data: " <> inner
    Unknown(inner) -> "Unknown error: " <> inner
  }
}

/// Format a duration as a relative time according to the specified locale and
/// configuration, returning a `Result` instead of falling back to an error message.
///
/// This is identical to `format`, except it lets you handle the `IntlError`
/// yourself instead of getting a human-readable string when resolution fails.
///
/// ## Example
///
/// ```gleam
/// import gleam/option
/// import gleam/time/duration
/// import intlrelative
///
/// intlrelative.try_format(
///   duration: duration.hours(3),
///   unit: intlrelative.Hour,
///   locale: option.Some("invalid-locale"),
///   config: intlrelative.new(),
/// )
/// // -> Error(intlrelative.FailedToLoadLocale("invalid-locale"))
/// ```
///
pub fn try_format(
  duration duration: duration.Duration,
  unit unit: Unit,
  locale locale: Option(String),
  config config: RelativeTimeFormatConfig,
) -> Result(String, IntlError) {
  raw_format(duration, unit, locale, config)
}

/// Format a duration and return the structured parts of the formatted output.
///
/// This mirrors `Intl.RelativeTimeFormat.prototype.formatToParts`.
pub fn format_to_parts(
  duration duration: duration.Duration,
  unit unit: Unit,
  locale locale: Option(String),
  config config: RelativeTimeFormatConfig,
) -> List(RelativeTimeFormatPart) {
  case raw_format_to_parts(duration, unit, locale, config) {
    Ok(parts) -> parts
    Error(error) -> [
      RelativeTimeFormatPart(
        kind: RelativeTimePartLiteral,
        value: describe_error(error),
        unit: None,
      ),
    ]
  }
}

/// Format a duration to parts, returning a `Result`.
pub fn try_format_to_parts(
  duration duration: duration.Duration,
  unit unit: Unit,
  locale locale: Option(String),
  config config: RelativeTimeFormatConfig,
) -> Result(List(RelativeTimeFormatPart), IntlError) {
  raw_format_to_parts(duration, unit, locale, config)
}

/// Return the options resolved by the relative time formatter.
///
/// This mirrors `Intl.RelativeTimeFormat.prototype.resolvedOptions`.
pub fn resolved_options(
  locale locale: Option(String),
  config config: RelativeTimeFormatConfig,
) -> Result(RelativeTimeResolvedOptions, IntlError) {
  raw_resolved_options(locale, config)
}

@external(javascript, "./intldate.ffi.mjs", "formatDuration")
fn raw_format(
  duration: duration.Duration,
  unit: Unit,
  locale: Option(String),
  config: RelativeTimeFormatConfig,
) -> Result(String, IntlError) {
  case
    core.format_relative(
      duration,
      map_unit(unit),
      locale,
      map_style(config.style),
      map_numeric(config.numeric),
      map_locale_matcher(config.locale_matcher),
    )
  {
    Ok(formatted) -> Ok(formatted)
    Error(icu.FailedToLoadLocale(inner)) -> Error(FailedToLoadLocale(inner))
    Error(icu.FailedToLoadData(inner)) -> Error(FailedToLoadData(inner))
    Error(icu.FailedToLoadTimeZone(inner))
    | Error(icu.FailedToLoadCalendar(inner))
    | Error(icu.Unknown(inner)) -> Error(Unknown(inner))
    Error(icu.SystemTimeZoneUnavailable) ->
      Error(Unknown("System time zone unavailable"))
  }
}

@external(javascript, "./intldate.ffi.mjs", "formatDurationToParts")
fn raw_format_to_parts(
  duration: duration.Duration,
  unit: Unit,
  locale: Option(String),
  config: RelativeTimeFormatConfig,
) -> Result(List(RelativeTimeFormatPart), IntlError) {
  case
    core.format_relative_to_parts(
      duration,
      map_unit(unit),
      locale,
      map_style(config.style),
      map_numeric(config.numeric),
      map_locale_matcher(config.locale_matcher),
    )
  {
    Ok(parts) -> Ok(list.map(parts, map_icu_relative_part))
    Error(icu.FailedToLoadLocale(inner)) -> Error(FailedToLoadLocale(inner))
    Error(icu.FailedToLoadData(inner)) -> Error(FailedToLoadData(inner))
    Error(icu.FailedToLoadTimeZone(inner))
    | Error(icu.FailedToLoadCalendar(inner))
    | Error(icu.Unknown(inner)) -> Error(Unknown(inner))
    Error(icu.SystemTimeZoneUnavailable) ->
      Error(Unknown("System time zone unavailable"))
  }
}

@external(javascript, "./intldate.ffi.mjs", "relativeResolvedOptions")
fn raw_resolved_options(
  locale: Option(String),
  config: RelativeTimeFormatConfig,
) -> Result(RelativeTimeResolvedOptions, IntlError) {
  case
    core.relative_resolved_options(
      locale,
      map_locale_matcher(config.locale_matcher),
    )
  {
    Ok(#(resolved_locale, numbering_system)) ->
      Ok(RelativeTimeResolvedOptions(
        locale: resolved_locale,
        numbering_system:,
        style: style_name(option.unwrap(config.style, Long)),
        numeric: numeric_name(option.unwrap(config.numeric, Always)),
      ))
    Error(icu.FailedToLoadLocale(inner)) -> Error(FailedToLoadLocale(inner))
    Error(icu.FailedToLoadData(inner)) -> Error(FailedToLoadData(inner))
    Error(icu.FailedToLoadTimeZone(inner))
    | Error(icu.FailedToLoadCalendar(inner))
    | Error(icu.Unknown(inner)) -> Error(Unknown(inner))
    Error(icu.SystemTimeZoneUnavailable) ->
      Error(Unknown("System time zone unavailable"))
  }
}

fn map_unit(unit: Unit) -> core.RelativeUnit {
  case unit {
    Second -> core.Second
    Minute -> core.Minute
    Hour -> core.Hour
    Day -> core.Day
    Week -> core.Week
    Month -> core.Month
    Quarter -> core.Quarter
    Year -> core.Year
  }
}

fn map_style(style: Option(Style)) -> core.TextStyle {
  case style {
    Some(Long) | None -> core.StyleLong
    Some(Short) -> core.StyleShort
    Some(Narrow) -> core.StyleNarrow
  }
}

fn map_numeric(numeric: Option(Numeric)) -> core.RelativeNumeric {
  case numeric {
    Some(Auto) -> core.NumericAuto
    Some(Always) | None -> core.NumericAlways
  }
}

fn map_locale_matcher(
  matcher: Option(LocaleMatcher),
) -> core.LocaleMatcherStyle {
  case matcher {
    Some(LocaleMatcherLookup) -> core.LocaleMatcherLookup
    Some(LocaleMatcherBestFit) | None -> core.LocaleMatcherBestFit
  }
}

fn style_name(style: Style) -> String {
  case style {
    Long -> "long"
    Short -> "short"
    Narrow -> "narrow"
  }
}

fn numeric_name(numeric: Numeric) -> String {
  case numeric {
    Always -> "always"
    Auto -> "auto"
  }
}

fn map_icu_relative_part(
  part: core.RelativeTimePart,
) -> RelativeTimeFormatPart {
  RelativeTimeFormatPart(
    kind: relative_part_kind(part.kind),
    value: part.value,
    unit: part.unit,
  )
}

fn relative_part_kind(kind: String) -> RelativeTimePartKind {
  case kind {
    "literal" -> RelativeTimePartLiteral
    "integer" -> RelativeTimePartInteger
    "fraction" -> RelativeTimePartFraction
    "decimal" -> RelativeTimePartDecimal
    "unit" -> RelativeTimePartUnit
    other -> RelativeTimePartUnknown(other)
  }
}

/// A part type returned by `format_to_parts`.
pub type RelativeTimePartKind {
  RelativeTimePartLiteral
  RelativeTimePartInteger
  RelativeTimePartFraction
  RelativeTimePartDecimal
  RelativeTimePartUnit
  RelativeTimePartUnknown(inner: String)
}

/// One structured part of a formatted relative time string.
pub type RelativeTimeFormatPart {
  RelativeTimeFormatPart(
    kind: RelativeTimePartKind,
    value: String,
    unit: Option(String),
  )
}

/// Options resolved by a relative time formatter.
pub type RelativeTimeResolvedOptions {
  RelativeTimeResolvedOptions(
    locale: String,
    numbering_system: String,
    style: String,
    numeric: String,
  )
}

/// The unit the duration is expressed in.
///
/// - `Second`: Seconds
/// - `Minute`: Minutes
/// - `Hour`: Hours
/// - `Day`: Days
/// - `Week`: Weeks
/// - `Month`: Months
/// - `Quarter`: Quarters (three-month periods)
/// - `Year`: Years
///
pub type Unit {
  Second
  Minute
  Hour
  Day
  Week
  Month
  Quarter
  Year
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

/// The length of the formatted message.
///
/// - `Long`: Full form (e.g., "in 3 hours", "il y a 5 secondes")
/// - `Short`: Abbreviated form (e.g., "in 3 hr.", "in 2 min.")
/// - `Narrow`: Narrow form, may be identical to `Short` for some locales (e.g., "3 hr. ago", "1h ago")
///
pub type Style {
  Long
  Short
  Narrow
}

/// Whether to always use the numeric value or allow idiomatic phrasing.
///
/// - `Always`: Always output a numeric value (e.g., "1 day ago", "il y a 1 jour")
/// - `Auto`: Use idiomatic phrasing when available (e.g., "yesterday", "hier")
///
pub type Numeric {
  Always
  Auto
}

/// Configuration for relative time formatting.
///
/// This type allows you to specify the style and numeric behaviour of the
/// formatted output.
///
/// Create a new configuration with `new()` and customize it with the various
/// `with_*` functions.
///
pub type RelativeTimeFormatConfig {
  RelativeTimeFormatConfig(
    locale_matcher: Option(LocaleMatcher),
    style: Option(Style),
    numeric: Option(Numeric),
  )
}

/// Create a new relative time format configuration with all options unset.
///
/// Use the various `with_*` functions to customize the configuration.
///
/// ## Example
///
/// ```gleam
/// intlrelative.new()
///   |> intlrelative.with_style(intlrelative.Short)
///   |> intlrelative.with_numeric(intlrelative.Auto)
/// ```
///
pub fn new() -> RelativeTimeFormatConfig {
  RelativeTimeFormatConfig(locale_matcher: None, style: None, numeric: None)
}

/// Set the locale matching algorithm.
///
/// The locale matcher determines how the runtime selects the best matching
/// locale when the exact locale you requested isn't available.
///
pub fn with_locale_matcher(
  config: RelativeTimeFormatConfig,
  locale_matcher: LocaleMatcher,
) -> RelativeTimeFormatConfig {
  RelativeTimeFormatConfig(..config, locale_matcher: Some(locale_matcher))
}

/// Set the length of the formatted message.
///
pub fn with_style(
  config: RelativeTimeFormatConfig,
  style: Style,
) -> RelativeTimeFormatConfig {
  RelativeTimeFormatConfig(..config, style: Some(style))
}

/// Set whether to always use the numeric value or allow idiomatic phrasing.
///
pub fn with_numeric(
  config: RelativeTimeFormatConfig,
  numeric: Numeric,
) -> RelativeTimeFormatConfig {
  RelativeTimeFormatConfig(..config, numeric: Some(numeric))
}
