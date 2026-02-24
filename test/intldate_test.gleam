import gleam/option
import gleam/time/timestamp
import gleeunit
import intldate

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn format_full_date_with_utc_timezone_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "mardi 24 février 2026 à 13:48"
}

pub fn format_full_date_implicit_utc_conversion_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "mardi 24 février 2026 à 13:48"
}

pub fn format_full_date_with_explicit_timezone_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Indian/Reunion"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "mardi 24 février 2026 à 17:48"
}

pub fn format_short_weekday_and_month_en_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Tue, Feb 24, 2026"
}

pub fn format_date_only_without_time_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-12-31T23:59:59+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "31. Dezember 2026"
}

pub fn format_time_only_with_seconds_en_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_second(intldate.SecondNumeric),
    )

  assert result == "1:48:22 PM"
}

pub fn format_with_two_digit_year_ja_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "26/2/24"
}

pub fn format_with_two_digit_month_and_day_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-05T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.Month2Digit)
        |> intldate.with_day(intldate.Day2Digit),
    )

  assert result == "02/05/2026"
}

pub fn format_with_narrow_month_es_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-03-15T10:30:45+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("es-ES"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "domingo, 15 M"
}

pub fn format_with_two_digit_hour_and_minute_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T05:08:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_second(intldate.Second2Digit),
    )

  assert result == "05:08:22 AM"
}

pub fn format_with_america_timezone_en_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "February 24, 2026 at 8:48 AM"
}

pub fn format_with_asia_timezone_zh_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Asia/Tokyo"),
      locale: option.Some("zh-CN"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "2026年2月24日 22:48"
}

pub fn format_minimal_config_date_only_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T18:30:00+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "6/15"
}

pub fn format_with_narrow_weekday_it_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("it-IT"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_year(intldate.YearNumeric),
    )

  assert result == "M 24 febbraio 2026"
}

pub fn format_with_none_locale_default_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.None,
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "February 24, 2026 at 1:48 PM"
}

pub fn format_midnight_time_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_second(intldate.Second2Digit),
    )

  assert result == "00:00:00"
}

pub fn format_complex_europe_timezone_pt_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-07-15T22:30:15+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/Lisbon"),
      locale: option.Some("pt-PT"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit),
    )

  assert result == "quarta-feira, 15 de julho de 2026 às 23:30"
}

pub fn format_only_year_and_month_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-11-20T15:45:30+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort),
    )

  assert result == "Nov 2026"
}

pub fn format_with_era_long_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "February 24, 2026 Anno Domini"
}

pub fn format_with_era_short_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "2/24/2026 AD"
}

pub fn format_with_era_narrow_ja_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraNarrow)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "AD2026年2月24日"
}

pub fn format_with_timezone_name_short_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShort),
    )

  assert result == "Feb 24, 8:48 AM EST"
}

pub fn format_with_timezone_name_long_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/Paris"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong),
    )

  assert result == "24 février à 14:48 heure normale d’Europe centrale"
}

pub fn format_with_timezone_name_short_offset_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Asia/Tokyo"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortOffset),
    )

  assert result == "2/24, 10:48 PM GMT+9"
}

pub fn format_with_timezone_name_long_offset_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-07-15T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/Los_Angeles"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongOffset),
    )

  assert result == "July 15, 2026 at 6 AM GMT-07:00"
}

pub fn format_with_timezone_name_short_generic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Australia/Sydney"),
      locale: option.Some("en-AU"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortGeneric),
    )

  assert result == "Wed, 25 Feb, 12:48 am AET"
}

pub fn format_with_timezone_name_long_generic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/Chicago"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric),
    )

  assert result == "February 24, 2026 at 7:48 AM Central Time"
}

pub fn format_with_hour12_true_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_hour12(True),
    )

  assert result == "5:48 PM"
}

pub fn format_with_hour12_false_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_hour12(False),
    )

  assert result == "17:48"
}

pub fn format_with_locale_matcher_best_fit_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-CA"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "24 février 2026"
}

pub fn format_with_locale_matcher_lookup_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-GB"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_year(intldate.YearNumeric),
    )

  assert result == "Tuesday, 24 February 2026"
}

pub fn format_with_format_matcher_best_fit_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  assert result == "24.2.2026, 13:48"
}

pub fn format_with_format_matcher_basic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("es-ES"),
      config: intldate.new()
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_year(intldate.YearNumeric),
    )

  assert result == "mar, 24 feb 2026"
}

pub fn format_complex_all_options_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/London"),
      locale: option.Some("en-GB"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_second(intldate.Second2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(False),
    )

  assert result
    == "Tuesday, 24 February 2026 AD at 13:48:22 Greenwich Mean Time"
}

pub fn format_empty_config_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new(),
    )

  assert result == "2/24/2026"
}
