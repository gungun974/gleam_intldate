import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/time/calendar

pub type Chronology {
  CalendarBuddhist
  CalendarChinese
  CalendarCoptic
  CalendarDangi
  CalendarEthioaa
  CalendarEthiopic
  CalendarGregory
  CalendarHebrew
  CalendarIndian
  CalendarIslamic
  CalendarIslamicUmalqura
  CalendarIslamicTbla
  CalendarIslamicCivil
  CalendarIslamicRgsa
  CalendarIso8601
  CalendarJapanese
  CalendarPersian
  CalendarRoc
}

pub type Converted {
  Converted(
    year: Int,
    month: Int,
    day: Int,
    era_index: Int,
    related_year: Int,
    year_name_index: Int,
    is_leap_month: Bool,
  )
}

const chinese_cache_key = "intldate#chinese"

type ChineseYear {
  ChineseYear(new_year: Int, month_count: Int, leap_pos: Int, length_bits: Int)
}

fn chinese_year_decoder() -> decode.Decoder(ChineseYear) {
  use new_year <- decode.field(0, decode.int)
  use month_count <- decode.field(1, decode.int)
  use leap_pos <- decode.field(2, decode.int)
  use length_bits <- decode.field(3, decode.int)
  decode.success(ChineseYear(new_year:, month_count:, leap_pos:, length_bits:))
}

fn chinese_table_decoder() -> decode.Decoder(List(ChineseYear)) {
  decode.list(chinese_year_decoder())
}

@external(erlang, "intldate_cache_ffi", "lookup")
fn cache_lookup(key: String) -> Result(any, Nil) {
  let _ = key
  Error(Nil)
}

@external(erlang, "intldate_cache_ffi", "insert")
fn cache_insert(key: String, value: any) -> Nil {
  let _ = key
  let _ = value
  Nil
}

@external(erlang, "intldate_locale_ffi", "load_chinese_data")
fn load_chinese_data() -> Result(Dynamic, Nil) {
  Error(Nil)
}

fn chinese_table() -> List(ChineseYear) {
  case cache_lookup(chinese_cache_key) {
    Ok(cached) -> cached
    Error(_) -> load_chinese_table()
  }
}

fn load_chinese_table() -> List(ChineseYear) {
  case load_chinese_data() {
    Ok(data) ->
      case decode.run(data, chinese_table_decoder()) {
        Ok(years) -> {
          let _ = cache_insert(chinese_cache_key, years)
          years
        }
        Error(_) -> []
      }
    Error(_) -> []
  }
}

fn floor_divide(dividend: Int, divisor: Int) -> Int {
  let assert Ok(res) = int.floor_divide(dividend, divisor)
  res
}

fn modulo(value: Int, modulus: Int) -> Int {
  let assert Ok(res) = int.modulo(value, by: modulus)
  res
}

fn pow2(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 2 * pow2(exponent - 1)
  }
}

fn amod(value: Int, modulus: Int) -> Int {
  let assert Ok(remainder) = int.modulo(value, by: modulus)
  case remainder {
    0 -> modulus
    _ -> remainder
  }
}

pub fn gregorian_to_fixed_day(year: Int, month: Int, day: Int) -> Int {
  let prior_years = year - 1

  365
  * prior_years
  + floor_divide(prior_years, 4)
  - floor_divide(prior_years, 100)
  + floor_divide(prior_years, 400)
  + floor_divide(367 * month - 362, 12)
  + case month <= 2 {
    True -> 0
    False ->
      case calendar.is_leap_year(year) {
        True -> -1
        False -> -2
      }
  }
  + day
}

fn day_of_year(year: Int, month: Int, day: Int) -> Int {
  gregorian_to_fixed_day(year, month, day)
  - gregorian_to_fixed_day(year, 1, 1)
  + 1
}

pub fn convert(
  cal: Chronology,
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  case cal {
    CalendarBuddhist ->
      plain(gregorian_year + 543, gregorian_month, gregorian_day)
    CalendarRoc -> convert_roc(gregorian_year, gregorian_month, gregorian_day)
    CalendarJapanese ->
      convert_japanese(gregorian_year, gregorian_month, gregorian_day)
    CalendarCoptic ->
      convert_coptic(gregorian_year, gregorian_month, gregorian_day)
    CalendarEthiopic ->
      convert_ethiopic(gregorian_year, gregorian_month, gregorian_day, 0)
    CalendarEthioaa ->
      convert_ethiopic(gregorian_year, gregorian_month, gregorian_day, 5500)
    CalendarIndian ->
      convert_indian(gregorian_year, gregorian_month, gregorian_day)
    CalendarPersian ->
      convert_persian(gregorian_year, gregorian_month, gregorian_day)
    CalendarHebrew ->
      convert_hebrew(gregorian_year, gregorian_month, gregorian_day)
    CalendarIslamicTbla ->
      convert_islamic(gregorian_year, gregorian_month, gregorian_day, 227_014)
    CalendarIslamic
    | CalendarIslamicCivil
    | CalendarIslamicUmalqura
    | CalendarIslamicRgsa ->
      convert_islamic(gregorian_year, gregorian_month, gregorian_day, 227_015)
    CalendarChinese ->
      convert_chinese(gregorian_year, gregorian_month, gregorian_day, False)
    CalendarDangi ->
      convert_chinese(gregorian_year, gregorian_month, gregorian_day, True)
    _ -> plain(gregorian_year, gregorian_month, gregorian_day)
  }
}

fn plain(year: Int, month: Int, day: Int) -> Converted {
  Converted(
    year: year,
    month: month,
    day: day,
    era_index: case year > 0 {
      True -> 1
      False -> 0
    },
    related_year: year,
    year_name_index: 0,
    is_leap_month: False,
  )
}

fn convert_roc(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  case gregorian_year > 1911 {
    True ->
      Converted(
        ..plain(gregorian_year - 1911, gregorian_month, gregorian_day),
        era_index: 1,
      )
    False ->
      Converted(
        ..plain(1912 - gregorian_year, gregorian_month, gregorian_day),
        era_index: 0,
      )
  }
}

const japanese_eras = [
  #(2019, 5, 1, 236),
  #(1989, 1, 8, 235),
  #(1926, 12, 25, 234),
  #(1912, 7, 30, 233),
  #(1868, 10, 23, 232),
]

fn convert_japanese(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  case
    list.find(japanese_eras, fn(era_entry) {
      let #(era_start_year, era_start_month, era_start_day, _) = era_entry
      gregorian_to_fixed_day(era_start_year, era_start_month, era_start_day)
      <= gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
    })
  {
    Ok(#(era_start_year, _, _, era_index)) ->
      Converted(
        ..plain(
          gregorian_year - era_start_year + 1,
          gregorian_month,
          gregorian_day,
        ),
        era_index:,
      )
    Error(_) ->
      Converted(
        ..plain(gregorian_year, gregorian_month, gregorian_day),
        era_index: 0,
      )
  }
}

const coptic_epoch = 103_605

fn fixed_day_from_coptic(
  coptic_year: Int,
  coptic_month: Int,
  coptic_day: Int,
) -> Int {
  coptic_epoch
  - 1
  + 365
  * { coptic_year - 1 }
  + floor_divide(coptic_year - 1, 4)
  + 30
  * { coptic_month - 1 }
  + coptic_day
}

fn convert_coptic(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  let fixed_day =
    gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
  let coptic_year = floor_divide(4 * { fixed_day - coptic_epoch } + 1463, 1461)
  let coptic_month =
    floor_divide(fixed_day - fixed_day_from_coptic(coptic_year, 1, 1), 30) + 1
  let coptic_day =
    fixed_day - fixed_day_from_coptic(coptic_year, coptic_month, 1) + 1
  Converted(..plain(coptic_year, coptic_month, coptic_day), era_index: 1)
}

const ethiopic_epoch = 2796

fn fixed_day_from_ethiopic(
  ethiopic_year: Int,
  ethiopic_month: Int,
  ethiopic_day: Int,
) -> Int {
  ethiopic_epoch
  - 1
  + 365
  * { ethiopic_year - 1 }
  + floor_divide(ethiopic_year - 1, 4)
  + 30
  * { ethiopic_month - 1 }
  + ethiopic_day
}

fn convert_ethiopic(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
  year_offset: Int,
) -> Converted {
  let fixed_day =
    gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
  let ethiopic_year =
    floor_divide(4 * { fixed_day - ethiopic_epoch } + 1463, 1461)
  let ethiopic_month =
    floor_divide(fixed_day - fixed_day_from_ethiopic(ethiopic_year, 1, 1), 30)
    + 1
  let ethiopic_day =
    fixed_day - fixed_day_from_ethiopic(ethiopic_year, ethiopic_month, 1) + 1
  Converted(
    ..plain(ethiopic_year + year_offset, ethiopic_month, ethiopic_day),
    era_index: 0,
  )
}

fn convert_indian(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  let day_of_gregorian_year =
    day_of_year(gregorian_year, gregorian_month, gregorian_day)

  let #(saka_year, day_of_saka_year, chaitra_length) = case
    day_of_gregorian_year >= 81
  {
    True -> #(
      gregorian_year - 78,
      day_of_gregorian_year - 81,
      case calendar.is_leap_year(gregorian_year) {
        True -> 31
        False -> 30
      },
    )
    False -> {
      let previous_gregorian_year_length = case
        calendar.is_leap_year(gregorian_year - 1)
      {
        True -> 366
        False -> 365
      }
      #(
        gregorian_year - 79,
        day_of_gregorian_year + previous_gregorian_year_length - 81,
        case calendar.is_leap_year(gregorian_year - 1) {
          True -> 31
          False -> 30
        },
      )
    }
  }

  let #(saka_month, saka_day) = case day_of_saka_year < chaitra_length {
    True -> #(1, day_of_saka_year + 1)
    False -> {
      let days_after_chaitra = day_of_saka_year - chaitra_length
      case days_after_chaitra < 5 * 31 {
        True -> #(
          2 + floor_divide(days_after_chaitra, 31),
          days_after_chaitra % 31 + 1,
        )
        False -> {
          let days_after_31day_months = days_after_chaitra - 5 * 31
          #(
            7 + floor_divide(days_after_31day_months, 30),
            days_after_31day_months % 30 + 1,
          )
        }
      }
    }
  }

  Converted(..plain(saka_year, saka_month, saka_day), era_index: 0)
}

fn convert_persian(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  let days_before_gregorian_month = case gregorian_month {
    1 -> 0
    2 -> 31
    3 -> 59
    4 -> 90
    5 -> 120
    6 -> 151
    7 -> 181
    8 -> 212
    9 -> 243
    10 -> 273
    11 -> 304
    12 -> 334
    _ -> 0
  }
  let leap_year_reference = case gregorian_month > 2 {
    True -> gregorian_year + 1
    False -> gregorian_year
  }
  let days_since_persian_epoch =
    355_666
    + 365
    * gregorian_year
    + floor_divide(leap_year_reference + 3, 4)
    - floor_divide(leap_year_reference + 99, 100)
    + floor_divide(leap_year_reference + 399, 400)
    + gregorian_day
    + days_before_gregorian_month
  let jalali_year_from_33year_cycle =
    -1595 + 33 * floor_divide(days_since_persian_epoch, 12_053)
  let days_in_33year_cycle = days_since_persian_epoch % 12_053
  let jalali_year_from_4year_cycle =
    jalali_year_from_33year_cycle + 4 * floor_divide(days_in_33year_cycle, 1461)
  let days_in_4year_cycle = days_in_33year_cycle % 1461
  let #(jalali_year, day_of_jalali_year) = case days_in_4year_cycle > 365 {
    True -> #(
      jalali_year_from_4year_cycle + floor_divide(days_in_4year_cycle - 1, 365),
      { days_in_4year_cycle - 1 } % 365,
    )
    False -> #(jalali_year_from_4year_cycle, days_in_4year_cycle)
  }
  let #(jalali_month, jalali_day) = case day_of_jalali_year < 186 {
    True -> #(
      1 + floor_divide(day_of_jalali_year, 31),
      1 + day_of_jalali_year % 31,
    )
    False -> #(
      7 + floor_divide(day_of_jalali_year - 186, 30),
      1 + { day_of_jalali_year - 186 } % 30,
    )
  }
  Converted(..plain(jalali_year, jalali_month, jalali_day), era_index: 0)
}

const islamic_leap_offset = 14

fn islamic_leap(islamic_year: Int) -> Bool {
  { 11 * islamic_year + islamic_leap_offset } % 30 < 11
}

fn islamic_month_length(islamic_year: Int, islamic_month: Int) -> Int {
  case islamic_month % 2 == 1 {
    True -> 30
    False ->
      case islamic_month == 12 && islamic_leap(islamic_year) {
        True -> 30
        False -> 29
      }
  }
}

fn fixed_day_from_islamic(
  islamic_year: Int,
  islamic_month: Int,
  islamic_day: Int,
  epoch: Int,
) -> Int {
  epoch
  - 1
  + { islamic_year - 1 }
  * 354
  + floor_divide(3 + 11 * islamic_year, 30)
  + 29
  * { islamic_month - 1 }
  + floor_divide(islamic_month, 2)
  + islamic_day
}

fn convert_islamic(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
  epoch: Int,
) -> Converted {
  let fixed_day =
    gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
  let islamic_year = floor_divide(30 * { fixed_day - epoch } + 10_646, 10_631)
  let islamic_month = islamic_find_month(fixed_day, islamic_year, 1, epoch)
  let islamic_day =
    fixed_day
    - fixed_day_from_islamic(islamic_year, islamic_month, 1, epoch)
    + 1
  Converted(..plain(islamic_year, islamic_month, islamic_day), era_index: 0)
}

fn islamic_find_month(
  fixed_day: Int,
  islamic_year: Int,
  candidate_month: Int,
  epoch: Int,
) -> Int {
  case candidate_month >= 12 {
    True -> 12
    False -> {
      let last_day_of_candidate_month =
        fixed_day_from_islamic(
          islamic_year,
          candidate_month,
          islamic_month_length(islamic_year, candidate_month),
          epoch,
        )
      case fixed_day <= last_day_of_candidate_month {
        True -> candidate_month
        False ->
          islamic_find_month(
            fixed_day,
            islamic_year,
            candidate_month + 1,
            epoch,
          )
      }
    }
  }
}

const hebrew_epoch = -1_373_427

fn hebrew_leap(hebrew_year: Int) -> Bool {
  { 7 * hebrew_year + 1 } % 19 < 7
}

fn hebrew_last_month(hebrew_year: Int) -> Int {
  case hebrew_leap(hebrew_year) {
    True -> 13
    False -> 12
  }
}

fn hebrew_elapsed_days(hebrew_year: Int) -> Int {
  let months_elapsed = floor_divide(235 * hebrew_year - 234, 19)
  let parts_elapsed = 12_084 + 13_753 * months_elapsed
  let elapsed_days = 29 * months_elapsed + floor_divide(parts_elapsed, 25_920)
  case { 3 * { elapsed_days + 1 } } % 7 < 3 {
    True -> elapsed_days + 1
    False -> elapsed_days
  }
}

fn hebrew_year_correction(hebrew_year: Int) -> Int {
  let new_year_prev = hebrew_elapsed_days(hebrew_year - 1)
  let new_year_curr = hebrew_elapsed_days(hebrew_year)
  let new_year_next = hebrew_elapsed_days(hebrew_year + 1)
  case new_year_next - new_year_curr == 356 {
    True -> 2
    False ->
      case new_year_curr - new_year_prev == 382 {
        True -> 1
        False -> 0
      }
  }
}

fn hebrew_new_year(hebrew_year: Int) -> Int {
  hebrew_epoch
  + hebrew_elapsed_days(hebrew_year)
  + hebrew_year_correction(hebrew_year)
}

fn hebrew_days_in_year(hebrew_year: Int) -> Int {
  hebrew_new_year(hebrew_year + 1) - hebrew_new_year(hebrew_year)
}

fn hebrew_long_marheshvan(hebrew_year: Int) -> Bool {
  let days_in_year = hebrew_days_in_year(hebrew_year)
  days_in_year == 355 || days_in_year == 385
}

fn hebrew_short_kislev(hebrew_year: Int) -> Bool {
  let days_in_year = hebrew_days_in_year(hebrew_year)
  days_in_year == 353 || days_in_year == 383
}

fn hebrew_last_day(hebrew_year: Int, hebrew_month: Int) -> Int {
  case
    hebrew_month == 2
    || hebrew_month == 4
    || hebrew_month == 6
    || hebrew_month == 10
    || hebrew_month == 13
  {
    True -> 29
    False ->
      case hebrew_month == 12 && !hebrew_leap(hebrew_year) {
        True -> 29
        False ->
          case hebrew_month == 8 && !hebrew_long_marheshvan(hebrew_year) {
            True -> 29
            False ->
              case hebrew_month == 9 && hebrew_short_kislev(hebrew_year) {
                True -> 29
                False -> 30
              }
          }
      }
  }
}

fn hebrew_sum_days(hebrew_year: Int, from_month: Int, to_month: Int) -> Int {
  case from_month > to_month {
    True -> 0
    False ->
      hebrew_last_day(hebrew_year, from_month)
      + hebrew_sum_days(hebrew_year, from_month + 1, to_month)
  }
}

fn fixed_day_from_hebrew(
  hebrew_year: Int,
  hebrew_month: Int,
  hebrew_day: Int,
) -> Int {
  let days_before_month_1 = hebrew_new_year(hebrew_year) + hebrew_day - 1
  case hebrew_month < 7 {
    True ->
      days_before_month_1
      + hebrew_sum_days(hebrew_year, 7, hebrew_last_month(hebrew_year))
      + hebrew_sum_days(hebrew_year, 1, hebrew_month - 1)
    False ->
      days_before_month_1 + hebrew_sum_days(hebrew_year, 7, hebrew_month - 1)
  }
}

fn convert_hebrew(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
) -> Converted {
  let fixed_day =
    gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
  let approximate_hebrew_year =
    floor_divide({ fixed_day - hebrew_epoch } * 98_496, 35_975_351) + 1
  let hebrew_year = hebrew_search_year(fixed_day, approximate_hebrew_year)
  let first_month_to_check = case
    fixed_day < fixed_day_from_hebrew(hebrew_year, 1, 1)
  {
    True -> 7
    False -> 1
  }
  let hebrew_month =
    hebrew_search_month(fixed_day, hebrew_year, first_month_to_check)
  let hebrew_day =
    fixed_day - fixed_day_from_hebrew(hebrew_year, hebrew_month, 1) + 1
  let #(cldr_month, is_leap_month) =
    hebrew_to_cldr_month(hebrew_month, hebrew_leap(hebrew_year))
  Converted(
    ..plain(hebrew_year, cldr_month, hebrew_day),
    era_index: 0,
    is_leap_month:,
  )
}

fn hebrew_search_year(fixed_day: Int, candidate_year: Int) -> Int {
  case hebrew_new_year(candidate_year + 1) <= fixed_day {
    True -> hebrew_search_year(fixed_day, candidate_year + 1)
    False -> candidate_year
  }
}

fn hebrew_search_month(
  fixed_day: Int,
  hebrew_year: Int,
  candidate_month: Int,
) -> Int {
  case
    fixed_day
    > fixed_day_from_hebrew(
      hebrew_year,
      candidate_month,
      hebrew_last_day(hebrew_year, candidate_month),
    )
  {
    True -> hebrew_search_month(fixed_day, hebrew_year, candidate_month + 1)
    False -> candidate_month
  }
}

fn hebrew_to_cldr_month(hebrew_month: Int, is_leap_year: Bool) -> #(Int, Bool) {
  case hebrew_month {
    7 -> #(1, False)
    8 -> #(2, False)
    9 -> #(3, False)
    10 -> #(4, False)
    11 -> #(5, False)
    12 ->
      case is_leap_year {
        True -> #(6, False)
        False -> #(7, False)
      }
    13 ->
      case is_leap_year {
        True -> #(7, True)
        False -> #(1, False)
      }
    1 -> #(8, False)
    2 -> #(9, False)
    3 -> #(10, False)
    4 -> #(11, False)
    5 -> #(12, False)
    6 -> #(13, False)
    _ -> #(hebrew_month, False)
  }
}

fn gregorian_year_from_fixed_day(fixed_day: Int) -> Int {
  let days_base = fixed_day - 1
  let n400 = floor_divide(days_base, 146_097)
  let days_mod400 = modulo(days_base, 146_097)
  let n100 = floor_divide(days_mod400, 36_524)
  let days_mod100 = modulo(days_mod400, 36_524)
  let periods_4 = floor_divide(days_mod100, 1461)
  let days_mod4 = modulo(days_mod100, 1461)
  let periods_1 = floor_divide(days_mod4, 365)
  let year = 400 * n400 + 100 * n100 + 4 * periods_4 + periods_1
  case n100 == 4 || periods_1 == 4 {
    True -> year
    False -> year + 1
  }
}

fn convert_chinese(
  gregorian_year: Int,
  gregorian_month: Int,
  gregorian_day: Int,
  _dangi: Bool,
) -> Converted {
  let fixed_day =
    gregorian_to_fixed_day(gregorian_year, gregorian_month, gregorian_day)
  case find_chinese_year(chinese_table(), fixed_day) {
    Ok(chinese_year_entry) -> {
      let related_year =
        gregorian_year_from_fixed_day(chinese_year_entry.new_year)
      let #(month, day, is_leap) =
        chinese_walk(
          chinese_year_entry,
          fixed_day - chinese_year_entry.new_year,
          1,
        )
      Converted(
        year: related_year,
        month:,
        day:,
        era_index: 0,
        related_year:,
        year_name_index: amod(related_year - 3, 60),
        is_leap_month: is_leap,
      )
    }
    Error(_) -> {
      let related_year = gregorian_year
      Converted(
        ..plain(related_year, gregorian_month, gregorian_day),
        related_year:,
        year_name_index: amod(related_year - 3, 60),
      )
    }
  }
}

fn find_chinese_year(
  remaining_table: List(ChineseYear),
  fixed_day: Int,
) -> Result(ChineseYear, Nil) {
  case remaining_table {
    [] -> Error(Nil)
    [current_entry] ->
      case current_entry.new_year <= fixed_day {
        True -> Ok(current_entry)
        False -> Error(Nil)
      }
    [current_entry, next_entry, ..rest] ->
      case
        current_entry.new_year <= fixed_day && fixed_day < next_entry.new_year
      {
        True -> Ok(current_entry)
        False -> find_chinese_year([next_entry, ..rest], fixed_day)
      }
  }
}

fn chinese_walk(
  chinese_year_entry: ChineseYear,
  days_remaining: Int,
  candidate_month: Int,
) -> #(Int, Int, Bool) {
  let month_length = case
    { chinese_year_entry.length_bits / pow2(candidate_month - 1) } % 2 == 1
  {
    True -> 30
    False -> 29
  }
  case
    days_remaining < month_length
    || candidate_month >= chinese_year_entry.month_count
  {
    True -> {
      let day_of_month = days_remaining + 1
      case chinese_year_entry.leap_pos {
        0 -> #(candidate_month, day_of_month, False)
        leap_pos_val ->
          case candidate_month < leap_pos_val {
            True -> #(candidate_month, day_of_month, False)
            False ->
              case candidate_month == leap_pos_val {
                True -> #(candidate_month - 1, day_of_month, True)
                False -> #(candidate_month - 1, day_of_month, False)
              }
          }
      }
    }
    False ->
      chinese_walk(
        chinese_year_entry,
        days_remaining - month_length,
        candidate_month + 1,
      )
  }
}
