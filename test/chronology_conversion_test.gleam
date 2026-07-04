import intldate/internal/chronology

pub fn convert_gregory_test() {
  let result = chronology.convert(chronology.CalendarGregory, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2026,
      month: 2,
      day: 24,
      era_index: 1,
      related_year: 2026,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_iso8601_test() {
  let result = chronology.convert(chronology.CalendarIso8601, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2026,
      month: 2,
      day: 24,
      era_index: 1,
      related_year: 2026,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_buddhist_test() {
  let result = chronology.convert(chronology.CalendarBuddhist, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2569,
      month: 2,
      day: 24,
      era_index: 1,
      related_year: 2569,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_roc_after_1911_test() {
  let result = chronology.convert(chronology.CalendarRoc, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 115,
      month: 2,
      day: 24,
      era_index: 1,
      related_year: 115,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_roc_before_1912_test() {
  let result = chronology.convert(chronology.CalendarRoc, 1900, 3, 15)
  assert result
    == chronology.Converted(
      year: 12,
      month: 3,
      day: 15,
      era_index: 0,
      related_year: 12,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_reiwa_first_day_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 2019, 5, 1)
  assert result
    == chronology.Converted(
      year: 1,
      month: 5,
      day: 1,
      era_index: 236,
      related_year: 1,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_reiwa_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 8,
      month: 2,
      day: 24,
      era_index: 236,
      related_year: 8,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_heisei_first_day_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1989, 1, 8)
  assert result
    == chronology.Converted(
      year: 1,
      month: 1,
      day: 8,
      era_index: 235,
      related_year: 1,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_heisei_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 2000, 6, 15)
  assert result
    == chronology.Converted(
      year: 12,
      month: 6,
      day: 15,
      era_index: 235,
      related_year: 12,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_last_day_of_showa_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1989, 1, 7)
  assert result
    == chronology.Converted(
      year: 64,
      month: 1,
      day: 7,
      era_index: 234,
      related_year: 64,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_showa_first_day_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1926, 12, 25)
  assert result
    == chronology.Converted(
      year: 1,
      month: 12,
      day: 25,
      era_index: 234,
      related_year: 1,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_showa_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1980, 3, 10)
  assert result
    == chronology.Converted(
      year: 55,
      month: 3,
      day: 10,
      era_index: 234,
      related_year: 55,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_taisho_first_day_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1912, 7, 30)
  assert result
    == chronology.Converted(
      year: 1,
      month: 7,
      day: 30,
      era_index: 233,
      related_year: 1,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_taisho_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1920, 8, 1)
  assert result
    == chronology.Converted(
      year: 9,
      month: 8,
      day: 1,
      era_index: 233,
      related_year: 9,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_meiji_first_day_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1868, 10, 23)
  assert result
    == chronology.Converted(
      year: 1,
      month: 10,
      day: 23,
      era_index: 232,
      related_year: 1,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_meiji_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1900, 1, 1)
  assert result
    == chronology.Converted(
      year: 33,
      month: 1,
      day: 1,
      era_index: 232,
      related_year: 33,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_japanese_before_known_eras_test() {
  let result = chronology.convert(chronology.CalendarJapanese, 1800, 1, 1)
  assert result
    == chronology.Converted(
      year: 1800,
      month: 1,
      day: 1,
      era_index: 0,
      related_year: 1800,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_coptic_test() {
  let result = chronology.convert(chronology.CalendarCoptic, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1742,
      month: 6,
      day: 17,
      era_index: 1,
      related_year: 1742,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_ethiopic_test() {
  let result = chronology.convert(chronology.CalendarEthiopic, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2018,
      month: 6,
      day: 17,
      era_index: 0,
      related_year: 2018,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_ethioaa_test() {
  let result = chronology.convert(chronology.CalendarEthioaa, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 7518,
      month: 6,
      day: 17,
      era_index: 0,
      related_year: 7518,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_indian_before_new_year_test() {
  let result = chronology.convert(chronology.CalendarIndian, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1947,
      month: 12,
      day: 5,
      era_index: 0,
      related_year: 1947,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_indian_after_new_year_test() {
  let result = chronology.convert(chronology.CalendarIndian, 2026, 4, 1)
  assert result
    == chronology.Converted(
      year: 1948,
      month: 1,
      day: 11,
      era_index: 0,
      related_year: 1948,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_persian_test() {
  let result = chronology.convert(chronology.CalendarPersian, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1404,
      month: 12,
      day: 5,
      era_index: 0,
      related_year: 1404,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_hebrew_non_leap_year_test() {
  let result = chronology.convert(chronology.CalendarHebrew, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 5786,
      month: 7,
      day: 7,
      era_index: 0,
      related_year: 5786,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_islamic_test() {
  let result = chronology.convert(chronology.CalendarIslamic, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1447,
      month: 9,
      day: 7,
      era_index: 0,
      related_year: 1447,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_islamic_umalqura_test() {
  let result =
    chronology.convert(chronology.CalendarIslamicUmalqura, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1447,
      month: 9,
      day: 7,
      era_index: 0,
      related_year: 1447,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_islamic_civil_test() {
  let result = chronology.convert(chronology.CalendarIslamicCivil, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1447,
      month: 9,
      day: 7,
      era_index: 0,
      related_year: 1447,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_islamic_rgsa_test() {
  let result = chronology.convert(chronology.CalendarIslamicRgsa, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1447,
      month: 9,
      day: 7,
      era_index: 0,
      related_year: 1447,
      year_name_index: 0,
      is_leap_month: False,
    )
}

pub fn convert_islamic_tbla_test() {
  let result = chronology.convert(chronology.CalendarIslamicTbla, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 1447,
      month: 9,
      day: 8,
      era_index: 0,
      related_year: 1447,
      year_name_index: 0,
      is_leap_month: False,
    )
}

@external(javascript, "./chronology_conversion_test.ffi.mjs", "noop")
pub fn convert_chinese_test() -> Nil {
  let result = chronology.convert(chronology.CalendarChinese, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2026,
      month: 1,
      day: 8,
      era_index: 0,
      related_year: 2026,
      year_name_index: 43,
      is_leap_month: False,
    )
}

@external(javascript, "./chronology_conversion_test.ffi.mjs", "noop")
pub fn convert_dangi_test() -> Nil {
  let result = chronology.convert(chronology.CalendarDangi, 2026, 2, 24)
  assert result
    == chronology.Converted(
      year: 2026,
      month: 1,
      day: 8,
      era_index: 0,
      related_year: 2026,
      year_name_index: 43,
      is_leap_month: False,
    )
}
