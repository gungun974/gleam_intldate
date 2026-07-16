import gleam/option.{None}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/math

pub type PersianMonth {
  Farvardin
  Ordibehesht
  Khordad
  Tir
  Mordad
  Shahrivar
  Mehr
  Aban
  Azar
  Dey
  Bahman
  Esfand
}

const millis_per_day = 86_400_000

const julian_1970_ce = 2_440_588

const persian_epoch = 1_948_320

const min_correction = 1502

fn is_non_leap_year(year: Int) -> Bool {
  case year {
    1502
    | 1601
    | 1634
    | 1667
    | 1700
    | 1733
    | 1766
    | 1799
    | 1832
    | 1865
    | 1898
    | 1931
    | 1964
    | 1997
    | 2030
    | 2059
    | 2063
    | 2096
    | 2129
    | 2158
    | 2162
    | 2191
    | 2195
    | 2224
    | 2228
    | 2257
    | 2261
    | 2290
    | 2294
    | 2323
    | 2327
    | 2356
    | 2360
    | 2389
    | 2393
    | 2422
    | 2426
    | 2455
    | 2459
    | 2488
    | 2492
    | 2521
    | 2525
    | 2554
    | 2558
    | 2587
    | 2591
    | 2620
    | 2624
    | 2653
    | 2657
    | 2686
    | 2690
    | 2719
    | 2723
    | 2748
    | 2752
    | 2756
    | 2781
    | 2785
    | 2789
    | 2818
    | 2822
    | 2847
    | 2851
    | 2855
    | 2880
    | 2884
    | 2888
    | 2913
    | 2917
    | 2921
    | 2946
    | 2950
    | 2954
    | 2979
    | 2983
    | 2987 -> True
    _ -> False
  }
}

fn month_from_int(month: Int) -> PersianMonth {
  case month {
    0 -> Farvardin
    1 -> Ordibehesht
    2 -> Khordad
    3 -> Tir
    4 -> Mordad
    5 -> Shahrivar
    6 -> Mehr
    7 -> Aban
    8 -> Azar
    9 -> Dey
    10 -> Bahman
    _ -> Esfand
  }
}

fn month_to_int(month: PersianMonth) -> Int {
  case month {
    Farvardin -> 0
    Ordibehesht -> 1
    Khordad -> 2
    Tir -> 3
    Mordad -> 4
    Shahrivar -> 5
    Mehr -> 6
    Aban -> 7
    Azar -> 8
    Dey -> 9
    Bahman -> 10
    Esfand -> 11
  }
}

fn persian_num_days_for(month: PersianMonth) -> Int {
  case month {
    Farvardin -> 0
    Ordibehesht -> 31
    Khordad -> 62
    Tir -> 93
    Mordad -> 124
    Shahrivar -> 155
    Mehr -> 186
    Aban -> 216
    Azar -> 246
    Dey -> 276
    Bahman -> 306
    Esfand -> 336
  }
}

pub fn is_persian_leap_year(year: Int) -> Bool {
  case year >= min_correction && is_non_leap_year(year) {
    True -> False
    False ->
      case year > min_correction && is_non_leap_year(year - 1) {
        True -> True
        False -> { { year * 25 + 11 } % 33 } < 8
      }
  }
}

pub fn first_julian_of_year(year: Int) -> Int {
  let julian_day0 = 365 * { year - 1 } + math.floor_div(8 * year + 21, 33)
  case year > min_correction && is_non_leap_year(year - 1) {
    True -> julian_day0 - 1
    False -> julian_day0
  }
}

pub fn compute_persian_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let time_fields = gregoimp.time_to_fields(local_millis)

  let days_since_epoch = julian_day - persian_epoch
  let year0 = math.floor_div(33 * days_since_epoch + 3, 12_053) + 1

  let farvardin1 = first_julian_of_year(year0)
  let day_of_year0 = days_since_epoch - farvardin1

  let #(year, day_of_year1) = case
    day_of_year0 == 365 && year0 >= min_correction && is_non_leap_year(year0)
  {
    True -> #(year0 + 1, 0)
    False -> #(year0, day_of_year0)
  }

  let month = case day_of_year1 < 216 {
    True -> month_from_int(math.floor_div(day_of_year1, 31))
    False -> month_from_int(math.floor_div(day_of_year1 - 6, 30))
  }
  let day_of_year = day_of_year1 + 1
  let day_of_month = day_of_year - persian_num_days_for(month)

  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      year,
      month_to_int(month),
      day_of_month,
      time_fields.dow,
      day_of_year,
      time_fields.millis_in_day,
      fn(y) {
        case is_persian_leap_year(y) {
          True -> 366
          False -> 365
        }
      },
      None,
    )

  gregocal.CalendarFields(
    era: 0,
    year:,
    extended_year: year,
    common: gregocal.CommonFields(..common, day_of_month:, day_of_year:),
  )
}
