import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import gleeunit
import intldate

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn format_ko_kr_full_weekday_hour_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ko-KR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "2026년 2월 24일 화요일 오후 1:48"
}

pub fn format_ko_kr_date_only_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ko-KR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2026년 2월 24일"
}

pub fn format_ko_kr_with_hour_asia_seoul_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Asia/Seoul"),
      locale: option.Some("ko-KR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric),
    )
  assert result == "2026년 2월 24일 오후 10시"
}

pub fn format_ru_ru_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ru-RU"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "вторник, 24 февраля 2026 г."
}

pub fn format_ru_ru_date_with_time_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ru-RU"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "24 февраля 2026 г. в 13:48"
}

pub fn format_nl_nl_full_with_time_2digit_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("nl-NL"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit),
    )
  assert result == "dinsdag 24 februari 2026 om 13:48"
}

pub fn format_nl_nl_date_only_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("nl-NL"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 februari 2026"
}

pub fn format_pl_pl_date_long_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("pl-PL"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 lutego 2026"
}

pub fn format_pl_pl_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("pl-PL"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "wtorek, 24 lutego 2026"
}

pub fn format_tr_tr_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("tr-TR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 Şubat 2026 Salı"
}

pub fn format_tr_tr_date_with_time_2digit_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("tr-TR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit),
    )
  assert result == "24 Şubat 2026 13:48"
}

pub fn format_sv_se_date_with_time_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("sv-SE"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "24 februari 2026 kl. 13:48"
}

pub fn format_sv_se_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("sv-SE"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "tisdag 24 februari 2026"
}

pub fn format_nb_no_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("nb-NO"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "tirsdag 24. februar 2026"
}

pub fn format_nb_no_date_with_2digit_time_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("nb-NO"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit),
    )
  assert result == "24. februar 2026 kl. 13:48"
}

pub fn format_fi_fi_date_long_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fi-FI"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24. helmikuuta 2026"
}

pub fn format_fi_fi_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fi-FI"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "tiistaina 24. helmikuuta 2026"
}

pub fn format_da_dk_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("da-DK"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "tirsdag den 24. februar 2026"
}

pub fn format_da_dk_date_long_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("da-DK"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24. februar 2026"
}

pub fn format_hu_hu_date_long_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("hu-HU"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2026. február 24."
}

pub fn format_hu_hu_date_short_month_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("hu-HU"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2026. febr. 24."
}

pub fn format_cs_cz_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("cs-CZ"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "úterý 24. února 2026"
}

pub fn format_cs_cz_date_with_time_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("cs-CZ"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "24. února 2026 v 13:48"
}

pub fn format_ro_ro_weekday_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ro-RO"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "marți, 24 februarie 2026"
}

pub fn format_ro_ro_date_short_month_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ro-RO"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 feb. 2026"
}

pub fn format_zh_cn_weekday_short_date_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("zh-CN"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2026/2/24周二"
}

pub fn format_zh_cn_date_long_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("zh-CN"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2026年2月24日"
}

pub fn format_zh_cn_month_narrow_day_utc_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("zh-CN"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2月24日"
}

pub fn format_midnight_en_us_hour12_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
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
  assert result == "12:00:00 AM"
}

pub fn format_noon_en_us_hour12_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T12:00:00+00:00")
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
  assert result == "12:00:00 PM"
}

pub fn format_late_night_fr_fr_2digit_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T23:59:59+00:00")
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
  assert result == "23:59:59"
}

pub fn format_early_morning_de_de_2digit_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T01:05:03+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_second(intldate.Second2Digit),
    )
  assert result == "01:05:03"
}

pub fn format_ja_midnight_h11_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "0:00"
}

pub fn format_ja_half_past_midnight_h11_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:30:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "0:30"
}

pub fn format_ja_noon_h11_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T12:30:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "12:30"
}

pub fn format_hour12_true_morning_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T03:15:00+00:00")
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
  assert result == "3:15 AM"
}

pub fn format_hour12_true_afternoon_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T15:15:00+00:00")
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
  assert result == "3:15 PM"
}

pub fn format_hour12_true_midnight_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
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
  assert result == "12:00 AM"
}

pub fn format_hour12_true_noon_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T12:00:00+00:00")
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
  assert result == "12:00 PM"
}

pub fn format_hour12_false_midnight_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
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
  assert result == "00:00"
}

pub fn format_hour12_false_noon_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T12:00:00+00:00")
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
  assert result == "12:00"
}

pub fn format_hour12_true_morning_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T03:15:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_hour12(True),
    )
  assert result == "3:15 AM"
}

pub fn format_hour12_false_afternoon_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T15:15:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_hour12(False),
    )
  assert result == "15:15"
}

pub fn format_timezone_day_rollback_to_prev_year_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-01-01T00:30:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "Wednesday, December 31, 2025 at 7:30 PM"
}

pub fn format_timezone_day_advance_to_next_year_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-12-31T23:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/Paris"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "1 janvier 2027 à 00:00"
}

pub fn format_indian_reunion_year_change_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-12-31T20:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Indian/Reunion"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "1 janvier 2027 à 00:00"
}

pub fn format_dst_spring_forward_edt_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-03-08T07:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShort),
    )
  assert result == "3:00 AM EDT"
}

pub fn format_dst_fall_back_est_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-11-01T06:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShort),
    )
  assert result == "1:00 AM EST"
}

pub fn format_dst_spring_forward_cest_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-03-29T01:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/Paris"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong),
    )
  assert result == "03:00 heure d’été d’Europe centrale"
}

pub fn format_leap_year_feb_29_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2024-02-29T12:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "Thursday, February 29, 2024"
}

pub fn format_leap_year_feb_29_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2024-02-29T12:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "jeudi 29 février 2024"
}

pub fn format_year_2000_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2000-01-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "January 1, 2000"
}

pub fn format_year_1999_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("1999-12-31T23:59:59+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )
  assert result == "December 31, 1999 at 11:59 PM"
}

pub fn format_year_2000_ja_jp_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2000-01-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "2000/1/1"
}

pub fn format_month_narrow_january_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-01-15T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "15 J"
}

pub fn format_month_narrow_june_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "15 J"
}

pub fn format_month_narrow_july_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-07-15T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "15 J"
}

pub fn format_month_short_december_de_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-12-25T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_year(intldate.YearNumeric),
    )
  assert result == "25. Dez. 2026"
}

pub fn format_month_narrow_august_es_es_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-08-10T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("es-ES"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_year(intldate.YearNumeric),
    )
  assert result == "10 A 2026"
}

pub fn format_weekday_narrow_de_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong),
    )
  assert result == "D, 24. Februar"
}

pub fn format_weekday_narrow_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthLong),
    )
  assert result == "M 24 février"
}

pub fn format_era_narrow_de_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraNarrow)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24. Februar 2026 n. Chr."
}

pub fn format_era_short_de_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24.02.2026 n. Chr."
}

pub fn format_era_short_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24/02/2026 ap. J.-C."
}

pub fn format_era_short_fr_fr_past_test() {
  let date =
    timestamp.from_calendar(
      date: calendar.Date(year: -43, month: calendar.March, day: 15),
      time: calendar.TimeOfDay(
        hours: 13,
        minutes: 48,
        seconds: 22,
        nanoseconds: 0,
      ),
      offset: calendar.utc_offset,
    )

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "15/03/44 av. J.-C."
}

pub fn format_era_short_fr_fr_zero_test() {
  let date =
    timestamp.from_calendar(
      date: calendar.Date(year: 0, month: calendar.February, day: 24),
      time: calendar.TimeOfDay(
        hours: 13,
        minutes: 48,
        seconds: 22,
        nanoseconds: 0,
      ),
      offset: calendar.utc_offset,
    )

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )

  assert result == "24/02/1 av. J.-C."
}

pub fn format_era_long_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_era(intldate.EraLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 février 2026 après Jésus-Christ"
}

pub fn format_tz_short_offset_summer_ny_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T10:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortOffset),
    )
  assert result == "6:00 AM GMT-4"
}

pub fn format_tz_long_offset_summer_london_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T10:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/London"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongOffset),
    )
  assert result == "11:00 AM GMT+01:00"
}

pub fn format_tz_short_offset_winter_ny_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-01-15T10:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortOffset),
    )
  assert result == "5:00 AM GMT-5"
}

pub fn format_tz_long_generic_summer_chicago_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-07-04T15:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/Chicago"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric),
    )
  assert result == "July 4, 2026 at 10 AM Central Time"
}

pub fn format_tz_short_generic_winter_la_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-01-15T10:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/Los_Angeles"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortGeneric),
    )
  assert result == "2:00 AM PT"
}

pub fn format_tz_short_generic_summer_la_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-07-04T15:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/Los_Angeles"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShortGeneric),
    )
  assert result == "8:00 AM PT"
}

pub fn format_tz_short_with_seconds_summer_ny_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T18:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_second(intldate.SecondNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameShort),
    )
  assert result == "2:00:00 PM EDT"
}

pub fn format_tz_long_summer_paris_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-15T18:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Europe/Paris"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong),
    )
  assert result == "20:00 heure d’été d’Europe centrale"
}

pub fn format_year_month_only_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-01-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong),
    )
  assert result == "janvier 2026"
}

pub fn format_year_month_short_de_de_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-12-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("de-DE"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthShort),
    )
  assert result == "Dez. 2026"
}

pub fn format_year_month_numeric_ja_jp_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-06-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ja-JP"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthNumeric),
    )
  assert result == "2026/6"
}

pub fn format_month_2digit_day_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-05T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.Day2Digit),
    )
  assert result == "2/05"
}

pub fn format_day_month_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-09-05T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_month(intldate.MonthNumeric),
    )
  assert result == "05/09"
}

pub fn format_year_2digit_en_us_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-09-05T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("en-US"),
      config: intldate.new()
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "9/5/26"
}

pub fn format_year_2digit_millenium_fr_fr_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2000-01-01T00:00:00+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "01/01/00"
}

pub fn format_range_fa_ir_hebrew_narrow_month_distinct_fields_collapses_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2007-10-17T02:27:54+00:00")
  let assert Ok(end) = timestamp.parse_rfc3339("2008-08-04T07:51:58+00:00")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("UTC"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_calendar(intldate.CalendarHebrew)
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthNarrow)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(False),
    )

  assert result == "ح ۶۸ تقویم عبری"
}

pub fn format_th_th_date_long_buddhist_year_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Asia/Bangkok"),
      locale: option.Some("th-TH"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "24 กุมภาพันธ์ 2569"
}

pub fn format_ar_sa_date_long_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ar-SA"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "٢٤ فبراير ٢٠٢٦"
}

pub fn format_ar_eg_date_long_arab_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ar-EG"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "٢٤ فبراير ٢٠٢٦"
}

pub fn format_ks_arab_date_long_arabext_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ks-Arab"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "فرؤری ۲۴, ۲۰۲۶"
}

pub fn format_ne_date_long_deva_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ne"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "२०२६ फेब्रुअरी २४"
}

pub fn format_bn_in_date_long_beng_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-03-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("bn-IN"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "২৪ মার্চ, ২০২৬"
}

pub fn format_my_date_long_mymr_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("my"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "၂၀၂၆ ဖေဖော်ဝါရီ ၂၄"
}

pub fn format_ff_adlm_date_long_adlm_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("ff-Adlm-BF"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "𞥒𞥔 𞤕𞤮𞤤𞤼𞤮⹁ 𞥒𞥐𞥒𞥖"
}

pub fn format_nqo_date_long_nkoo_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("nqo"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "߂߀߂߆ ߞߏ߲ߞߏߜߍ ߂߄"
}

pub fn format_dz_date_long_tibt_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("dz"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "སྤྱི་ལོ་༢༠༢༦ ཟླ་གཉིས་པ་ ཚེས་ ༢༤"
}

pub fn format_sat_date_long_olck_numerals_test() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T13:48:22+00:00")
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("UTC"),
      locale: option.Some("sat"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )
  assert result == "᱒᱔ ᱯᱷᱟᱨᱣᱟᱨᱤ ᱒᱐᱒᱖"
}

pub fn format_fr_fr_month_day_tz_no_spurious_hour_test() {
  let date = timestamp.from_unix_seconds_and_nanoseconds(1_754_459_774, 0)
  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Indian/Reunion"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_month(intldate.MonthNumeric)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong),
    )
  assert result == "06/08 heure de La Réunion"
}
