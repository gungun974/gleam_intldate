import gleam/option.{None}
import intldate/internal/icu/calendar/buddhcal
import intldate/internal/icu/calendar/chnsecal
import intldate/internal/icu/calendar/coptccal
import intldate/internal/icu/calendar/dangical
import intldate/internal/icu/calendar/gregocal.{type CalendarFields}
import intldate/internal/icu/calendar/hebrwcal
import intldate/internal/icu/calendar/indiancal
import intldate/internal/icu/calendar/islamcal
import intldate/internal/icu/calendar/iso8601cal
import intldate/internal/icu/calendar/japancal
import intldate/internal/icu/calendar/persncal
import intldate/internal/icu/calendar/taiwncal
import intldate/internal/icu/icudata/bundle.{type Bundle}

pub fn compute_fields_for_calendar(
  cal_type: String,
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> CalendarFields {
  case cal_type {
    "gregorian" | "gregory" ->
      gregocal.compute_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
        None,
      )
    "buddhist" ->
      buddhcal.compute_buddhist_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "roc" ->
      taiwncal.compute_roc_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "iso8601" ->
      iso8601cal.compute_iso8601_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "japanese" ->
      japancal.compute_japanese_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "coptic" ->
      coptccal.compute_coptic_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "ethiopic" ->
      coptccal.compute_ethiopic_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "ethiopic-amete-alem" ->
      coptccal.compute_ethiopic_amete_alem_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "indian" ->
      indiancal.compute_indian_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "persian" ->
      persncal.compute_persian_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "islamic-civil" ->
      islamcal.compute_islamic_civil_calendar_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "islamic-tbla" ->
      islamcal.compute_islamic_tbla_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "hebrew" ->
      hebrwcal.compute_hebrew_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "islamic-umalqura" ->
      islamcal.compute_islamic_umalqura_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "islamic" | "islamic-rgsa" ->
      islamcal.compute_islamic_astro_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "chinese" ->
      chnsecal.compute_chinese_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    "dangi" ->
      dangical.compute_dangi_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    _ ->
      gregocal.compute_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
        None,
      )
  }
}
