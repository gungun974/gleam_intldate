import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp
import intldate

pub fn format_range_date_only_fr_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-27T13:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "24–27 février 2026"
}

pub fn format_range_to_parts_reconstructs_format_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-01-10T00:00:00+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-03-05T00:00:00+00:00")
  let config =
    intldate.new()
    |> intldate.with_year(intldate.YearNumeric)
    |> intldate.with_month(intldate.MonthLong)
    |> intldate.with_day(intldate.DayNumeric)

  let formatted =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config:,
    )

  let reconstructed =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config:,
    )
    |> list.map(fn(part) { part.value })
    |> string.concat

  assert reconstructed == formatted
}

pub fn format_range_time_only_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-24T15:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "1:48 – 3:48 PM"
}

pub fn format_range_across_months_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-01-10T00:00:00+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-03-05T00:00:00+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "January 10 – March 5, 2026"
}

pub fn format_range_full_weekday_de_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-27T13:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Dienstag, 24. – Freitag, 27. Februar 2026"
}

pub fn format_range_across_years_short_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-12-30T10:00:00+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2027-01-02T10:00:00+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Dec 30, 2026 – Jan 2, 2027"
}

pub fn format_range_identical_dates_collapses_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "February 24, 2026"
}

pub fn format_range_datetime_explicit_timezone_fr_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-27T17:48:22+04:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Indian/Reunion"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "24 février 2026 à 17:48 – 27 février 2026 à 17:48"
}

pub fn format_range_same_date_fr_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "24 février 2026"
}

pub fn format_range_reversed_dates_en_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-02-27T13:48:22+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "February 27 – 24, 2026"
}

pub fn format_range_same_day_hours_ja_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2026-06-01T08:00:00+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2026-06-01T17:30:00+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "8時00分～17時30分"
}
