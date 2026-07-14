import gleam/float
import gleam/int
import gleam/option.{None}
import intldate/internal/icu/calendar/astro
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/math

pub type MonthInfo {
  MonthInfo(month: Int, ordinal_month: Int, this_moon: Int, is_leap_month: Bool)
}

const millis_per_day = 86_400_000

const chinese_epoch_year = 1

const cycle_epoch = -2636

const synodic_gap = 25

const china_offset = 28_800_000

fn china_offset_fn(_millis: Int) -> Int {
  china_offset
}

fn days_to_millis(offset_fn: fn(Int) -> Int, days: Int) -> Int {
  let millis = days * millis_per_day
  millis - offset_fn(millis)
}

fn millis_to_days(offset_fn: fn(Int) -> Int, millis: Int) -> Int {
  math.floor_div(millis + offset_fn(millis), millis_per_day)
}

fn winter_solstice(offset_fn: fn(Int) -> Int, gyear: Int) -> Int {
  let ms = days_to_millis(offset_fn, gregoimp.fields_to_day(gyear, 11, 1))
  let solstice_millis =
    astro.get_sun_time(
      astro.create_calendar_astronomer(int.to_float(ms)),
      astro.winter_solstice(),
      True,
    )
  millis_to_days(offset_fn, math.floor_float(solstice_millis))
}

fn new_moon_near(offset_fn: fn(Int) -> Int, days: Int, after: Bool) -> Int {
  let ms = days_to_millis(offset_fn, days)
  let moon_millis =
    astro.get_moon_time(
      astro.create_calendar_astronomer(int.to_float(ms)),
      astro.new_moon,
      after,
    )
  millis_to_days(offset_fn, math.floor_float(moon_millis))
}

fn synodic_months_between(day1: Int, day2: Int) -> Int {
  let roundme = int.to_float(day2 - day1) /. astro.synodic_month
  let adjust = case roundme >=. 0.0 {
    True -> 0.5
    False -> -0.5
  }
  float.truncate(roundme +. adjust)
}

fn major_solar_term(offset_fn: fn(Int) -> Int, days: Int) -> Int {
  let ms = days_to_millis(offset_fn, days)
  let longitude =
    astro.get_sun_longitude(astro.create_calendar_astronomer(int.to_float(ms)))
  let term = { math.floor_float({ 6.0 *. longitude } /. math.pi()) + 2 } % 12
  case term < 1 {
    True -> term + 12
    False -> term
  }
}

fn has_no_major_solar_term(offset_fn: fn(Int) -> Int, new_moon: Int) -> Bool {
  let term1 = major_solar_term(offset_fn, new_moon)
  let term2 =
    major_solar_term(
      offset_fn,
      new_moon_near(offset_fn, new_moon + synodic_gap, True),
    )
  term1 == term2
}

fn is_leap_month_between(
  offset_fn: fn(Int) -> Int,
  new_moon1: Int,
  new_moon2: Int,
) -> Bool {
  case new_moon2 >= new_moon1 {
    False -> False
    True ->
      case has_no_major_solar_term(offset_fn, new_moon2) {
        True -> True
        False ->
          is_leap_month_between(
            offset_fn,
            new_moon1,
            new_moon_near(offset_fn, new_moon2 - synodic_gap, False),
          )
      }
  }
}

fn new_year(offset_fn: fn(Int) -> Int, gyear: Int) -> Int {
  let solstice_before = winter_solstice(offset_fn, gyear - 1)
  let solstice_after = winter_solstice(offset_fn, gyear)
  let new_moon1 = new_moon_near(offset_fn, solstice_before + 1, True)
  let new_moon2 = new_moon_near(offset_fn, new_moon1 + synodic_gap, True)
  let new_moon11 = new_moon_near(offset_fn, solstice_after + 1, False)

  case
    synodic_months_between(new_moon1, new_moon11) == 12
    && {
      has_no_major_solar_term(offset_fn, new_moon1)
      || has_no_major_solar_term(offset_fn, new_moon2)
    }
  {
    True -> new_moon_near(offset_fn, new_moon2 + synodic_gap, True)
    False -> new_moon2
  }
}

fn compute_month_info(
  offset_fn: fn(Int) -> Int,
  gyear: Int,
  days: Int,
) -> MonthInfo {
  let solstice_after_0 = winter_solstice(offset_fn, gyear)
  let #(solstice_before, solstice_after) = case days < solstice_after_0 {
    True -> #(winter_solstice(offset_fn, gyear - 1), solstice_after_0)
    False -> #(solstice_after_0, winter_solstice(offset_fn, gyear + 1))
  }

  let first_moon = new_moon_near(offset_fn, solstice_before + 1, True)
  let last_moon = new_moon_near(offset_fn, solstice_after + 1, False)
  let this_moon = new_moon_near(offset_fn, days + 1, False)
  let has_leap_month_between_winter_solstices =
    synodic_months_between(first_moon, last_moon) == 12

  let month0 = synodic_months_between(first_moon, this_moon)

  let the_new_year_0 = new_year(offset_fn, gyear)
  let the_new_year = case days < the_new_year_0 {
    True -> new_year(offset_fn, gyear - 1)
    False -> the_new_year_0
  }

  let month1 = case
    has_leap_month_between_winter_solstices
    && is_leap_month_between(offset_fn, first_moon, this_moon)
  {
    True -> month0 - 1
    False -> month0
  }
  let month = case month1 < 1 {
    True -> month1 + 12
    False -> month1
  }

  let ordinal_month0 = synodic_months_between(the_new_year, this_moon)
  let ordinal_month = case ordinal_month0 < 0 {
    True -> ordinal_month0 + 12
    False -> ordinal_month0
  }

  let is_leap_month =
    has_leap_month_between_winter_solstices
    && has_no_major_solar_term(offset_fn, this_moon)
    && !is_leap_month_between(
      offset_fn,
      first_moon,
      new_moon_near(offset_fn, this_moon - synodic_gap, False),
    )

  MonthInfo(month:, ordinal_month:, this_moon:, is_leap_month:)
}

pub fn chinese_year_length(offset_fn: fn(Int) -> Int) -> fn(Int) -> Int {
  fn(ext_year: Int) {
    new_year(offset_fn, ext_year + 1) - new_year(offset_fn, ext_year)
  }
}

pub fn compute_chinese_fields_with_offset(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
  offset_fn: fn(Int) -> Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let days = math.floor_div(local_millis, millis_per_day)

  let time_fields = gregoimp.time_to_fields(local_millis)
  let gyear = time_fields.year
  let gmonth = time_fields.month
  let dow = time_fields.dow
  let millis_in_day = time_fields.millis_in_day

  let info = compute_month_info(offset_fn, gyear, days)

  let eyear0 = gyear - chinese_epoch_year
  let cycle_year0 = gyear - cycle_epoch
  let #(eyear, cycle_year) = case info.month < 11 || gmonth >= 6 {
    True -> #(eyear0 + 1, cycle_year0 + 1)
    False -> #(eyear0, cycle_year0)
  }

  let day_of_month = days - info.this_moon + 1

  let #(cycle0, year_of_cycle0) = math.floor_div_rem(cycle_year - 1, 60)

  let the_new_year_0 = new_year(offset_fn, gyear)
  let the_new_year = case days < the_new_year_0 {
    True -> new_year(offset_fn, gyear - 1)
    False -> the_new_year_0
  }
  let cycle = cycle0 + 1
  let year_of_cycle = year_of_cycle0 + 1
  let day_of_year = days - the_new_year + 1

  let month = info.month - 1
  let year_length_fn = chinese_year_length(offset_fn)

  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      eyear,
      month,
      day_of_month,
      dow,
      day_of_year,
      millis_in_day,
      year_length_fn,
      None,
    )

  gregocal.CalendarFields(
    era: cycle,
    year: year_of_cycle,
    extended_year: eyear,
    common: gregocal.CommonFields(
      ..common,
      month:,
      day_of_month:,
      day_of_year:,
      is_leap_month: info.is_leap_month,
    ),
  )
}

pub fn compute_chinese_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_chinese_fields_with_offset(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    china_offset_fn,
  )
}
