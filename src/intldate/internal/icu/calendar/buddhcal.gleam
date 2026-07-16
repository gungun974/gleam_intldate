import gleam/option.{None}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/bundle.{type Bundle}

const buddhist_era_start = -543

pub fn compute_buddhist_fields(
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
  gregocal.CalendarFields(
    ..f,
    era: 0,
    year: f.extended_year - buddhist_era_start,
  )
}
