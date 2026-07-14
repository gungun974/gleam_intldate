import intldate/internal/math

pub const millis_per_day = 86_400_000

pub type DayToYearResult {
  DayToYearResult(year: Int, doy: Int)
}

pub type DayToFieldsResult {
  DayToFieldsResult(year: Int, month: Int, dom: Int, dow: Int, doy: Int)
}

pub type TimeToFieldsResult {
  TimeToFieldsResult(
    year: Int,
    month: Int,
    dom: Int,
    dow: Int,
    doy: Int,
    millis_in_day: Int,
  )
}

const julian_1_ce = 1_721_426

const julian_1970_ce = 2_440_588

pub fn is_leap_year(year: Int) -> Bool {
  year % 4 == 0 && { year % 100 != 0 || year % 400 == 0 }
}

pub fn month_length(year: Int, month: Int) -> Int {
  case is_leap_year(year), month {
    _, 0 -> 31
    False, 1 -> 28
    True, 1 -> 29
    _, 2 -> 31
    _, 3 -> 30
    _, 4 -> 31
    _, 5 -> 30
    _, 6 -> 31
    _, 7 -> 31
    _, 8 -> 30
    _, 9 -> 31
    _, 10 -> 30
    _, 11 -> 31
    _, _ -> 0
  }
}

pub fn previous_month_length(year: Int, month: Int) -> Int {
  case month > 0 {
    True -> month_length(year, month - 1)
    False -> 31
  }
}

pub fn fields_to_day(year: Int, month: Int, dom: Int) -> Int {
  let y = year - 1
  let julian =
    365
    * y
    + math.floor_div(y, 4)
    + { julian_1_ce - 3 }
    + math.floor_div(y, 400)
    - math.floor_div(y, 100)
    + 2
    + days_before_month(year, month)
    + dom
  julian - julian_1970_ce
}

pub fn day_to_year(day: Int) -> DayToYearResult {
  let day = day + { julian_1970_ce - julian_1_ce }
  let #(n400, doy32_1) = math.floor_div_rem(day, 146_097)
  let #(n100, doy32_2) = math.floor_div_rem(doy32_1, 36_524)
  let #(n4, doy32_3) = math.floor_div_rem(doy32_2, 1461)
  let #(n1, doy32_4) = math.floor_div_rem(doy32_3, 365)
  let year = 400 * n400 + 100 * n100 + 4 * n4 + n1
  let #(year, doy) = case n100 == 4 || n1 == 4 {
    True -> #(year, 365)
    False -> #(year + 1, doy32_4)
  }
  DayToYearResult(year:, doy: doy + 1)
}

pub fn day_to_fields(day: Int) -> DayToFieldsResult {
  let result = day_to_year(day)
  let year = result.year
  let doy = result.doy
  let gday = day + { julian_1970_ce - julian_1_ce }
  let dow0 = { gday + 1 } % 7
  let dow =
    dow0
    + case dow0 < 0 {
      True -> 7 + 1
      False -> 1
    }

  let is_leap = is_leap_year(year)
  let march1 = case is_leap {
    True -> 60
    False -> 59
  }
  let correction = case doy > march1 {
    True ->
      case is_leap {
        True -> 1
        False -> 2
      }
    False -> 0
  }
  let month = { 12 * { doy - 1 + correction } + 6 } / 367
  let dom = doy - days_before_month(year, month)
  DayToFieldsResult(year:, month:, dom:, dow:, doy:)
}

fn days_before_month(year: Int, month: Int) -> Int {
  case is_leap_year(year), month {
    _, 0 -> 0
    _, 1 -> 31
    False, 2 -> 59
    True, 2 -> 60
    False, 3 -> 90
    True, 3 -> 91
    False, 4 -> 120
    True, 4 -> 121
    False, 5 -> 151
    True, 5 -> 152
    False, 6 -> 181
    True, 6 -> 182
    False, 7 -> 212
    True, 7 -> 213
    False, 8 -> 243
    True, 8 -> 244
    False, 9 -> 273
    True, 9 -> 274
    False, 10 -> 304
    True, 10 -> 305
    False, 11 -> 334
    True, 11 -> 335
    _, _ -> 0
  }
}

pub fn time_to_fields(time: Int) -> TimeToFieldsResult {
  let #(day, mid) = math.floor_div_rem(time, millis_per_day)
  let fields = day_to_fields(day)
  TimeToFieldsResult(
    year: fields.year,
    month: fields.month,
    dom: fields.dom,
    dow: fields.dow,
    doy: fields.doy,
    millis_in_day: mid,
  )
}
