import gleam/float
import gleam/int
import gleam/option.{None}
import intldate/internal/icu/calendar/astro
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/math

const millis_per_day = 86_400_000

const julian_1970_ce = 2_440_588

const civil_epoc = 1_948_440

const astronomical_epoc = 1_948_439

const hijra_millis = -42_521_587_200_000.0

pub fn civil_leap_year(year: Int) -> Bool {
  { { 14 + 11 * year } % 30 } < 11
}

pub fn civil_year_start(year: Int) -> Int {
  354 * { year - 1 } + math.floor_div(3 + 11 * year, 30)
}

pub fn civil_month_start(year: Int, month: Int) -> Int {
  math.ceil_float(29.5 *. int.to_float(month))
  + 354
  * { year - 1 }
  + math.floor_div(11 * year + 3, 30)
}

pub fn civil_month_length(year: Int, month: Int) -> Int {
  let length = 29 + { { month + 1 } % 2 }
  case month == 11 && civil_leap_year(year) {
    True -> length + 1
    False -> length
  }
}

pub fn civil_year_length(year: Int) -> Int {
  354
  + case civil_leap_year(year) {
    True -> 1
    False -> 0
  }
}

pub fn compute_islamic_civil_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
  epoc: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let time_fields = gregoimp.time_to_fields(local_millis)

  let days = julian_day - epoc
  let year = math.floor_div(30 * days + 10_646, 10_631)
  let month0 =
    math.ceil_float(int.to_float(days - 29 - civil_year_start(year)) /. 29.5)
  let month = case month0 < 11 {
    True -> month0
    False -> 11
  }

  let day_of_month = days - civil_month_start(year, month) + 1
  let day_of_year = days - civil_month_start(year, 0) + 1

  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      year,
      month,
      day_of_month,
      time_fields.dow,
      day_of_year,
      time_fields.millis_in_day,
      civil_year_length,
      None,
    )

  gregocal.CalendarFields(
    era: 0,
    year:,
    extended_year: year,
    common: gregocal.CommonFields(..common, day_of_month:, day_of_year:),
  )
}

pub fn moon_age_degrees(time_millis: Int) -> Float {
  let age =
    astro.get_moon_age(
      astro.create_calendar_astronomer(int.to_float(time_millis)),
    )
    *. 180.0
    /. math.pi()
  case age >. 180.0 {
    True -> age -. 360.0
    False -> age
  }
}

fn true_month_start_search_down(origin: Float) -> Float {
  let next_origin = origin -. int.to_float(millis_per_day)
  let age = moon_age_degrees(float.round(next_origin))
  case age >=. 0.0 {
    True -> true_month_start_search_down(next_origin)
    False -> next_origin
  }
}

fn true_month_start_search_up(origin: Float) -> Float {
  let next_origin = origin +. int.to_float(millis_per_day)
  let age = moon_age_degrees(float.round(next_origin))
  case age <. 0.0 {
    True -> true_month_start_search_up(next_origin)
    False -> next_origin
  }
}

pub fn true_month_start(month: Int) -> Int {
  let origin0 =
    hijra_millis
    +. int.to_float(math.floor_float(int.to_float(month) *. astro.synodic_month))
    *. int.to_float(millis_per_day)
  let age = moon_age_degrees(float.round(origin0))
  let origin = case age >=. 0.0 {
    True -> true_month_start_search_down(origin0)
    False -> true_month_start_search_up(origin0)
  }
  math.floor_float({ origin -. hijra_millis } /. int.to_float(millis_per_day))
  + 1
}

pub fn astro_month_start(year: Int, month: Int) -> Int {
  true_month_start(12 * { year - 1 } + month)
}

pub fn astro_year_length(year: Int) -> Int {
  let m = 12 * { year - 1 }
  true_month_start(m + 12) - true_month_start(m)
}

const umalqura_year_start_bound = 1300

const umalqura_year_end = 1600

fn umalqura_monthlength_at(idx: Int) -> Int {
  case idx {
    0 -> 0x0aaa
    1 -> 0x0d54
    2 -> 0x0ec9
    3 -> 0x06d4
    4 -> 0x06ea
    5 -> 0x036c
    6 -> 0x0aad
    7 -> 0x0555
    8 -> 0x06a9
    9 -> 0x0792
    10 -> 0x0ba9
    11 -> 0x05d4
    12 -> 0x0ada
    13 -> 0x055c
    14 -> 0x0d2d
    15 -> 0x0695
    16 -> 0x074a
    17 -> 0x0b54
    18 -> 0x0b6a
    19 -> 0x05ad
    20 -> 0x04ae
    21 -> 0x0a4f
    22 -> 0x0517
    23 -> 0x068b
    24 -> 0x06a5
    25 -> 0x0ad5
    26 -> 0x02d6
    27 -> 0x095b
    28 -> 0x049d
    29 -> 0x0a4d
    30 -> 0x0d26
    31 -> 0x0d95
    32 -> 0x05ac
    33 -> 0x09b6
    34 -> 0x02ba
    35 -> 0x0a5b
    36 -> 0x052b
    37 -> 0x0a95
    38 -> 0x06ca
    39 -> 0x0ae9
    40 -> 0x02f4
    41 -> 0x0976
    42 -> 0x02b6
    43 -> 0x0956
    44 -> 0x0aca
    45 -> 0x0ba4
    46 -> 0x0bd2
    47 -> 0x05d9
    48 -> 0x02dc
    49 -> 0x096d
    50 -> 0x054d
    51 -> 0x0aa5
    52 -> 0x0b52
    53 -> 0x0ba5
    54 -> 0x05b4
    55 -> 0x09b6
    56 -> 0x0557
    57 -> 0x0297
    58 -> 0x054b
    59 -> 0x06a3
    60 -> 0x0752
    61 -> 0x0b65
    62 -> 0x056a
    63 -> 0x0aab
    64 -> 0x052b
    65 -> 0x0c95
    66 -> 0x0d4a
    67 -> 0x0da5
    68 -> 0x05ca
    69 -> 0x0ad6
    70 -> 0x0957
    71 -> 0x04ab
    72 -> 0x094b
    73 -> 0x0aa5
    74 -> 0x0b52
    75 -> 0x0b6a
    76 -> 0x0575
    77 -> 0x0276
    78 -> 0x08b7
    79 -> 0x045b
    80 -> 0x0555
    81 -> 0x05a9
    82 -> 0x05b4
    83 -> 0x09da
    84 -> 0x04dd
    85 -> 0x026e
    86 -> 0x0936
    87 -> 0x0aaa
    88 -> 0x0d54
    89 -> 0x0db2
    90 -> 0x05d5
    91 -> 0x02da
    92 -> 0x095b
    93 -> 0x04ab
    94 -> 0x0a55
    95 -> 0x0b49
    96 -> 0x0b64
    97 -> 0x0b71
    98 -> 0x05b4
    99 -> 0x0ab5
    100 -> 0x0a55
    101 -> 0x0d25
    102 -> 0x0e92
    103 -> 0x0ec9
    104 -> 0x06d4
    105 -> 0x0ae9
    106 -> 0x096b
    107 -> 0x04ab
    108 -> 0x0a93
    109 -> 0x0d49
    110 -> 0x0da4
    111 -> 0x0db2
    112 -> 0x0ab9
    113 -> 0x04ba
    114 -> 0x0a5b
    115 -> 0x052b
    116 -> 0x0a95
    117 -> 0x0b2a
    118 -> 0x0b55
    119 -> 0x055c
    120 -> 0x04bd
    121 -> 0x023d
    122 -> 0x091d
    123 -> 0x0a95
    124 -> 0x0b4a
    125 -> 0x0b5a
    126 -> 0x056d
    127 -> 0x02b6
    128 -> 0x093b
    129 -> 0x049b
    130 -> 0x0655
    131 -> 0x06a9
    132 -> 0x0754
    133 -> 0x0b6a
    134 -> 0x056c
    135 -> 0x0aad
    136 -> 0x0555
    137 -> 0x0b29
    138 -> 0x0b92
    139 -> 0x0ba9
    140 -> 0x05d4
    141 -> 0x0ada
    142 -> 0x055a
    143 -> 0x0aab
    144 -> 0x0595
    145 -> 0x0749
    146 -> 0x0764
    147 -> 0x0baa
    148 -> 0x05b5
    149 -> 0x02b6
    150 -> 0x0a56
    151 -> 0x0e4d
    152 -> 0x0b25
    153 -> 0x0b52
    154 -> 0x0b6a
    155 -> 0x05ad
    156 -> 0x02ae
    157 -> 0x092f
    158 -> 0x0497
    159 -> 0x064b
    160 -> 0x06a5
    161 -> 0x06ac
    162 -> 0x0ad6
    163 -> 0x055d
    164 -> 0x049d
    165 -> 0x0a4d
    166 -> 0x0d16
    167 -> 0x0d95
    168 -> 0x05aa
    169 -> 0x05b5
    170 -> 0x02da
    171 -> 0x095b
    172 -> 0x04ad
    173 -> 0x0595
    174 -> 0x06ca
    175 -> 0x06e4
    176 -> 0x0aea
    177 -> 0x04f5
    178 -> 0x02b6
    179 -> 0x0956
    180 -> 0x0aaa
    181 -> 0x0b54
    182 -> 0x0bd2
    183 -> 0x05d9
    184 -> 0x02ea
    185 -> 0x096d
    186 -> 0x04ad
    187 -> 0x0a95
    188 -> 0x0b4a
    189 -> 0x0ba5
    190 -> 0x05b2
    191 -> 0x09b5
    192 -> 0x04d6
    193 -> 0x0a97
    194 -> 0x0547
    195 -> 0x0693
    196 -> 0x0749
    197 -> 0x0b55
    198 -> 0x056a
    199 -> 0x0a6b
    200 -> 0x052b
    201 -> 0x0a8b
    202 -> 0x0d46
    203 -> 0x0da3
    204 -> 0x05ca
    205 -> 0x0ad6
    206 -> 0x04db
    207 -> 0x026b
    208 -> 0x094b
    209 -> 0x0aa5
    210 -> 0x0b52
    211 -> 0x0b69
    212 -> 0x0575
    213 -> 0x0176
    214 -> 0x08b7
    215 -> 0x025b
    216 -> 0x052b
    217 -> 0x0565
    218 -> 0x05b4
    219 -> 0x09da
    220 -> 0x04ed
    221 -> 0x016d
    222 -> 0x08b6
    223 -> 0x0aa6
    224 -> 0x0d52
    225 -> 0x0da9
    226 -> 0x05d4
    227 -> 0x0ada
    228 -> 0x095b
    229 -> 0x04ab
    230 -> 0x0653
    231 -> 0x0729
    232 -> 0x0762
    233 -> 0x0ba9
    234 -> 0x05b2
    235 -> 0x0ab5
    236 -> 0x0555
    237 -> 0x0b25
    238 -> 0x0d92
    239 -> 0x0ec9
    240 -> 0x06d2
    241 -> 0x0ae9
    242 -> 0x056b
    243 -> 0x04ab
    244 -> 0x0a55
    245 -> 0x0d29
    246 -> 0x0d54
    247 -> 0x0daa
    248 -> 0x09b5
    249 -> 0x04ba
    250 -> 0x0a3b
    251 -> 0x049b
    252 -> 0x0a4d
    253 -> 0x0aaa
    254 -> 0x0ad5
    255 -> 0x02da
    256 -> 0x095d
    257 -> 0x045e
    258 -> 0x0a2e
    259 -> 0x0c9a
    260 -> 0x0d55
    261 -> 0x06b2
    262 -> 0x06b9
    263 -> 0x04ba
    264 -> 0x0a5d
    265 -> 0x052d
    266 -> 0x0a95
    267 -> 0x0b52
    268 -> 0x0ba8
    269 -> 0x0bb4
    270 -> 0x05b9
    271 -> 0x02da
    272 -> 0x095a
    273 -> 0x0b4a
    274 -> 0x0da4
    275 -> 0x0ed1
    276 -> 0x06e8
    277 -> 0x0b6a
    278 -> 0x056d
    279 -> 0x0535
    280 -> 0x0695
    281 -> 0x0d4a
    282 -> 0x0da8
    283 -> 0x0dd4
    284 -> 0x06da
    285 -> 0x055b
    286 -> 0x029d
    287 -> 0x062b
    288 -> 0x0b15
    289 -> 0x0b4a
    290 -> 0x0b95
    291 -> 0x05aa
    292 -> 0x0aae
    293 -> 0x092e
    294 -> 0x0c8f
    295 -> 0x0527
    296 -> 0x0695
    297 -> 0x06aa
    298 -> 0x0ad6
    299 -> 0x055d
    300 -> 0x029d
    _ -> 0
  }
}

fn umalqura_yr_start_fix(idx: Int) -> Int {
  case idx {
    2
    | 4
    | 10
    | 18
    | 45
    | 46
    | 53
    | 67
    | 75
    | 83
    | 89
    | 97
    | 102
    | 103
    | 105
    | 111
    | 124
    | 125
    | 132
    | 133
    | 135
    | 138
    | 139
    | 141
    | 143
    | 146
    | 147
    | 154
    | 162
    | 176
    | 181
    | 182
    | 203
    | 211
    | 225
    | 233
    | 239
    | 241
    | 247
    | 260
    | 269
    | 274
    | 275
    | 277
    | 282
    | 283
    | 290 -> -1
    20
    | 22
    | 23
    | 28
    | 36
    | 42
    | 50
    | 57
    | 58
    | 71
    | 72
    | 77
    | 79
    | 80
    | 85
    | 91
    | 93
    | 107
    | 115
    | 121
    | 129
    | 156
    | 158
    | 159
    | 164
    | 170
    | 172
    | 178
    | 186
    | 194
    | 200
    | 207
    | 208
    | 213
    | 215
    | 216
    | 221
    | 229
    | 243
    | 249
    | 251
    | 257
    | 265
    | 279
    | 286
    | 287
    | 295
    | 300 -> 1
    _ -> 0
  }
}

pub fn umalqura_year_start(year: Int) -> Int {
  case year < umalqura_year_start_bound || year > umalqura_year_end {
    True -> civil_year_start(year)
    False -> {
      let idx = year - umalqura_year_start_bound
      let yr_start_linear_estimate =
        float.truncate(354.3672 *. int.to_float(idx) +. 460_322.05 +. 0.5)
      yr_start_linear_estimate + umalqura_yr_start_fix(idx)
    }
  }
}

pub fn umalqura_month_length(year: Int, month: Int) -> Int {
  case year < umalqura_year_start_bound || year > umalqura_year_end {
    True -> civil_month_length(year, month)
    False -> {
      let mask = int.bitwise_shift_left(1, 11 - month)
      let idx = year - umalqura_year_start_bound
      let value = umalqura_monthlength_at(idx)
      29
      + case int.bitwise_and(value, mask) != 0 {
        True -> 1
        False -> 0
      }
    }
  }
}

pub fn umalqura_month_start(year: Int, month: Int) -> Int {
  umalqura_month_start_loop(year, 0, month, umalqura_year_start(year))
}

fn umalqura_month_start_loop(year: Int, i: Int, month: Int, acc: Int) -> Int {
  case i < month {
    True ->
      umalqura_month_start_loop(
        year,
        i + 1,
        month,
        acc + umalqura_month_length(year, i),
      )
    False -> acc
  }
}

pub fn umalqura_year_length(year: Int) -> Int {
  case year < umalqura_year_start_bound || year > umalqura_year_end {
    True -> civil_year_length(year)
    False -> umalqura_year_length_loop(year, 0, 0)
  }
}

fn umalqura_year_length_loop(year: Int, i: Int, acc: Int) -> Int {
  case i < 12 {
    True ->
      umalqura_year_length_loop(
        year,
        i + 1,
        acc + umalqura_month_length(year, i),
      )
    False -> acc
  }
}

fn k_umalqura_start() -> Int {
  umalqura_year_start(umalqura_year_start_bound)
}

pub fn compute_islamic_civil_calendar_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_islamic_civil_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    civil_epoc,
  )
}

pub fn compute_islamic_tbla_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  compute_islamic_civil_fields(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    astronomical_epoc,
  )
}

pub fn compute_islamic_astro_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let days = julian_day - civil_epoc

  let month0 = math.floor_float(int.to_float(days) /. astro.synodic_month)
  let start_date_guess =
    math.floor_float(int.to_float(month0) *. astro.synodic_month)

  let age = moon_age_degrees(epoch_millis)
  let month1 = case days - start_date_guess >= 25 && age >. 0.0 {
    True -> month0 + 1
    False -> month0
  }

  let month2 = find_month_start(month1, days)

  let year = case month2 >= 0 {
    True -> month2 / 12 + 1
    False -> { month2 + 1 } / 12
  }
  let month = { { month2 % 12 } + 12 } % 12

  let day_of_month = days - astro_month_start(year, month) + 1
  let day_of_year = days - astro_month_start(year, 0) + 1

  let time_fields = gregoimp.time_to_fields(local_millis)
  let common =
    gregocal.compute_common_fields(
      bundle,
      locale_id,
      year,
      month,
      day_of_month,
      time_fields.dow,
      day_of_year,
      time_fields.millis_in_day,
      astro_year_length,
      None,
    )

  gregocal.CalendarFields(
    era: 0,
    year:,
    extended_year: year,
    common: gregocal.CommonFields(..common, day_of_month:, day_of_year:),
  )
}

fn find_month_start(month: Int, days: Int) -> Int {
  case true_month_start(month) > days {
    True -> find_month_start(month - 1, days)
    False -> month
  }
}

pub fn compute_islamic_umalqura_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let day = math.floor_div(local_millis, millis_per_day)
  let julian_day = day + julian_1970_ce
  let days = julian_day - civil_epoc

  case days < k_umalqura_start() {
    True ->
      compute_islamic_civil_calendar_fields(
        bundle,
        locale_id,
        epoch_millis,
        zone_offset_millis,
      )
    False -> {
      let year_start_guess =
        float.truncate(
          { int.to_float(days) -. { 460_322.05 +. 0.5 } } /. 354.3672,
        )
        + umalqura_year_start_bound
        - 1
      let #(year, month, day_of_month) = umalqura_search(days, year_start_guess)
      let day_of_year = days - umalqura_month_start(year, 0) + 1

      let time_fields = gregoimp.time_to_fields(local_millis)
      let common =
        gregocal.compute_common_fields(
          bundle,
          locale_id,
          year,
          month,
          day_of_month,
          time_fields.dow,
          day_of_year,
          time_fields.millis_in_day,
          umalqura_year_length,
          None,
        )

      gregocal.CalendarFields(
        era: 0,
        year:,
        extended_year: year,
        common: gregocal.CommonFields(..common, day_of_month:, day_of_year:),
      )
    }
  }
}

fn umalqura_search(days: Int, year_guess: Int) -> #(Int, Int, Int) {
  umalqura_search_loop(days, year_guess, 1)
}

fn umalqura_search_loop(days: Int, year: Int, d: Int) -> #(Int, Int, Int) {
  case d > 0 {
    False -> #(year, 0, 0)
    True -> {
      let next_year = year + 1
      let d2 = days - umalqura_year_start(next_year) + 1
      let length = umalqura_year_length(next_year)
      case d2 == length {
        True -> #(next_year, 11, days - umalqura_month_start(next_year, 11) + 1)
        False ->
          case d2 < length {
            True -> {
              let #(month, day_of_month) =
                umalqura_search_month(next_year, 0, d2)
              #(next_year, month, day_of_month)
            }
            False -> umalqura_search_loop(days, next_year, d2)
          }
      }
    }
  }
}

fn umalqura_search_month(year: Int, month: Int, d: Int) -> #(Int, Int) {
  let month_len = umalqura_month_length(year, month)
  case d > month_len {
    True -> umalqura_search_month(year, month + 1, d - month_len)
    False -> #(month, d)
  }
}
