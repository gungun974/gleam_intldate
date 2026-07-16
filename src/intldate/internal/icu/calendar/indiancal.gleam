import gleam/option.{None}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/math

const millis_per_day = 86_400_000

const indian_era_start = 78

const indian_year_start = 80

pub fn compute_indian_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let time_fields = gregoimp.time_to_fields(local_millis)
  let gregorian_year = time_fields.year

  let jd_at_start_of_greg_year = gregoimp.fields_to_day(gregorian_year, 0, 1)
  let yday0 = day - jd_at_start_of_greg_year

  let #(indian_year0, leap_month, yday) = case yday0 < indian_year_start {
    True -> {
      let leap_month = case gregoimp.is_leap_year(gregorian_year - 1) {
        True -> 31
        False -> 30
      }
      #(
        gregorian_year - indian_era_start - 1,
        leap_month,
        yday0 + leap_month + 31 * 5 + 30 * 3 + 10,
      )
    }
    False -> {
      let leap_month = case gregoimp.is_leap_year(gregorian_year) {
        True -> 31
        False -> 30
      }
      #(
        gregorian_year - indian_era_start,
        leap_month,
        yday0 - indian_year_start,
      )
    }
  }

  let #(indian_month, indian_day_of_month) = case yday < leap_month {
    True -> #(0, yday + 1)
    False -> {
      let mday = yday - leap_month
      case mday < 31 * 5 {
        True -> #(mday / 31 + 1, mday % 31 + 1)
        False -> {
          let mday2 = mday - 31 * 5
          #(mday2 / 30 + 6, mday2 % 30 + 1)
        }
      }
    }
  }

  let doy = yday + 1

  let year_length = fn(y: Int) -> Int {
    case gregoimp.is_leap_year(y + indian_era_start) {
      True -> 366
      False -> 365
    }
  }

  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      indian_year0,
      indian_month,
      indian_day_of_month,
      time_fields.dow,
      doy,
      time_fields.millis_in_day,
      year_length,
      None,
    )

  gregocal.CalendarFields(
    era: 0,
    year: indian_year0,
    extended_year: indian_year0,
    common: gregocal.CommonFields(
      ..common,
      day_of_month: indian_day_of_month,
      day_of_year: doy,
    ),
  )
}
