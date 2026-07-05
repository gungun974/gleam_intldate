import gleam/option
import gleam/time/timestamp
import gleeunit
import intldate
@target(erlang)
import zones

pub fn main() -> Nil {
  let _ = configure_test_timezone()

  gleeunit.main()
}

@external(erlang, "intldate_test", "do_configure_test_timezone")
fn configure_test_timezone() -> Nil {
  Nil
}

@target(erlang)
pub fn do_configure_test_timezone() {
  intldate.set_time_zone_database(zones.database())
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

fn tz_name(locale: String, matcher: intldate.LocaleMatcher) -> String {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  intldate.format(
    date:,
    time_zone: option.Some("America/Los_Angeles"),
    locale: option.Some(locale),
    config: intldate.new()
      |> intldate.with_locale_matcher(matcher)
      |> intldate.with_hour(intldate.HourNumeric)
      |> intldate.with_minute(intldate.MinuteNumeric)
      |> intldate.with_time_zone_name(intldate.TimeZoneNameLong)
      |> intldate.with_hour12(False),
  )
}

pub fn format_lookup_truncates_subtags_one_at_a_time_test() {
  assert tz_name("zh-Hant-QQ", intldate.LocaleMatcherLookup)
    == "05:48 [太平洋標準時間]"

  assert tz_name("zh-Hant-QQ", intldate.LocaleMatcherBestFit)
    == "05:48 [太平洋標準時間]"
}

pub fn format_locale_matcher_applies_likely_script_test() {
  assert tz_name("zh-TW", intldate.LocaleMatcherLookup) == "05:48 [太平洋標準時間]"

  assert tz_name("zh-TW", intldate.LocaleMatcherBestFit) == "05:48 [太平洋標準時間]"

  assert tz_name("zh-CN", intldate.LocaleMatcherLookup) == "北美太平洋标准时间 05:48"
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

pub fn format_with_calendar_gregory_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarGregory)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "February 24, 2026"
}

pub fn format_with_calendar_japanese_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarJapanese)
        |> intldate.with_era(intldate.EraLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "令和8/2/24"
}

pub fn format_with_calendar_buddhist_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("th-TH"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarBuddhist)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "24/2/2569"
}

pub fn format_with_calendar_hebrew_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("he-IL"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarHebrew)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "7 באדר 5786"
}

pub fn format_with_calendar_persian_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarPersian)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "۵ اسفند ۱۴۰۴"
}

pub fn format_with_calendar_islamic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ar-SA"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamic)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "٧ رمضان ١٤٤٧ هـ"
}

pub fn format_with_calendar_islamic_umalqura_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ar-SA"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamicUmalqura)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "٧ رمضان ١٤٤٧ هـ"
}

pub fn format_with_calendar_islamic_tbla_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamicTbla)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Ramadan 8, 1447 AH"
}

pub fn format_with_calendar_islamic_civil_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamicCivil)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Ramadan 7, 1447 AH"
}

pub fn format_with_calendar_islamic_rgsa_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ar-SA"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamicRgsa)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "٧ رمضان ١٤٤٧ هـ"
}

pub fn format_with_calendar_roc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("zh-TW"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarRoc)
        |> intldate.with_era(intldate.EraLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "民國115/2/24"
}

pub fn format_with_calendar_chinese_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("zh-CN"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "2026丙午年正月8"
}

pub fn format_with_calendar_dangi_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ko-KR"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarDangi)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "2026년(병오년) 1월 8일"
}

pub fn format_with_calendar_indian_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("hi-IN"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIndian)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "5 फाल्गुन 1947 शक"
}

pub fn format_with_calendar_coptic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarCoptic)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Amshir 17, 1742 AM"
}

pub fn format_with_calendar_ethiopic_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("am-ET"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarEthiopic)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "17 የካቲት 2018"
}

pub fn format_with_calendar_ethioaa_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarEthioaa)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "Yekatit 17, 7518 AA"
}

pub fn format_with_calendar_iso8601_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIso8601)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "2026-02-24"
}
