import gleam/option.{None}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/math

pub type EraYear {
  EraYear(era: Int, year: Int)
}

pub type JdToCeResult {
  JdToCeResult(year: Int, month: Int, day: Int, doy: Int)
}

const millis_per_day = 86_400_000

const julian_1970_ce = 2_440_588

pub fn jd_to_ce(julian_day: Int, jd_epoch_offset: Int) -> JdToCeResult {
  let j = julian_day - jd_epoch_offset
  let #(c4, r4) = math.floor_div_rem(j, 1461)
  let year = 4 * c4 + { math.floor_div(r4, 365) - math.floor_div(r4, 1460) }
  let doy = case r4 == 1460 {
    True -> 365
    False -> r4 % 365
  }
  let month = math.floor_div(doy, 30)
  let day = { doy % 30 } + 1
  JdToCeResult(year:, month:, day:, doy: doy + 1)
}

pub fn ce_year_length(year: Int) -> Int {
  case { { year % 4 } + 4 } % 4 == 3 {
    True -> 366
    False -> 365
  }
}

pub fn compute_ce_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
  jd_epoch_offset: Int,
  extended_year_to_era_year: fn(Int) -> EraYear,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let ce = jd_to_ce(julian_day, jd_epoch_offset)
  let era_year = extended_year_to_era_year(ce.year)

  let time_fields = gregoimp.time_to_fields(local_millis)

  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      ce.year,
      ce.month,
      ce.day,
      time_fields.dow,
      ce.doy,
      time_fields.millis_in_day,
      ce_year_length,
      None,
    )

  gregocal.CalendarFields(
    era: era_year.era,
    year: era_year.year,
    extended_year: ce.year,
    common: gregocal.CommonFields(
      ..common,
      day_of_month: ce.day,
      day_of_year: ce.doy,
    ),
  )
}

const coptic_jd_epoch_offset = 1_824_665

pub fn coptic_era_year(ext_year: Int) -> EraYear {
  case ext_year <= 0 {
    True -> EraYear(era: 0, year: 1 - ext_year)
    False -> EraYear(era: 1, year: ext_year)
  }
}

pub fn compute_coptic_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_ce_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    coptic_jd_epoch_offset,
    coptic_era_year,
  )
}

const jd_epoch_offset_amete_alem = -285_019

const jd_epoch_offset_amete_mihret = 1_723_856

const amete_mihret_delta = 5500

pub fn ethiopic_era_year(ext_year: Int) -> EraYear {
  case ext_year <= 0 {
    True -> EraYear(era: 0, year: ext_year + amete_mihret_delta)
    False -> EraYear(era: 1, year: ext_year)
  }
}

pub fn compute_ethiopic_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_ce_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    jd_epoch_offset_amete_mihret,
    ethiopic_era_year,
  )
}

pub fn ethiopic_amete_alem_era_year(ext_year: Int) -> EraYear {
  EraYear(era: 0, year: ext_year)
}

pub fn compute_ethiopic_amete_alem_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_ce_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    jd_epoch_offset_amete_alem,
    ethiopic_amete_alem_era_year,
  )
}
