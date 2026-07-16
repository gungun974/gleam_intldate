import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/math

pub type YearType {
  Deficient
  Regular
  Complete
}

pub type HebrewMonth {
  Tishri
  Heshvan
  Kislev
  Tevet
  Shevat
  Adar1
  Adar2
  Nisan
  Iyar
  Sivan
  Tamuz
  Ab
  Elul
}

const millis_per_day = 86_400_000

const julian_1970_ce = 2_440_588

const hour_parts = 1080

const day_parts_value = 25_920

const month_days = 29

const month_fract_value = 13_753

const baharad_value = 12_084

const years_in_cycle = 19

fn month_parts() -> Int {
  month_days * day_parts_value + month_fract_value
}

fn next_month(month: HebrewMonth) -> Option(HebrewMonth) {
  case month {
    Tishri -> Some(Heshvan)
    Heshvan -> Some(Kislev)
    Kislev -> Some(Tevet)
    Tevet -> Some(Shevat)
    Shevat -> Some(Adar1)
    Adar1 -> Some(Adar2)
    Adar2 -> Some(Nisan)
    Nisan -> Some(Iyar)
    Iyar -> Some(Sivan)
    Sivan -> Some(Tamuz)
    Tamuz -> Some(Ab)
    Ab -> Some(Elul)
    Elul -> None
  }
}

fn month_to_int(month: HebrewMonth) -> Int {
  case month {
    Tishri -> 0
    Heshvan -> 1
    Kislev -> 2
    Tevet -> 3
    Shevat -> 4
    Adar1 -> 5
    Adar2 -> 6
    Nisan -> 7
    Iyar -> 8
    Sivan -> 9
    Tamuz -> 10
    Ab -> 11
    Elul -> 12
  }
}

fn month_start(month: HebrewMonth, type_: YearType) -> Int {
  case month, type_ {
    Tishri, _ -> 0
    Heshvan, _ -> 30
    Kislev, Deficient -> 59
    Kislev, Regular -> 59
    Kislev, Complete -> 60
    Tevet, Deficient -> 88
    Tevet, Regular -> 89
    Tevet, Complete -> 90
    Shevat, Deficient -> 117
    Shevat, Regular -> 118
    Shevat, Complete -> 119
    Adar1, Deficient -> 147
    Adar1, Regular -> 148
    Adar1, Complete -> 149
    Adar2, Deficient -> 147
    Adar2, Regular -> 148
    Adar2, Complete -> 149
    Nisan, Deficient -> 176
    Nisan, Regular -> 177
    Nisan, Complete -> 178
    Iyar, Deficient -> 206
    Iyar, Regular -> 207
    Iyar, Complete -> 208
    Sivan, Deficient -> 235
    Sivan, Regular -> 236
    Sivan, Complete -> 237
    Tamuz, Deficient -> 265
    Tamuz, Regular -> 266
    Tamuz, Complete -> 267
    Ab, Deficient -> 294
    Ab, Regular -> 295
    Ab, Complete -> 296
    Elul, Deficient -> 324
    Elul, Regular -> 325
    Elul, Complete -> 326
  }
}

fn leap_month_start(month: HebrewMonth, type_: YearType) -> Int {
  case month, type_ {
    Tishri, _ -> 0
    Heshvan, _ -> 30
    Kislev, Deficient -> 59
    Kislev, Regular -> 59
    Kislev, Complete -> 60
    Tevet, Deficient -> 88
    Tevet, Regular -> 89
    Tevet, Complete -> 90
    Shevat, Deficient -> 117
    Shevat, Regular -> 118
    Shevat, Complete -> 119
    Adar1, Deficient -> 147
    Adar1, Regular -> 148
    Adar1, Complete -> 149
    Adar2, Deficient -> 177
    Adar2, Regular -> 178
    Adar2, Complete -> 179
    Nisan, Deficient -> 206
    Nisan, Regular -> 207
    Nisan, Complete -> 208
    Iyar, Deficient -> 236
    Iyar, Regular -> 237
    Iyar, Complete -> 238
    Sivan, Deficient -> 265
    Sivan, Regular -> 266
    Sivan, Complete -> 267
    Tamuz, Deficient -> 295
    Tamuz, Regular -> 296
    Tamuz, Complete -> 297
    Ab, Deficient -> 324
    Ab, Regular -> 325
    Ab, Complete -> 326
    Elul, Deficient -> 354
    Elul, Regular -> 355
    Elul, Complete -> 356
  }
}

pub fn is_leap_year(year: Int) -> Bool {
  let x = { year * 12 + 17 } % years_in_cycle
  case x < 0 {
    True -> x >= -7
    False -> x >= 12
  }
}

pub fn start_of_year(year: Int) -> Int {
  let months = math.floor_div(235 * year - 234, 19)
  let frac0 = months * month_fract_value + baharad_value
  let day0 = months * 29 + math.floor_div(frac0, day_parts_value)
  let frac = frac0 % day_parts_value
  let wd0 = day0 % 7

  case wd0 == 2 || wd0 == 4 || wd0 == 6 {
    True -> day0 + 1
    False ->
      case wd0 == 1 && frac > 15 * hour_parts + 204 && !is_leap_year(year) {
        True -> day0 + 2
        False ->
          case
            wd0 == 0 && frac > 21 * hour_parts + 589 && is_leap_year(year - 1)
          {
            True -> day0 + 1
            False -> day0
          }
      }
  }
}

pub fn days_in_year(year: Int) -> Int {
  start_of_year(year + 1) - start_of_year(year)
}

pub fn year_type(year: Int) -> YearType {
  let year_length0 = days_in_year(year)
  let year_length = case year_length0 > 380 {
    True -> year_length0 - 30
    False -> year_length0
  }
  case year_length {
    353 -> Deficient
    354 -> Regular
    355 -> Complete
    _ -> Regular
  }
}

fn month_boundary(is_leap: Bool, month: HebrewMonth, type_: YearType) -> Int {
  case is_leap {
    True -> leap_month_start(month, type_)
    False -> month_start(month, type_)
  }
}

fn find_month(is_leap: Bool, type_: YearType, day_of_year: Int) -> HebrewMonth {
  find_month_loop(Tishri, is_leap, type_, day_of_year)
}

fn find_month_loop(
  month: HebrewMonth,
  is_leap: Bool,
  type_: YearType,
  day_of_year: Int,
) -> HebrewMonth {
  case next_month(month) {
    None -> month
    Some(next) ->
      case day_of_year > month_boundary(is_leap, next, type_) {
        True -> find_month_loop(next, is_leap, type_, day_of_year)
        False -> month
      }
  }
}

fn find_year_loop(year: Int, d: Int) -> #(Int, Int, Int) {
  let ys = start_of_year(year)
  let day_of_year = d - ys
  case day_of_year < 1 {
    True -> find_year_loop(year - 1, d)
    False -> #(year, ys, day_of_year)
  }
}

pub fn compute_hebrew_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let time_fields = gregoimp.time_to_fields(local_millis)

  let d = julian_day - 347_997
  let m = math.floor_div(d * day_parts_value, month_parts())
  let year0 = math.floor_div(19 * m + 234, 235) + 1

  let #(year, _ys, day_of_year) = find_year_loop(year0, d)

  let type_ = year_type(year)
  let is_leap = is_leap_year(year)

  let month = find_month(is_leap, type_, day_of_year)
  let day_of_month = day_of_year - month_boundary(is_leap, month, type_)

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
      days_in_year,
      None,
    )

  gregocal.CalendarFields(
    era: 0,
    year:,
    extended_year: year,
    common: gregocal.CommonFields(..common, day_of_month:, day_of_year:),
  )
}
