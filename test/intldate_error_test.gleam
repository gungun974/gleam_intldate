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
