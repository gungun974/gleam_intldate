import gleam/option
import gleam/time/timestamp
import gleeunit
import intldate

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn try_format_returns_error_for_invalid_time_zone_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.try_format(
      date:,
      time_zone: option.Some("Invalid/TimeZone"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == Error(intldate.FailedToLoadTimeZone("Invalid/TimeZone"))
}

pub fn format_returns_error_message_for_invalid_time_zone_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Invalid/TimeZone"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Failed to load time zone: Invalid/TimeZone"
}

pub fn try_format_returns_error_for_invalid_locale_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.try_format(
      date:,
      time_zone: option.None,
      locale: option.Some("xx-XX"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == Error(intldate.FailedToLoadLocale("xx-XX"))
}

pub fn format_returns_error_message_for_invalid_locale_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.None,
      locale: option.Some("xx-XX"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Failed to load locale: xx-XX"
}

pub fn try_format_returns_error_for_malformed_locale_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.try_format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en_US"),
      config: intldate.new(),
    )

  assert result == Error(intldate.FailedToLoadLocale("en_US"))
}

pub fn resolved_options_rejects_invalid_time_zone_test() {
  let result =
    intldate.resolved_options(
      time_zone: option.Some("Invalid/TimeZone"),
      locale: option.Some("en-US"),
      config: intldate.new(),
    )

  assert result == Error(intldate.FailedToLoadTimeZone("Invalid/TimeZone"))
}

pub fn resolved_options_uses_locale_default_calendar_test() {
  let assert Ok(options) =
    intldate.resolved_options(
      time_zone: option.Some("UTC"),
      locale: option.Some("th-TH"),
      config: intldate.new(),
    )

  assert options.locale == "th-TH"
  assert options.calendar == "buddhist"
  assert options.time_zone == "UTC"
}

pub fn resolved_options_preserves_numbering_system_extension_test() {
  let assert Ok(options) =
    intldate.resolved_options(
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US-u-nu-arab"),
      config: intldate.new(),
    )

  assert options.locale == "en-US-u-nu-arab"
  assert options.numbering_system == "arab"
}

pub fn resolved_options_canonicalizes_locale_and_time_zone_test() {
  let assert Ok(options) =
    intldate.resolved_options(
      time_zone: option.Some("Asia/Kolkata"),
      locale: option.Some("iw-IL"),
      config: intldate.new(),
    )

  assert options.locale == "he-IL"
  assert options.time_zone == "Asia/Calcutta"
}

pub fn resolved_options_resolves_runtime_defaults_test() {
  let assert Ok(options) =
    intldate.resolved_options(
      time_zone: option.None,
      locale: option.None,
      config: intldate.new(),
    )

  assert options.locale != ""
  assert options.time_zone != ""
}
