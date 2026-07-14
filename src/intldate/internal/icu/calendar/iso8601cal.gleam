import gleam/option.{Some}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/locale/uloc

const ucal_monday = 2

pub fn get_iso8601_week_data(
  bundle: Bundle,
  locale_id: String,
) -> gregocal.WeekData {
  let has_fw = uloc.get_keyword_value(Some(locale_id), "fw") != ""
  let has_rg = uloc.get_keyword_value(Some(locale_id), "rg") != ""
  let first_day_of_week = case has_fw || has_rg {
    True -> gregocal.get_week_data(bundle, locale_id).first_day_of_week
    False -> ucal_monday
  }
  gregocal.WeekData(first_day_of_week:, minimal_days_in_first_week: 4)
}

pub fn compute_iso8601_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  gregocal.compute_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    Some(get_iso8601_week_data(bundle, locale_id)),
  )
}
