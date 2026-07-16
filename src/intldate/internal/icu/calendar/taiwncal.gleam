import gleam/option.{None}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/bundle.{type Bundle}

const taiwan_era_start = 1911

pub fn compute_roc_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let f =
    gregocal.compute_fields(
      bundle,
      locale_id,
      epoch_millis,
      zone_offset_millis,
      None,
    )
  let y = f.extended_year - taiwan_era_start
  case y > 0 {
    True -> gregocal.CalendarFields(..f, era: 1, year: y)
    False -> gregocal.CalendarFields(..f, era: 0, year: 1 - y)
  }
}
