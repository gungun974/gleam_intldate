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

pub fn format_range_fa_islamic_does_not_use_persian_collapse_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1994-04-18T16:12:53Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1994-05-15T13:17:38Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Asia/Jerusalem"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarIslamic)
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthLong),
    )

  assert result == "د ذیقعده ۱۴ تا ی ذیحجه ۱۴"
}

pub fn format_range_fa_indian_does_not_use_persian_collapse_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2020-10-08T08:21:32Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2021-01-20T11:28:17Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Africa/Cairo"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
        |> intldate.with_calendar(intldate.CalendarIndian)
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_era(intldate.EraLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_second(intldate.Second2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongOffset)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(False),
    )

  assert result
    == "پ آشوین ۱۹۴۲ تقویم ساکا ساعت ۱۰:۲۱:۳۲ (‎+۰۲:۰۰ گرینویچ) تا چ پاوشه ۱۹۴۲ تقویم ساکا ساعت ۱۳:۲۸:۱۷ (‎+۰۲:۰۰ گرینویچ)"
}

pub fn format_range_fa_persian_with_weekday_and_time_does_not_collapse_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1991-05-21T06:17:19Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1991-06-12T09:35:15Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Australia/Eucla"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_era(intldate.EraNarrow)
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(True),
    )

  assert result == "س اردیبهشت ۷۰ ه‍.ش.، ۳:۰۲ ب.ظ. تا چ خرداد ۷۰ ه‍.ش.، ۶:۲۰ ب.ظ."
}

pub fn format_range_fa_persian_year_and_month_only_still_collapses_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1991-05-21T06:17:19Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1991-06-12T09:35:15Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Australia/Eucla"),
      locale: option.Some("fa-IR"),
      config: intldate.new()
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthShort),
    )

  assert result == "اردیبهشت ۷۰"
}

pub fn format_range_generic_zone_name_during_repeated_hour_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2012-09-12T01:36:15Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2013-11-03T10:33:04Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/Anchorage"),
      locale: option.Some("zh-CN-u-ca-chinese"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_calendar(intldate.CalendarBuddhist)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit),
    )

  assert result == "11日 阿拉斯加时间 – 3日 阿拉斯加时间"
}

pub fn format_range_generic_zone_name_uses_later_overlap_offset_sr_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1981-09-26T23:22:14Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1982-05-04T10:39:45Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Africa/Cairo"),
      locale: option.Some("sr-RS"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_era(intldate.EraShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_second(intldate.Second2Digit)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit),
    )

  assert result
    == "1981. н. е. (дан: недеља 27.) 02 Источноевропско време (Египат) (секунд: 14) – 1982. н. е. (дан: уторак 04.) 12 Источноевропско време (Египат) (секунд: 45)"
}

pub fn format_range_generic_zone_name_uses_later_overlap_offset_vi_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1985-10-27T09:37:41Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1988-05-18T07:02:09Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/Anchorage"),
      locale: option.Some("vi-VN"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_era(intldate.EraNarrow)
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthShort)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_second(intldate.SecondNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(False),
    )

  assert result
    == "01:37:41 Giờ Alaska (Anchorage) 27 thg 10, 85 CN – 23:02:09 Giờ Alaska 17 thg 5, 88 CN"
}

pub fn format_range_japanese_day_only_expands_era_year_and_month_ko_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2018-10-29T06:55:58Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2021-08-23T00:16:22Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Pacific/Marquesas"),
      locale: option.Some("ko-KR"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarJapanese)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_hour12(True),
    )

  assert result == "H 30년 10월 28일 ~ R 3년 8월 22일"
}

pub fn format_range_japanese_day_only_expands_era_year_and_month_de_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2018-12-05T00:00:00Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2020-12-14T00:00:00Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Antarctica/Troll"),
      locale: option.Some("de-AT"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
        |> intldate.with_calendar(intldate.CalendarJapanese)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic),
    )

  assert result == "Heisei 30-12-05 – Reiwa 2-12-14"
}

pub fn format_range_japanese_explicit_month_does_not_add_era_or_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2018-08-22T19:03:53Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2020-11-26T02:52:23Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Pacific/Chatham"),
      locale: option.Some("pl-PL"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
        |> intldate.with_calendar(intldate.CalendarJapanese)
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
        |> intldate.with_hour12(True),
    )

  assert result == "czw., 23 sierpnia – czw., 26 listopada"
}

pub fn format_range_to_parts_japanese_default_cross_era_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1988-12-12T10:13:17Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1991-09-27T04:46:42Z")
  let config =
    intldate.new()
    |> intldate.with_calendar(intldate.CalendarJapanese)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Asia/Kolkata"),
      locale: option.Some("en-AU"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartEra)
    == [
      #("S", intldate.DateTimePartSourceStartRange),
      #("H", intldate.DateTimePartSourceEndRange),
    ]
  assert parts |> list.map(fn(part) { part.value }) |> string.concat
    == "12/12/63 S – 27/09/3 H"
}

pub fn format_range_chinese_adds_month_without_losing_cyclic_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1976-06-25T15:56:00Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1976-12-10T22:05:00Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Africa/Casablanca"),
      locale: option.Some("id-ID"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_era(intldate.EraNarrow)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit),
    )

  assert result == "J, bing-chen 5 28, 16.56 – J, bing-chen 10 20, 22.05"
}

pub fn format_range_chinese_time_only_uses_numeric_date_fallback_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1972-05-16T08:42:08Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1972-10-12T03:17:08Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/Chicago"),
      locale: option.Some("id-ID"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_hour12(True),
    )

  assert result == "49-4-4, 3 AM – 49-9-5, 10 PM"
}

pub fn format_range_indonesian_chinese_missing_month_keeps_numeric_width_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1989-03-17T14:26:55Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1990-08-31T15:20:30Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("id-ID"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.Hour2Digit)
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
        |> intldate.with_hour12(True),
    )

  assert result == "ji-si 02-10, 9 AM – geng-wu 07-12, 11 AM"
}

pub fn format_range_indonesian_chinese_without_year_keeps_related_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1991-11-18T00:05:23Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1994-01-14T18:08:04Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Antarctica/Troll"),
      locale: option.Some("id-ID"),
      config: intldate.new()
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_day(intldate.Day2Digit)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
        |> intldate.with_hour12(True),
    )

  assert result == "1991-10-13, Sen, 12 AM – 1993-12-03, Jum, 6 PM"
}

pub fn format_range_mongolian_chinese_uses_interval_grammar_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1984-10-22T14:42:06Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1985-09-18T11:38:38Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Asia/Tehran"),
      locale: option.Some("mn-MN"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_calendar(intldate.CalendarChinese)
        |> intldate.with_weekday(intldate.WeekdayNarrow)
        |> intldate.with_year(intldate.Year2Digit)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric)
        |> intldate.with_second(intldate.SecondNumeric)
        |> intldate.with_time_zone_name(intldate.TimeZoneNameLong)
        |> intldate.with_format_matcher(intldate.FormatMatcherBasic),
    )

  assert result
    == "1984(jia-zi) оны 9-р сар сарын 28, Да 18:12:06 (Ираны стандарт цаг) – 1985(yi-chou) оны 8-р сар сарын 4, Лх 15:08:38 (Ираны стандарт цаг)"
}

pub fn format_range_mongolian_dangi_uses_interval_grammar_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2021-12-24T09:26:45Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2023-08-31T01:13:42Z")

  let result =
    intldate.format_range(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/New_York"),
      locale: option.Some("mn-MN"),
      config: intldate.new()
        |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
        |> intldate.with_calendar(intldate.CalendarDangi)
        |> intldate.with_weekday(intldate.WeekdayShort)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.Minute2Digit)
        |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)
        |> intldate.with_hour12(True),
    )

  assert result
    == "2021(xin-chou) оны 11-р сар сарын 21, Ба 4:26 ү.ө. – 2023(gui-mao) оны 7-р сар сарын 15, Лх 9:13 ү.х."
}

fn values_and_sources(
  parts: List(intldate.DateTimeFormatPart),
  kind: intldate.DateTimePartKind,
) -> List(#(String, intldate.DateTimePartSource)) {
  list.filter_map(parts, fn(part) {
    case part.kind == kind {
      True -> Ok(#(part.value, part.source))
      False -> Error(Nil)
    }
  })
}

pub fn format_range_to_parts_indonesian_dangi_uses_cyclic_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1984-08-17T00:54:20Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1984-10-21T14:14:54Z")
  let config =
    intldate.new()
    |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
    |> intldate.with_calendar(intldate.CalendarDangi)
    |> intldate.with_weekday(intldate.WeekdayShort)
    |> intldate.with_era(intldate.EraLong)
    |> intldate.with_year(intldate.YearNumeric)
    |> intldate.with_day(intldate.DayNumeric)
    |> intldate.with_hour(intldate.HourNumeric)
    |> intldate.with_minute(intldate.Minute2Digit)
    |> intldate.with_time_zone_name(intldate.TimeZoneNameShortOffset)
    |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
    |> intldate.with_hour12(True)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Asia/Tehran"),
      locale: option.Some("id-ID"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartRelatedYear) == []
  assert values_and_sources(parts, intldate.DateTimePartYearName)
    == [
      #("jia-zi", intldate.DateTimePartSourceStartRange),
      #("jia-zi", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth)
    == [
      #("7", intldate.DateTimePartSourceStartRange),
      #("9", intldate.DateTimePartSourceEndRange),
    ]
}

pub fn format_range_to_parts_chinese_with_seconds_keeps_related_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2023-08-27T18:19:14Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2023-10-01T08:05:09Z")
  let config =
    intldate.new()
    |> intldate.with_calendar(intldate.CalendarChinese)
    |> intldate.with_year(intldate.YearNumeric)
    |> intldate.with_day(intldate.DayNumeric)
    |> intldate.with_hour(intldate.HourNumeric)
    |> intldate.with_minute(intldate.Minute2Digit)
    |> intldate.with_second(intldate.SecondNumeric)
    |> intldate.with_time_zone_name(intldate.TimeZoneNameLongOffset)
    |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Africa/Johannesburg"),
      locale: option.Some("id-ID"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartRelatedYear)
    == [
      #("2023", intldate.DateTimePartSourceStartRange),
      #("2023", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartYearName)
    == [
      #("gui-mao", intldate.DateTimePartSourceStartRange),
      #("gui-mao", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth) == []
  assert values_and_sources(parts, intldate.DateTimePartDay)
    == [
      #("12", intldate.DateTimePartSourceStartRange),
      #("17", intldate.DateTimePartSourceEndRange),
    ]
}

pub fn format_range_to_parts_non_gregorian_flexible_day_period_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1997-08-28T17:01:50Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1997-08-29T10:04:27Z")
  let config =
    intldate.new()
    |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
    |> intldate.with_calendar(intldate.CalendarRoc)
    |> intldate.with_weekday(intldate.WeekdayNarrow)
    |> intldate.with_hour(intldate.HourNumeric)
    |> intldate.with_minute(intldate.Minute2Digit)
    |> intldate.with_format_matcher(intldate.FormatMatcherBasic)
    |> intldate.with_hour12(True)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Australia/Sydney"),
      locale: option.Some("zh-TW"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartDayPeriod)
    == [
      #("凌晨", intldate.DateTimePartSourceStartRange),
      #("晚上", intldate.DateTimePartSourceEndRange),
    ]
}

pub fn format_range_to_parts_japanese_expansion_sources_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2018-12-05T00:00:00Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2020-12-14T00:00:00Z")
  let config =
    intldate.new()
    |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
    |> intldate.with_calendar(intldate.CalendarJapanese)
    |> intldate.with_day(intldate.Day2Digit)
    |> intldate.with_format_matcher(intldate.FormatMatcherBasic)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Antarctica/Troll"),
      locale: option.Some("de-AT"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartEra)
    == [
      #("Heisei", intldate.DateTimePartSourceStartRange),
      #("Reiwa", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartYear)
    == [
      #("30", intldate.DateTimePartSourceStartRange),
      #("2", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth)
    == [
      #("12", intldate.DateTimePartSourceStartRange),
      #("12", intldate.DateTimePartSourceEndRange),
    ]
}

pub fn format_range_to_parts_persian_text_months_are_shared_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2019-08-06T07:04:19Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2019-09-10T15:47:08Z")
  let config =
    intldate.new()
    |> intldate.with_locale_matcher(intldate.LocaleMatcherLookup)
    |> intldate.with_weekday(intldate.WeekdayNarrow)
    |> intldate.with_year(intldate.YearNumeric)
    |> intldate.with_month(intldate.MonthShort)
    |> intldate.with_day(intldate.Day2Digit)
    |> intldate.with_hour12(True)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("America/Sao_Paulo"),
      locale: option.Some("fa-IR"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartDay)
    == [
      #("۱۵", intldate.DateTimePartSourceStartRange),
      #("۱۹", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth)
    == [
      #("مرداد", intldate.DateTimePartSourceShared),
      #("شهریور", intldate.DateTimePartSourceShared),
    ]
  assert values_and_sources(parts, intldate.DateTimePartYear)
    == [#("۱۳۹۸", intldate.DateTimePartSourceShared)]
  assert values_and_sources(parts, intldate.DateTimePartLiteral)
    == [
      #(" ", intldate.DateTimePartSourceStartRange),
      #(" ", intldate.DateTimePartSourceShared),
      #(" تا ", intldate.DateTimePartSourceShared),
      #(" ", intldate.DateTimePartSourceEndRange),
      #(" ", intldate.DateTimePartSourceShared),
      #(" ", intldate.DateTimePartSourceShared),
    ]
}

pub fn format_range_to_parts_chinese_cyclic_year_sources_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("1976-06-25T15:56:00Z")
  let assert Ok(end) = timestamp.parse_rfc3339("1976-12-10T22:05:00Z")
  let config =
    intldate.new()
    |> intldate.with_locale_matcher(intldate.LocaleMatcherBestFit)
    |> intldate.with_calendar(intldate.CalendarChinese)
    |> intldate.with_weekday(intldate.WeekdayNarrow)
    |> intldate.with_era(intldate.EraNarrow)
    |> intldate.with_year(intldate.YearNumeric)
    |> intldate.with_day(intldate.DayNumeric)
    |> intldate.with_hour(intldate.HourNumeric)
    |> intldate.with_minute(intldate.Minute2Digit)
    |> intldate.with_format_matcher(intldate.FormatMatcherBestFit)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Africa/Casablanca"),
      locale: option.Some("id-ID"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartRelatedYear) == []
  assert values_and_sources(parts, intldate.DateTimePartYearName)
    == [
      #("bing-chen", intldate.DateTimePartSourceStartRange),
      #("bing-chen", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth)
    == [
      #("5", intldate.DateTimePartSourceStartRange),
      #("10", intldate.DateTimePartSourceEndRange),
    ]
}

pub fn format_range_to_parts_chinese_missing_month_cross_year_test() {
  let assert Ok(start) = timestamp.parse_rfc3339("2022-03-06T14:37:11Z")
  let assert Ok(end) = timestamp.parse_rfc3339("2025-01-03T08:03:12Z")
  let config =
    intldate.new()
    |> intldate.with_calendar(intldate.CalendarChinese)
    |> intldate.with_weekday(intldate.WeekdayNarrow)
    |> intldate.with_year(intldate.Year2Digit)
    |> intldate.with_day(intldate.DayNumeric)
    |> intldate.with_hour(intldate.Hour2Digit)
    |> intldate.with_time_zone_name(intldate.TimeZoneNameLongGeneric)
    |> intldate.with_hour12(False)

  let parts =
    intldate.format_range_to_parts(
      date_start: start,
      date_end: end,
      time_zone: option.Some("Europe/London"),
      locale: option.Some("id-ID"),
      config:,
    )

  assert values_and_sources(parts, intldate.DateTimePartRelatedYear) == []
  assert values_and_sources(parts, intldate.DateTimePartYearName)
    == [
      #("ren-yin", intldate.DateTimePartSourceStartRange),
      #("jia-chen", intldate.DateTimePartSourceEndRange),
    ]
  assert values_and_sources(parts, intldate.DateTimePartMonth)
    == [
      #("2", intldate.DateTimePartSourceStartRange),
      #("12", intldate.DateTimePartSourceEndRange),
    ]
  assert parts |> list.map(fn(part) { part.value }) |> string.concat
    == "M, ren-yin 2 4, 14 Waktu Inggris Raya – J, jia-chen 12 4, 08 Waktu Inggris Raya"
}
