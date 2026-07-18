import argv
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/duration
import gleam/time/timestamp
import intldate
import intlrelative.{type Unit}
import prng/random
import simplifile

const default_count = 5000

pub fn main() {
  let count = case argv.load().arguments {
    [count_string, ..] ->
      case int.parse(count_string) {
        Ok(count) -> count
        Error(_) -> default_count
      }
    [] -> default_count
  }

  generate_format_tests(count)
  generate_format_range_tests(count)
  generate_format_parts_tests(count)
  generate_format_range_parts_tests(count)
  generate_resolved_options_tests(count)
  generate_relative_tests(count)
  generate_relative_parts_tests(count)
  generate_relative_resolved_options_tests(count)
}

const locales = [
  "fr-FR", "fr-CA", "en-US", "en-GB", "en-AU", "en-IN", "de-DE", "de-AT",
  "es-ES", "es-MX", "es-AR", "it-IT", "pt-BR", "pt-PT", "nl-NL", "sv-SE",
  "nb-NO", "da-DK", "fi-FI", "pl-PL", "cs-CZ", "ro-RO", "hu-HU", "tr-TR",
  "ru-RU", "uk-UA", "el-GR", "he-IL", "ar-SA", "ar-EG", "fa-IR", "hi-IN",
  "bn-BD", "th-TH", "vi-VN", "id-ID", "ms-MY", "ja-JP", "ko-KR", "zh-CN",
  "zh-TW", "zh-Hant-TW", "zh-Hans-CN", "mn-MN", "am-ET", "sw-KE", "ka-GE",
  "hy-AM", "km-KH", "ta-IN", "ur-PK", "sr-RS", "sr-Cyrl-RS", "sr-Latn-RS",
  "bg-BG", "hr-HR", "sk-SK", "sl-SI", "lt-LT", "lv-LV", "et-EE", "is-IS",
  "mt-MT", "ga-IE", "cy-GB", "th-TH-u-ca-buddhist", "ja-JP-u-ca-japanese",
  "zh-CN-u-ca-chinese", "he-IL-u-ca-hebrew", "en-US-u-hc-h12", "ar-SA-u-nu-arab",
]

const time_zones = [
  "UTC", "Europe/Paris", "Europe/London", "Europe/Moscow", "Europe/Istanbul",
  "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
  "America/Anchorage", "America/Sao_Paulo", "America/St_Johns",
  "America/Argentina/Buenos_Aires", "Pacific/Honolulu", "Pacific/Auckland",
  "Pacific/Chatham", "Pacific/Kiritimati", "Pacific/Marquesas", "Pacific/Niue",
  "Australia/Sydney", "Australia/Lord_Howe", "Australia/Eucla", "Asia/Tokyo",
  "Asia/Shanghai", "Asia/Kolkata", "Asia/Kathmandu", "Asia/Yangon",
  "Asia/Tehran", "Asia/Dubai", "Asia/Jerusalem", "Africa/Johannesburg",
  "Africa/Cairo", "Africa/Casablanca", "Indian/Reunion", "Atlantic/Azores",
  "Antarctica/Troll",
]

const min_unix_seconds = -2_208_988_800

const max_unix_seconds = 4_102_444_800

const max_range_duration_seconds = 94_672_800

fn pick(options: List(a)) -> random.Generator(a) {
  let assert Ok(generator) = random.try_uniform(options)
  generator
}

fn maybe(
  generator: random.Generator(a),
  probability: Float,
) -> random.Generator(Option(a)) {
  use roll <- random.then(random.float(0.0, 1.0))
  case roll <. probability {
    True -> random.map(generator, Some)
    False -> random.constant(None)
  }
}

fn make_seed(salt: Int) -> random.Seed {
  let #(seconds, nanoseconds) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds
  random.new_seed(seconds * 1_000_000_000 + nanoseconds + salt)
}

fn write_json_file(path: String, value: json.Json) -> Nil {
  let assert Ok(_) = simplifile.create_directory_all("test")
  let assert Ok(_) = simplifile.write(to: path, contents: json.to_string(value))
  Nil
}

fn timestamp_generator() -> random.Generator(timestamp.Timestamp) {
  random.map(
    random.int(min_unix_seconds, max_unix_seconds),
    timestamp.from_unix_seconds,
  )
}

fn range_generator() -> random.Generator(
  #(timestamp.Timestamp, timestamp.Timestamp),
) {
  use start <- random.then(timestamp_generator())
  use offset_seconds <- random.then(random.int(0, max_range_duration_seconds))
  random.constant(#(
    start,
    timestamp.add(start, duration.seconds(offset_seconds)),
  ))
}

fn locale_matcher_generator() -> random.Generator(intldate.LocaleMatcher) {
  pick([intldate.LocaleMatcherBestFit, intldate.LocaleMatcherLookup])
}

fn calendar_generator() -> random.Generator(intldate.Calendar) {
  pick([
    intldate.CalendarGregory,
    intldate.CalendarBuddhist,
    intldate.CalendarChinese,
    intldate.CalendarCoptic,
    intldate.CalendarDangi,
    intldate.CalendarEthioaa,
    intldate.CalendarEthiopic,
    intldate.CalendarHebrew,
    intldate.CalendarIndian,
    intldate.CalendarIslamic,
    intldate.CalendarIslamicUmalqura,
    intldate.CalendarIslamicTbla,
    intldate.CalendarIslamicCivil,
    intldate.CalendarIslamicRgsa,
    intldate.CalendarIso8601,
    intldate.CalendarJapanese,
    intldate.CalendarPersian,
    intldate.CalendarRoc,
  ])
}

fn weekday_generator() -> random.Generator(intldate.Weekday) {
  pick([intldate.WeekdayLong, intldate.WeekdayShort, intldate.WeekdayNarrow])
}

fn era_generator() -> random.Generator(intldate.Era) {
  pick([intldate.EraLong, intldate.EraShort, intldate.EraNarrow])
}

fn year_generator() -> random.Generator(intldate.Year) {
  pick([intldate.YearNumeric, intldate.Year2Digit])
}

fn month_generator() -> random.Generator(intldate.Month) {
  pick([
    intldate.MonthNumeric,
    intldate.Month2Digit,
    intldate.MonthLong,
    intldate.MonthShort,
    intldate.MonthNarrow,
  ])
}

fn day_generator() -> random.Generator(intldate.Day) {
  pick([intldate.DayNumeric, intldate.Day2Digit])
}

fn hour_generator() -> random.Generator(intldate.Hour) {
  pick([intldate.HourNumeric, intldate.Hour2Digit])
}

fn minute_generator() -> random.Generator(intldate.Minute) {
  pick([intldate.MinuteNumeric, intldate.Minute2Digit])
}

fn second_generator() -> random.Generator(intldate.Second) {
  pick([intldate.SecondNumeric, intldate.Second2Digit])
}

fn time_zone_name_generator() -> random.Generator(intldate.TimeZoneName) {
  pick([
    intldate.TimeZoneNameShort,
    intldate.TimeZoneNameLong,
    intldate.TimeZoneNameShortOffset,
    intldate.TimeZoneNameLongOffset,
    intldate.TimeZoneNameShortGeneric,
    intldate.TimeZoneNameLongGeneric,
  ])
}

fn format_matcher_generator() -> random.Generator(intldate.FormatMatcher) {
  pick([intldate.FormatMatcherBestFit, intldate.FormatMatcherBasic])
}

fn date_time_format_config_generator() -> random.Generator(
  intldate.DateTimeFormatConfig,
) {
  use density <- random.then(random.float(0.02, 0.98))
  use locale_matcher <- random.then(maybe(locale_matcher_generator(), density))
  use calendar <- random.then(maybe(calendar_generator(), density))
  use weekday <- random.then(maybe(weekday_generator(), density))
  use era <- random.then(maybe(era_generator(), density *. 0.5))
  use year <- random.then(maybe(year_generator(), density))
  use month <- random.then(maybe(month_generator(), density))
  use day <- random.then(maybe(day_generator(), density))
  use hour <- random.then(maybe(hour_generator(), density))
  use minute <- random.then(maybe(minute_generator(), density))
  use second <- random.then(maybe(second_generator(), density *. 0.8))
  use time_zone_name <- random.then(maybe(
    time_zone_name_generator(),
    density *. 0.7,
  ))
  use format_matcher <- random.then(maybe(format_matcher_generator(), density))
  use hour12 <- random.then(maybe(random.choose(True, False), density))

  random.constant(
    intldate.new()
    |> apply(locale_matcher, intldate.with_locale_matcher)
    |> apply(calendar, intldate.with_calendar)
    |> apply(weekday, intldate.with_weekday)
    |> apply(era, intldate.with_era)
    |> apply(year, intldate.with_year)
    |> apply(month, intldate.with_month)
    |> apply(day, intldate.with_day)
    |> apply(hour, intldate.with_hour)
    |> apply(minute, intldate.with_minute)
    |> apply(second, intldate.with_second)
    |> apply(time_zone_name, intldate.with_time_zone_name)
    |> apply(format_matcher, intldate.with_format_matcher)
    |> apply(hour12, intldate.with_hour12),
  )
}

fn relative_locale_matcher_generator() -> random.Generator(
  intlrelative.LocaleMatcher,
) {
  pick([intlrelative.LocaleMatcherBestFit, intlrelative.LocaleMatcherLookup])
}

fn relative_style_generator() -> random.Generator(intlrelative.Style) {
  pick([intlrelative.Long, intlrelative.Short, intlrelative.Narrow])
}

fn relative_numeric_generator() -> random.Generator(intlrelative.Numeric) {
  pick([intlrelative.Always, intlrelative.Auto])
}

fn relative_unit_generator() -> random.Generator(Unit) {
  pick([
    intlrelative.Second,
    intlrelative.Minute,
    intlrelative.Hour,
    intlrelative.Day,
    intlrelative.Week,
    intlrelative.Month,
    intlrelative.Quarter,
    intlrelative.Year,
  ])
}

fn relative_unit_seconds(unit: Unit) -> Int {
  case unit {
    intlrelative.Second -> 1
    intlrelative.Minute -> 60
    intlrelative.Hour -> 3600
    intlrelative.Day -> 86_400
    intlrelative.Week -> 604_800
    intlrelative.Month -> 2_629_746
    intlrelative.Quarter -> 7_889_238
    intlrelative.Year -> 31_556_952
  }
}

fn relative_time_format_config_generator() -> random.Generator(
  intlrelative.RelativeTimeFormatConfig,
) {
  use density <- random.then(random.float(0.02, 0.98))
  use locale_matcher <- random.then(maybe(
    relative_locale_matcher_generator(),
    density,
  ))
  use style <- random.then(maybe(relative_style_generator(), density))
  use numeric <- random.then(maybe(relative_numeric_generator(), density))

  random.constant(
    intlrelative.new()
    |> relative_apply(locale_matcher, intlrelative.with_locale_matcher)
    |> relative_apply(style, intlrelative.with_style)
    |> relative_apply(numeric, intlrelative.with_numeric),
  )
}

fn format_test_case_generator() -> random.Generator(FormatTestCase) {
  use date <- random.then(timestamp_generator())
  use locale <- random.then(pick(locales))
  use time_zone <- random.then(pick(time_zones))
  use config <- random.then(date_time_format_config_generator())

  let date_string = timestamp.to_rfc3339(date, duration.seconds(0))

  let expected = case
    intldate.try_format(
      date:,
      time_zone: Some(time_zone),
      locale: Some(locale),
      config:,
    )
  {
    Ok(value) -> ExpectResult(value)
    Error(error) -> ExpectError(intldate.describe_error(error))
  }

  random.constant(FormatTestCase(
    date: date_string,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub fn generate_format_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(format_test_case_generator(), count),
      make_seed(1),
    )
  write_json_file(
    "test/format.json",
    json.array(cases, format_test_case_to_json),
  )
  io.println("Generated " <> int.to_string(count) <> " format test cases.")
}

fn format_range_test_case_generator() -> random.Generator(FormatRangeTestCase) {
  use range <- random.then(range_generator())
  let #(date_start, date_end) = range
  use locale <- random.then(pick(locales))
  use time_zone <- random.then(pick(time_zones))
  use config <- random.then(date_time_format_config_generator())

  let date_start_string = timestamp.to_rfc3339(date_start, duration.seconds(0))
  let date_end_string = timestamp.to_rfc3339(date_end, duration.seconds(0))

  let expected = case
    intldate.try_format_range(
      date_start:,
      date_end:,
      time_zone: Some(time_zone),
      locale: Some(locale),
      config:,
    )
  {
    Ok(value) -> ExpectResult(value)
    Error(error) -> ExpectError(intldate.describe_error(error))
  }

  random.constant(FormatRangeTestCase(
    date_start: date_start_string,
    date_end: date_end_string,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub fn generate_format_range_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(format_range_test_case_generator(), count),
      make_seed(2),
    )
  write_json_file(
    "test/format_range.json",
    json.array(cases, format_range_test_case_to_json),
  )
  io.println(
    "Generated " <> int.to_string(count) <> " format range test cases.",
  )
}

fn format_parts_test_case_generator() -> random.Generator(FormatPartsTestCase) {
  use date <- random.then(timestamp_generator())
  use locale <- random.then(pick(locales))
  use time_zone <- random.then(pick(time_zones))
  use config <- random.then(date_time_format_config_generator())

  let date_string = timestamp.to_rfc3339(date, duration.seconds(0))

  let expected = case
    intldate.try_format_to_parts(
      date:,
      time_zone: Some(time_zone),
      locale: Some(locale),
      config:,
    )
  {
    Ok(parts) -> ExpectParts(parts)
    Error(error) -> ExpectPartsError(intldate.describe_error(error))
  }

  random.constant(FormatPartsTestCase(
    date: date_string,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub fn generate_format_parts_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(format_parts_test_case_generator(), count),
      make_seed(3),
    )
  write_json_file(
    "test/format_parts.json",
    json.array(cases, format_parts_test_case_to_json),
  )
  io.println(
    "Generated " <> int.to_string(count) <> " format parts test cases.",
  )
}

fn format_range_parts_test_case_generator() -> random.Generator(
  FormatRangePartsTestCase,
) {
  use range <- random.then(range_generator())
  let #(date_start, date_end) = range
  use locale <- random.then(pick(locales))
  use time_zone <- random.then(pick(time_zones))
  use config <- random.then(date_time_format_config_generator())

  let date_start_string = timestamp.to_rfc3339(date_start, duration.seconds(0))
  let date_end_string = timestamp.to_rfc3339(date_end, duration.seconds(0))

  let expected = case
    intldate.try_format_range_to_parts(
      date_start:,
      date_end:,
      time_zone: Some(time_zone),
      locale: Some(locale),
      config:,
    )
  {
    Ok(parts) -> ExpectParts(parts)
    Error(error) -> ExpectPartsError(intldate.describe_error(error))
  }

  random.constant(FormatRangePartsTestCase(
    date_start: date_start_string,
    date_end: date_end_string,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub fn generate_format_range_parts_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(format_range_parts_test_case_generator(), count),
      make_seed(4),
    )
  write_json_file(
    "test/format_range_parts.json",
    json.array(cases, format_range_parts_test_case_to_json),
  )
  io.println(
    "Generated " <> int.to_string(count) <> " format range parts test cases.",
  )
}

fn resolved_options_test_case_generator() -> random.Generator(
  ResolvedOptionsTestCase,
) {
  use locale <- random.then(pick(locales))
  use time_zone <- random.then(pick(time_zones))
  use config <- random.then(date_time_format_config_generator())

  let expected = case
    intldate.resolved_options(
      time_zone: Some(time_zone),
      locale: Some(locale),
      config:,
    )
  {
    Ok(options) -> ExpectOptions(options)
    Error(error) -> ExpectOptionsError(intldate.describe_error(error))
  }

  random.constant(ResolvedOptionsTestCase(
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub fn generate_resolved_options_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(resolved_options_test_case_generator(), count),
      make_seed(5),
    )
  write_json_file(
    "test/resolved_options.json",
    json.array(cases, resolved_options_test_case_to_json),
  )
  io.println(
    "Generated " <> int.to_string(count) <> " resolved options test cases.",
  )
}

fn relative_format_test_case_generator() -> random.Generator(
  RelativeFormatTestCase,
) {
  use value <- random.then(random.int(-99_999, 99_999))
  use unit <- random.then(relative_unit_generator())
  use locale <- random.then(pick(locales))
  use config <- random.then(relative_time_format_config_generator())

  let duration_value = duration.seconds(value * relative_unit_seconds(unit))

  let expected = case
    intlrelative.try_format(
      duration: duration_value,
      unit:,
      locale: Some(locale),
      config:,
    )
  {
    Ok(text) -> ExpectResult(text)
    Error(error) -> ExpectError(intlrelative.describe_error(error))
  }

  random.constant(RelativeFormatTestCase(
    value:,
    unit:,
    locale:,
    config:,
    expected:,
  ))
}

pub fn generate_relative_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(relative_format_test_case_generator(), count),
      make_seed(6),
    )
  write_json_file(
    "test/relative.json",
    json.array(cases, relative_format_test_case_to_json),
  )
  io.println("Generated " <> int.to_string(count) <> " relative test cases.")
}

fn relative_parts_test_case_generator() -> random.Generator(
  RelativePartsTestCase,
) {
  use value <- random.then(random.int(-99_999, 99_999))
  use unit <- random.then(relative_unit_generator())
  use locale <- random.then(pick(locales))
  use config <- random.then(relative_time_format_config_generator())

  let duration_value = duration.seconds(value * relative_unit_seconds(unit))

  let expected = case
    intlrelative.try_format_to_parts(
      duration: duration_value,
      unit:,
      locale: Some(locale),
      config:,
    )
  {
    Ok(parts) -> ExpectRelativeParts(parts)
    Error(error) -> ExpectRelativePartsError(intlrelative.describe_error(error))
  }

  random.constant(RelativePartsTestCase(
    value:,
    unit:,
    locale:,
    config:,
    expected:,
  ))
}

pub fn generate_relative_parts_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(relative_parts_test_case_generator(), count),
      make_seed(7),
    )
  write_json_file(
    "test/relative_parts.json",
    json.array(cases, relative_parts_test_case_to_json),
  )
  io.println(
    "Generated " <> int.to_string(count) <> " relative parts test cases.",
  )
}

fn relative_resolved_options_test_case_generator() -> random.Generator(
  RelativeResolvedOptionsTestCase,
) {
  use locale <- random.then(pick(locales))
  use config <- random.then(relative_time_format_config_generator())

  let expected = case
    intlrelative.resolved_options(locale: Some(locale), config:)
  {
    Ok(options) -> ExpectRelativeOptions(options)
    Error(error) ->
      ExpectRelativeOptionsError(intlrelative.describe_error(error))
  }

  random.constant(RelativeResolvedOptionsTestCase(locale:, config:, expected:))
}

pub fn generate_relative_resolved_options_tests(count: Int) -> Nil {
  let #(cases, _) =
    random.step(
      random.fixed_size_list(
        relative_resolved_options_test_case_generator(),
        count,
      ),
      make_seed(8),
    )
  write_json_file(
    "test/relative_resolved_options.json",
    json.array(cases, relative_resolved_options_test_case_to_json),
  )
  io.println(
    "Generated "
    <> int.to_string(count)
    <> " relative resolved options test cases.",
  )
}

pub type Expected {
  ExpectResult(String)
  ExpectError(String)
}

fn expected_to_json(expected: Expected) -> json.Json {
  case expected {
    ExpectResult(value) ->
      json.object([#("t", json.string("r")), #("v", json.string(value))])
    ExpectError(value) ->
      json.object([#("t", json.string("e")), #("v", json.string(value))])
  }
}

fn expected_decoder() -> decode.Decoder(Expected) {
  use tag <- decode.field("t", decode.string)
  case tag {
    "r" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectResult(value))
    }
    "e" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectError(value))
    }
    _ -> decode.failure(ExpectResult(""), "Expected")
  }
}

fn expected_parts_to_json(expected: ExpectedParts) -> json.Json {
  case expected {
    ExpectParts(value) ->
      json.object([
        #("t", json.string("r")),
        #("v", json.array(value, date_time_part_to_json)),
      ])
    ExpectPartsError(value) ->
      json.object([#("t", json.string("e")), #("v", json.string(value))])
  }
}

fn expected_parts_decoder() -> decode.Decoder(ExpectedParts) {
  use tag <- decode.field("t", decode.string)
  case tag {
    "r" -> {
      use value <- decode.field("v", decode.list(date_time_part_decoder()))
      decode.success(ExpectParts(value))
    }
    "e" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectPartsError(value))
    }
    _ -> decode.failure(ExpectParts([]), "ExpectedParts")
  }
}

fn expected_options_to_json(expected: ExpectedOptions) -> json.Json {
  case expected {
    ExpectOptions(value) ->
      json.object([
        #("t", json.string("r")),
        #("v", date_time_resolved_options_to_json(value)),
      ])
    ExpectOptionsError(value) ->
      json.object([#("t", json.string("e")), #("v", json.string(value))])
  }
}

fn expected_options_decoder() -> decode.Decoder(ExpectedOptions) {
  use tag <- decode.field("t", decode.string)
  case tag {
    "r" -> {
      use value <- decode.field("v", date_time_resolved_options_decoder())
      decode.success(ExpectOptions(value))
    }
    "e" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectOptionsError(value))
    }
    _ ->
      decode.failure(
        ExpectOptions(intldate.DateTimeResolvedOptions(
          "",
          "",
          "",
          "",
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
          None,
        )),
        "ExpectedOptions",
      )
  }
}

fn expected_relative_parts_to_json(
  expected: ExpectedRelativeParts,
) -> json.Json {
  case expected {
    ExpectRelativeParts(value) ->
      json.object([
        #("t", json.string("r")),
        #("v", json.array(value, relative_time_format_part_to_json)),
      ])
    ExpectRelativePartsError(value) ->
      json.object([#("t", json.string("e")), #("v", json.string(value))])
  }
}

fn expected_relative_parts_decoder() -> decode.Decoder(ExpectedRelativeParts) {
  use tag <- decode.field("t", decode.string)
  case tag {
    "r" -> {
      use value <- decode.field(
        "v",
        decode.list(relative_time_format_part_decoder()),
      )
      decode.success(ExpectRelativeParts(value))
    }
    "e" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectRelativePartsError(value))
    }
    _ -> decode.failure(ExpectRelativeParts([]), "ExpectedRelativeParts")
  }
}

fn expected_relative_options_to_json(
  expected: ExpectedRelativeOptions,
) -> json.Json {
  case expected {
    ExpectRelativeOptions(value) ->
      json.object([
        #("t", json.string("r")),
        #("v", relative_resolved_options_to_json(value)),
      ])
    ExpectRelativeOptionsError(value) ->
      json.object([#("t", json.string("e")), #("v", json.string(value))])
  }
}

fn expected_relative_options_decoder() -> decode.Decoder(
  ExpectedRelativeOptions,
) {
  use tag <- decode.field("t", decode.string)
  case tag {
    "r" -> {
      use value <- decode.field("v", relative_resolved_options_decoder())
      decode.success(ExpectRelativeOptions(value))
    }
    "e" -> {
      use value <- decode.field("v", decode.string)
      decode.success(ExpectRelativeOptionsError(value))
    }
    _ ->
      decode.failure(
        ExpectRelativeOptions(intlrelative.RelativeTimeResolvedOptions(
          "",
          "",
          "",
          "",
        )),
        "ExpectedRelativeOptions",
      )
  }
}

pub type FormatTestCase {
  FormatTestCase(
    date: String,
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: Expected,
  )
}

pub fn format_test_case_to_json(test_case: FormatTestCase) -> json.Json {
  json.object([
    #("d", json.string(test_case.date)),
    #("l", json.string(test_case.locale)),
    #("z", json.string(test_case.time_zone)),
    #("c", date_time_format_config_to_json(test_case.config)),
    #("r", expected_to_json(test_case.expected)),
  ])
}

pub fn format_test_case_decoder() -> decode.Decoder(FormatTestCase) {
  use date <- decode.field("d", decode.string)
  use locale <- decode.field("l", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use config <- decode.field("c", date_time_format_config_decoder())
  use expected <- decode.field("r", expected_decoder())

  decode.success(FormatTestCase(date:, locale:, time_zone:, config:, expected:))
}

fn option_to_json(value: Option(a), to_json: fn(a) -> json.Json) -> json.Json {
  case value {
    Some(value) -> to_json(value)
    None -> json.null()
  }
}

fn optional_json_field(
  key: String,
  value: Option(a),
  to_json: fn(a) -> json.Json,
) -> List(#(String, json.Json)) {
  case value {
    Some(value) -> [#(key, to_json(value))]
    None -> []
  }
}

fn date_time_format_config_to_json(
  config: intldate.DateTimeFormatConfig,
) -> json.Json {
  json.object(
    [
      #("m", option_to_json(config.locale_matcher, locale_matcher_to_json)),
      #("c", option_to_json(config.calendar, calendar_to_json)),
      #("w", option_to_json(config.weekday, weekday_to_json)),
      #("e", option_to_json(config.era, era_to_json)),
      #("y", option_to_json(config.year, year_to_json)),
      #("o", option_to_json(config.month, month_to_json)),
      #("d", option_to_json(config.day, day_to_json)),
      #("h", option_to_json(config.hour, hour_to_json)),
      #("i", option_to_json(config.minute, minute_to_json)),
      #("s", option_to_json(config.second, second_to_json)),
      #("z", option_to_json(config.time_zone_name, time_zone_name_to_json)),
      #("f", option_to_json(config.format_matcher, format_matcher_to_json)),
    ]
    |> list.append(optional_json_field("b", config.hour12, json.bool)),
  )
}

fn date_time_format_config_decoder() -> decode.Decoder(
  intldate.DateTimeFormatConfig,
) {
  use locale_matcher <- decode.optional_field(
    "m",
    None,
    decode.optional(locale_matcher_decoder()),
  )
  use calendar <- decode.optional_field(
    "c",
    None,
    decode.optional(calendar_decoder()),
  )
  use weekday <- decode.optional_field(
    "w",
    None,
    decode.optional(weekday_decoder()),
  )
  use era <- decode.optional_field("e", None, decode.optional(era_decoder()))
  use year <- decode.optional_field("y", None, decode.optional(year_decoder()))
  use month <- decode.optional_field(
    "o",
    None,
    decode.optional(month_decoder()),
  )
  use day <- decode.optional_field("d", None, decode.optional(day_decoder()))
  use hour <- decode.optional_field("h", None, decode.optional(hour_decoder()))
  use minute <- decode.optional_field(
    "i",
    None,
    decode.optional(minute_decoder()),
  )
  use second <- decode.optional_field(
    "s",
    None,
    decode.optional(second_decoder()),
  )
  use time_zone_name <- decode.optional_field(
    "z",
    None,
    decode.optional(time_zone_name_decoder()),
  )
  use format_matcher <- decode.optional_field(
    "f",
    None,
    decode.optional(format_matcher_decoder()),
  )
  use hour12 <- decode.optional_field("b", None, decode.map(decode.bool, Some))

  let config =
    intldate.new()
    |> apply(locale_matcher, intldate.with_locale_matcher)
    |> apply(calendar, intldate.with_calendar)
    |> apply(weekday, intldate.with_weekday)
    |> apply(era, intldate.with_era)
    |> apply(year, intldate.with_year)
    |> apply(month, intldate.with_month)
    |> apply(day, intldate.with_day)
    |> apply(hour, intldate.with_hour)
    |> apply(minute, intldate.with_minute)
    |> apply(second, intldate.with_second)
    |> apply(time_zone_name, intldate.with_time_zone_name)
    |> apply(format_matcher, intldate.with_format_matcher)
    |> apply(hour12, intldate.with_hour12)

  decode.success(config)
}

fn apply(
  config: intldate.DateTimeFormatConfig,
  value: Option(a),
  with: fn(intldate.DateTimeFormatConfig, a) -> intldate.DateTimeFormatConfig,
) -> intldate.DateTimeFormatConfig {
  case value {
    Some(value) -> with(config, value)
    None -> config
  }
}

fn locale_matcher_to_json(locale_matcher: intldate.LocaleMatcher) -> json.Json {
  case locale_matcher {
    intldate.LocaleMatcherBestFit -> json.string("b")
    intldate.LocaleMatcherLookup -> json.string("l")
  }
}

fn locale_matcher_decoder() -> decode.Decoder(intldate.LocaleMatcher) {
  use variant <- decode.then(decode.string)
  case variant {
    "b" -> decode.success(intldate.LocaleMatcherBestFit)
    "l" -> decode.success(intldate.LocaleMatcherLookup)
    _ -> decode.failure(intldate.LocaleMatcherBestFit, "LocaleMatcher")
  }
}

fn calendar_to_json(calendar: intldate.Calendar) -> json.Json {
  case calendar {
    intldate.CalendarBuddhist -> json.string("b")
    intldate.CalendarChinese -> json.string("c")
    intldate.CalendarCoptic -> json.string("o")
    intldate.CalendarDangi -> json.string("d")
    intldate.CalendarEthioaa -> json.string("a")
    intldate.CalendarEthiopic -> json.string("e")
    intldate.CalendarGregory -> json.string("g")
    intldate.CalendarHebrew -> json.string("h")
    intldate.CalendarIndian -> json.string("i")
    intldate.CalendarIslamic -> json.string("s")
    intldate.CalendarIslamicUmalqura -> json.string("u")
    intldate.CalendarIslamicTbla -> json.string("t")
    intldate.CalendarIslamicCivil -> json.string("v")
    intldate.CalendarIslamicRgsa -> json.string("r")
    intldate.CalendarIso8601 -> json.string("8")
    intldate.CalendarJapanese -> json.string("j")
    intldate.CalendarPersian -> json.string("p")
    intldate.CalendarRoc -> json.string("k")
  }
}

fn calendar_decoder() -> decode.Decoder(intldate.Calendar) {
  use variant <- decode.then(decode.string)
  case variant {
    "b" -> decode.success(intldate.CalendarBuddhist)
    "c" -> decode.success(intldate.CalendarChinese)
    "o" -> decode.success(intldate.CalendarCoptic)
    "d" -> decode.success(intldate.CalendarDangi)
    "a" -> decode.success(intldate.CalendarEthioaa)
    "e" -> decode.success(intldate.CalendarEthiopic)
    "g" -> decode.success(intldate.CalendarGregory)
    "h" -> decode.success(intldate.CalendarHebrew)
    "i" -> decode.success(intldate.CalendarIndian)
    "s" -> decode.success(intldate.CalendarIslamic)
    "u" -> decode.success(intldate.CalendarIslamicUmalqura)
    "t" -> decode.success(intldate.CalendarIslamicTbla)
    "v" -> decode.success(intldate.CalendarIslamicCivil)
    "r" -> decode.success(intldate.CalendarIslamicRgsa)
    "8" -> decode.success(intldate.CalendarIso8601)
    "j" -> decode.success(intldate.CalendarJapanese)
    "p" -> decode.success(intldate.CalendarPersian)
    "k" -> decode.success(intldate.CalendarRoc)
    _ -> decode.failure(intldate.CalendarBuddhist, "Calendar")
  }
}

fn weekday_to_json(weekday: intldate.Weekday) -> json.Json {
  case weekday {
    intldate.WeekdayLong -> json.string("l")
    intldate.WeekdayShort -> json.string("s")
    intldate.WeekdayNarrow -> json.string("n")
  }
}

fn weekday_decoder() -> decode.Decoder(intldate.Weekday) {
  use variant <- decode.then(decode.string)
  case variant {
    "l" -> decode.success(intldate.WeekdayLong)
    "s" -> decode.success(intldate.WeekdayShort)
    "n" -> decode.success(intldate.WeekdayNarrow)
    _ -> decode.failure(intldate.WeekdayLong, "Weekday")
  }
}

fn era_to_json(era: intldate.Era) -> json.Json {
  case era {
    intldate.EraLong -> json.string("l")
    intldate.EraShort -> json.string("s")
    intldate.EraNarrow -> json.string("n")
  }
}

fn era_decoder() -> decode.Decoder(intldate.Era) {
  use variant <- decode.then(decode.string)
  case variant {
    "l" -> decode.success(intldate.EraLong)
    "s" -> decode.success(intldate.EraShort)
    "n" -> decode.success(intldate.EraNarrow)
    _ -> decode.failure(intldate.EraLong, "Era")
  }
}

fn year_to_json(year: intldate.Year) -> json.Json {
  case year {
    intldate.YearNumeric -> json.string("n")
    intldate.Year2Digit -> json.string("2")
  }
}

fn year_decoder() -> decode.Decoder(intldate.Year) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.YearNumeric)
    "2" -> decode.success(intldate.Year2Digit)
    _ -> decode.failure(intldate.YearNumeric, "Year")
  }
}

fn month_to_json(month: intldate.Month) -> json.Json {
  case month {
    intldate.MonthNumeric -> json.string("n")
    intldate.Month2Digit -> json.string("2")
    intldate.MonthLong -> json.string("l")
    intldate.MonthShort -> json.string("s")
    intldate.MonthNarrow -> json.string("a")
  }
}

fn month_decoder() -> decode.Decoder(intldate.Month) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.MonthNumeric)
    "2" -> decode.success(intldate.Month2Digit)
    "l" -> decode.success(intldate.MonthLong)
    "s" -> decode.success(intldate.MonthShort)
    "a" -> decode.success(intldate.MonthNarrow)
    _ -> decode.failure(intldate.MonthNumeric, "Month")
  }
}

fn day_to_json(day: intldate.Day) -> json.Json {
  case day {
    intldate.DayNumeric -> json.string("n")
    intldate.Day2Digit -> json.string("2")
  }
}

fn day_decoder() -> decode.Decoder(intldate.Day) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.DayNumeric)
    "2" -> decode.success(intldate.Day2Digit)
    _ -> decode.failure(intldate.DayNumeric, "Day")
  }
}

fn hour_to_json(hour: intldate.Hour) -> json.Json {
  case hour {
    intldate.HourNumeric -> json.string("n")
    intldate.Hour2Digit -> json.string("2")
  }
}

fn hour_decoder() -> decode.Decoder(intldate.Hour) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.HourNumeric)
    "2" -> decode.success(intldate.Hour2Digit)
    _ -> decode.failure(intldate.HourNumeric, "Hour")
  }
}

fn minute_to_json(minute: intldate.Minute) -> json.Json {
  case minute {
    intldate.MinuteNumeric -> json.string("n")
    intldate.Minute2Digit -> json.string("2")
  }
}

fn minute_decoder() -> decode.Decoder(intldate.Minute) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.MinuteNumeric)
    "2" -> decode.success(intldate.Minute2Digit)
    _ -> decode.failure(intldate.MinuteNumeric, "Minute")
  }
}

fn second_to_json(second: intldate.Second) -> json.Json {
  case second {
    intldate.SecondNumeric -> json.string("n")
    intldate.Second2Digit -> json.string("2")
  }
}

fn second_decoder() -> decode.Decoder(intldate.Second) {
  use variant <- decode.then(decode.string)
  case variant {
    "n" -> decode.success(intldate.SecondNumeric)
    "2" -> decode.success(intldate.Second2Digit)
    _ -> decode.failure(intldate.SecondNumeric, "Second")
  }
}

fn time_zone_name_to_json(time_zone_name: intldate.TimeZoneName) -> json.Json {
  case time_zone_name {
    intldate.TimeZoneNameShort -> json.string("s")
    intldate.TimeZoneNameLong -> json.string("l")
    intldate.TimeZoneNameShortOffset -> json.string("o")
    intldate.TimeZoneNameLongOffset -> json.string("f")
    intldate.TimeZoneNameShortGeneric -> json.string("g")
    intldate.TimeZoneNameLongGeneric -> json.string("e")
  }
}

fn time_zone_name_decoder() -> decode.Decoder(intldate.TimeZoneName) {
  use variant <- decode.then(decode.string)
  case variant {
    "s" -> decode.success(intldate.TimeZoneNameShort)
    "l" -> decode.success(intldate.TimeZoneNameLong)
    "o" -> decode.success(intldate.TimeZoneNameShortOffset)
    "f" -> decode.success(intldate.TimeZoneNameLongOffset)
    "g" -> decode.success(intldate.TimeZoneNameShortGeneric)
    "e" -> decode.success(intldate.TimeZoneNameLongGeneric)
    _ -> decode.failure(intldate.TimeZoneNameShort, "TimeZoneName")
  }
}

fn format_matcher_to_json(format_matcher: intldate.FormatMatcher) -> json.Json {
  case format_matcher {
    intldate.FormatMatcherBestFit -> json.string("b")
    intldate.FormatMatcherBasic -> json.string("a")
  }
}

fn format_matcher_decoder() -> decode.Decoder(intldate.FormatMatcher) {
  use variant <- decode.then(decode.string)
  case variant {
    "b" -> decode.success(intldate.FormatMatcherBestFit)
    "a" -> decode.success(intldate.FormatMatcherBasic)
    _ -> decode.failure(intldate.FormatMatcherBestFit, "FormatMatcher")
  }
}

pub type ExpectedParts {
  ExpectParts(List(intldate.DateTimeFormatPart))
  ExpectPartsError(String)
}

pub type ExpectedOptions {
  ExpectOptions(intldate.DateTimeResolvedOptions)
  ExpectOptionsError(String)
}

pub type FormatRangeTestCase {
  FormatRangeTestCase(
    date_start: String,
    date_end: String,
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: Expected,
  )
}

pub fn format_range_test_case_to_json(
  test_case: FormatRangeTestCase,
) -> json.Json {
  json.object([
    #("s", json.string(test_case.date_start)),
    #("e", json.string(test_case.date_end)),
    #("l", json.string(test_case.locale)),
    #("z", json.string(test_case.time_zone)),
    #("c", date_time_format_config_to_json(test_case.config)),
    #("r", expected_to_json(test_case.expected)),
  ])
}

pub fn format_range_test_case_decoder() -> decode.Decoder(FormatRangeTestCase) {
  use date_start <- decode.field("s", decode.string)
  use date_end <- decode.field("e", decode.string)
  use locale <- decode.field("l", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use config <- decode.field("c", date_time_format_config_decoder())
  use expected <- decode.field("r", expected_decoder())

  decode.success(FormatRangeTestCase(
    date_start:,
    date_end:,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub type FormatPartsTestCase {
  FormatPartsTestCase(
    date: String,
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: ExpectedParts,
  )
}

pub fn format_parts_test_case_to_json(
  test_case: FormatPartsTestCase,
) -> json.Json {
  json.object([
    #("d", json.string(test_case.date)),
    #("l", json.string(test_case.locale)),
    #("z", json.string(test_case.time_zone)),
    #("c", date_time_format_config_to_json(test_case.config)),
    #("r", expected_parts_to_json(test_case.expected)),
  ])
}

pub fn format_parts_test_case_decoder() -> decode.Decoder(FormatPartsTestCase) {
  use date <- decode.field("d", decode.string)
  use locale <- decode.field("l", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use config <- decode.field("c", date_time_format_config_decoder())
  use expected <- decode.field("r", expected_parts_decoder())

  decode.success(FormatPartsTestCase(
    date:,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

pub type FormatRangePartsTestCase {
  FormatRangePartsTestCase(
    date_start: String,
    date_end: String,
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: ExpectedParts,
  )
}

pub fn format_range_parts_test_case_to_json(
  test_case: FormatRangePartsTestCase,
) -> json.Json {
  json.object([
    #("s", json.string(test_case.date_start)),
    #("e", json.string(test_case.date_end)),
    #("l", json.string(test_case.locale)),
    #("z", json.string(test_case.time_zone)),
    #("c", date_time_format_config_to_json(test_case.config)),
    #("r", expected_parts_to_json(test_case.expected)),
  ])
}

pub fn format_range_parts_test_case_decoder() -> decode.Decoder(
  FormatRangePartsTestCase,
) {
  use date_start <- decode.field("s", decode.string)
  use date_end <- decode.field("e", decode.string)
  use locale <- decode.field("l", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use config <- decode.field("c", date_time_format_config_decoder())
  use expected <- decode.field("r", expected_parts_decoder())

  decode.success(FormatRangePartsTestCase(
    date_start:,
    date_end:,
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

fn date_time_part_to_json(part: intldate.DateTimeFormatPart) -> json.Json {
  json.object([
    #("t", date_time_part_kind_to_json(part.kind)),
    #("v", json.string(part.value)),
    #("s", date_time_part_source_to_json(part.source)),
  ])
}

fn date_time_part_decoder() -> decode.Decoder(intldate.DateTimeFormatPart) {
  use kind <- decode.field("t", date_time_part_kind_decoder())
  use value <- decode.field("v", decode.string)
  use source <- decode.optional_field(
    "s",
    intldate.DateTimePartSourceNone,
    date_time_part_source_decoder(),
  )

  decode.success(intldate.DateTimeFormatPart(kind:, value:, source:))
}

fn date_time_part_kind_to_json(kind: intldate.DateTimePartKind) -> json.Json {
  case kind {
    intldate.DateTimePartLiteral -> json.string("l")
    intldate.DateTimePartWeekday -> json.string("w")
    intldate.DateTimePartEra -> json.string("e")
    intldate.DateTimePartYear -> json.string("y")
    intldate.DateTimePartRelatedYear -> json.string("r")
    intldate.DateTimePartYearName -> json.string("n")
    intldate.DateTimePartMonth -> json.string("m")
    intldate.DateTimePartDay -> json.string("d")
    intldate.DateTimePartDayPeriod -> json.string("p")
    intldate.DateTimePartHour -> json.string("h")
    intldate.DateTimePartMinute -> json.string("i")
    intldate.DateTimePartSecond -> json.string("s")
    intldate.DateTimePartFractionalSecond -> json.string("f")
    intldate.DateTimePartTimeZoneName -> json.string("z")
    intldate.DateTimePartUnknown(variant) -> json.string(variant)
  }
}

fn date_time_part_kind_decoder() -> decode.Decoder(intldate.DateTimePartKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "l" -> decode.success(intldate.DateTimePartLiteral)
    "w" -> decode.success(intldate.DateTimePartWeekday)
    "e" -> decode.success(intldate.DateTimePartEra)
    "y" -> decode.success(intldate.DateTimePartYear)
    "r" -> decode.success(intldate.DateTimePartRelatedYear)
    "n" -> decode.success(intldate.DateTimePartYearName)
    "m" -> decode.success(intldate.DateTimePartMonth)
    "d" -> decode.success(intldate.DateTimePartDay)
    "p" -> decode.success(intldate.DateTimePartDayPeriod)
    "h" -> decode.success(intldate.DateTimePartHour)
    "i" -> decode.success(intldate.DateTimePartMinute)
    "s" -> decode.success(intldate.DateTimePartSecond)
    "f" -> decode.success(intldate.DateTimePartFractionalSecond)
    "z" -> decode.success(intldate.DateTimePartTimeZoneName)
    _ -> decode.success(intldate.DateTimePartUnknown(variant))
  }
}

fn date_time_part_source_to_json(
  source: intldate.DateTimePartSource,
) -> json.Json {
  case source {
    intldate.DateTimePartSourceNone -> json.string("n")
    intldate.DateTimePartSourceStartRange -> json.string("s")
    intldate.DateTimePartSourceShared -> json.string("h")
    intldate.DateTimePartSourceEndRange -> json.string("e")
  }
}

fn date_time_part_source_decoder() -> decode.Decoder(
  intldate.DateTimePartSource,
) {
  use variant <- decode.then(decode.string)
  case variant {
    "s" -> decode.success(intldate.DateTimePartSourceStartRange)
    "h" -> decode.success(intldate.DateTimePartSourceShared)
    "e" -> decode.success(intldate.DateTimePartSourceEndRange)
    _ -> decode.success(intldate.DateTimePartSourceNone)
  }
}

pub type ResolvedOptionsTestCase {
  ResolvedOptionsTestCase(
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: ExpectedOptions,
  )
}

pub fn resolved_options_test_case_to_json(
  test_case: ResolvedOptionsTestCase,
) -> json.Json {
  json.object([
    #("l", json.string(test_case.locale)),
    #("z", json.string(test_case.time_zone)),
    #("c", date_time_format_config_to_json(test_case.config)),
    #("r", expected_options_to_json(test_case.expected)),
  ])
}

pub fn resolved_options_test_case_decoder() -> decode.Decoder(
  ResolvedOptionsTestCase,
) {
  use locale <- decode.field("l", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use config <- decode.field("c", date_time_format_config_decoder())
  use expected <- decode.field("r", expected_options_decoder())

  decode.success(ResolvedOptionsTestCase(
    locale:,
    time_zone:,
    config:,
    expected:,
  ))
}

fn date_time_resolved_options_to_json(
  options: intldate.DateTimeResolvedOptions,
) -> json.Json {
  json.object(
    [
      #("l", json.string(options.locale)),
      #("c", json.string(options.calendar)),
      #("n", json.string(options.numbering_system)),
      #("z", json.string(options.time_zone)),
    ]
    |> list.append(
      list.flatten([
        optional_json_field("y", options.hour_cycle, json.string),
        optional_json_field("b", options.hour12, json.bool),
        optional_json_field("w", options.weekday, json.string),
        optional_json_field("e", options.era, json.string),
        optional_json_field("a", options.year, json.string),
        optional_json_field("o", options.month, json.string),
        optional_json_field("d", options.day, json.string),
        optional_json_field("h", options.hour, json.string),
        optional_json_field("i", options.minute, json.string),
        optional_json_field("s", options.second, json.string),
        optional_json_field("t", options.time_zone_name, json.string),
      ]),
    ),
  )
}

fn date_time_resolved_options_decoder() -> decode.Decoder(
  intldate.DateTimeResolvedOptions,
) {
  use locale <- decode.field("l", decode.string)
  use calendar <- decode.field("c", decode.string)
  use numbering_system <- decode.field("n", decode.string)
  use time_zone <- decode.field("z", decode.string)
  use hour_cycle <- decode.optional_field(
    "y",
    None,
    decode.map(decode.string, Some),
  )
  use hour12 <- decode.optional_field("b", None, decode.map(decode.bool, Some))
  use weekday <- decode.optional_field(
    "w",
    None,
    decode.map(decode.string, Some),
  )
  use era <- decode.optional_field("e", None, decode.map(decode.string, Some))
  use year <- decode.optional_field("a", None, decode.map(decode.string, Some))
  use month <- decode.optional_field("o", None, decode.map(decode.string, Some))
  use day <- decode.optional_field("d", None, decode.map(decode.string, Some))
  use hour <- decode.optional_field("h", None, decode.map(decode.string, Some))
  use minute <- decode.optional_field(
    "i",
    None,
    decode.map(decode.string, Some),
  )
  use second <- decode.optional_field(
    "s",
    None,
    decode.map(decode.string, Some),
  )
  use time_zone_name <- decode.optional_field(
    "t",
    None,
    decode.map(decode.string, Some),
  )

  decode.success(intldate.DateTimeResolvedOptions(
    locale:,
    calendar:,
    numbering_system:,
    time_zone:,
    hour_cycle:,
    hour12:,
    weekday:,
    era:,
    year:,
    month:,
    day:,
    hour:,
    minute:,
    second:,
    time_zone_name:,
  ))
}

pub type RelativeFormatTestCase {
  RelativeFormatTestCase(
    value: Int,
    unit: Unit,
    locale: String,
    config: intlrelative.RelativeTimeFormatConfig,
    expected: Expected,
  )
}

pub fn relative_format_test_case_to_json(
  test_case: RelativeFormatTestCase,
) -> json.Json {
  json.object([
    #("v", json.int(test_case.value)),
    #("u", relative_unit_to_json(test_case.unit)),
    #("l", json.string(test_case.locale)),
    #("c", relative_time_format_config_to_json(test_case.config)),
    #("r", expected_to_json(test_case.expected)),
  ])
}

pub fn relative_format_test_case_decoder() -> decode.Decoder(
  RelativeFormatTestCase,
) {
  use value <- decode.field("v", decode.int)
  use unit <- decode.field("u", relative_unit_decoder())
  use locale <- decode.field("l", decode.string)
  use config <- decode.field("c", relative_time_format_config_decoder())
  use expected <- decode.field("r", expected_decoder())

  decode.success(RelativeFormatTestCase(
    value:,
    unit:,
    locale:,
    config:,
    expected:,
  ))
}

fn relative_time_format_config_to_json(
  config: intlrelative.RelativeTimeFormatConfig,
) -> json.Json {
  json.object([
    #(
      "m",
      option_to_json(config.locale_matcher, relative_locale_matcher_to_json),
    ),
    #("s", option_to_json(config.style, relative_style_to_json)),
    #("n", option_to_json(config.numeric, relative_numeric_to_json)),
  ])
}

fn relative_time_format_config_decoder() -> decode.Decoder(
  intlrelative.RelativeTimeFormatConfig,
) {
  use locale_matcher <- decode.optional_field(
    "m",
    None,
    decode.optional(relative_locale_matcher_decoder()),
  )
  use style <- decode.optional_field(
    "s",
    None,
    decode.optional(relative_style_decoder()),
  )
  use numeric <- decode.optional_field(
    "n",
    None,
    decode.optional(relative_numeric_decoder()),
  )

  let config =
    intlrelative.new()
    |> relative_apply(locale_matcher, intlrelative.with_locale_matcher)
    |> relative_apply(style, intlrelative.with_style)
    |> relative_apply(numeric, intlrelative.with_numeric)

  decode.success(config)
}

fn relative_apply(
  config: intlrelative.RelativeTimeFormatConfig,
  value: Option(a),
  with: fn(intlrelative.RelativeTimeFormatConfig, a) ->
    intlrelative.RelativeTimeFormatConfig,
) -> intlrelative.RelativeTimeFormatConfig {
  case value {
    Some(value) -> with(config, value)
    None -> config
  }
}

fn relative_unit_to_json(unit: intlrelative.Unit) -> json.Json {
  case unit {
    intlrelative.Second -> json.string("s")
    intlrelative.Minute -> json.string("i")
    intlrelative.Hour -> json.string("h")
    intlrelative.Day -> json.string("d")
    intlrelative.Week -> json.string("w")
    intlrelative.Month -> json.string("o")
    intlrelative.Quarter -> json.string("q")
    intlrelative.Year -> json.string("y")
  }
}

fn relative_unit_decoder() -> decode.Decoder(intlrelative.Unit) {
  use variant <- decode.then(decode.string)
  case variant {
    "s" -> decode.success(intlrelative.Second)
    "i" -> decode.success(intlrelative.Minute)
    "h" -> decode.success(intlrelative.Hour)
    "d" -> decode.success(intlrelative.Day)
    "w" -> decode.success(intlrelative.Week)
    "o" -> decode.success(intlrelative.Month)
    "q" -> decode.success(intlrelative.Quarter)
    "y" -> decode.success(intlrelative.Year)
    _ -> decode.failure(intlrelative.Second, "Unit")
  }
}

fn relative_locale_matcher_to_json(
  locale_matcher: intlrelative.LocaleMatcher,
) -> json.Json {
  case locale_matcher {
    intlrelative.LocaleMatcherBestFit -> json.string("b")
    intlrelative.LocaleMatcherLookup -> json.string("l")
  }
}

fn relative_locale_matcher_decoder() -> decode.Decoder(
  intlrelative.LocaleMatcher,
) {
  use variant <- decode.then(decode.string)
  case variant {
    "b" -> decode.success(intlrelative.LocaleMatcherBestFit)
    "l" -> decode.success(intlrelative.LocaleMatcherLookup)
    _ -> decode.failure(intlrelative.LocaleMatcherBestFit, "LocaleMatcher")
  }
}

fn relative_style_to_json(style: intlrelative.Style) -> json.Json {
  case style {
    intlrelative.Long -> json.string("l")
    intlrelative.Short -> json.string("s")
    intlrelative.Narrow -> json.string("n")
  }
}

fn relative_style_decoder() -> decode.Decoder(intlrelative.Style) {
  use variant <- decode.then(decode.string)
  case variant {
    "l" -> decode.success(intlrelative.Long)
    "s" -> decode.success(intlrelative.Short)
    "n" -> decode.success(intlrelative.Narrow)
    _ -> decode.failure(intlrelative.Long, "Style")
  }
}

fn relative_numeric_to_json(numeric: intlrelative.Numeric) -> json.Json {
  case numeric {
    intlrelative.Always -> json.string("a")
    intlrelative.Auto -> json.string("u")
  }
}

fn relative_numeric_decoder() -> decode.Decoder(intlrelative.Numeric) {
  use variant <- decode.then(decode.string)
  case variant {
    "a" -> decode.success(intlrelative.Always)
    "u" -> decode.success(intlrelative.Auto)
    _ -> decode.failure(intlrelative.Always, "Numeric")
  }
}

pub type ExpectedRelativeParts {
  ExpectRelativeParts(List(intlrelative.RelativeTimeFormatPart))
  ExpectRelativePartsError(String)
}

pub type ExpectedRelativeOptions {
  ExpectRelativeOptions(intlrelative.RelativeTimeResolvedOptions)
  ExpectRelativeOptionsError(String)
}

pub type RelativePartsTestCase {
  RelativePartsTestCase(
    value: Int,
    unit: Unit,
    locale: String,
    config: intlrelative.RelativeTimeFormatConfig,
    expected: ExpectedRelativeParts,
  )
}

pub fn relative_parts_test_case_to_json(
  test_case: RelativePartsTestCase,
) -> json.Json {
  json.object([
    #("v", json.int(test_case.value)),
    #("u", relative_unit_to_json(test_case.unit)),
    #("l", json.string(test_case.locale)),
    #("c", relative_time_format_config_to_json(test_case.config)),
    #("r", expected_relative_parts_to_json(test_case.expected)),
  ])
}

pub fn relative_parts_test_case_decoder() -> decode.Decoder(
  RelativePartsTestCase,
) {
  use value <- decode.field("v", decode.int)
  use unit <- decode.field("u", relative_unit_decoder())
  use locale <- decode.field("l", decode.string)
  use config <- decode.field("c", relative_time_format_config_decoder())
  use expected <- decode.field("r", expected_relative_parts_decoder())

  decode.success(RelativePartsTestCase(
    value:,
    unit:,
    locale:,
    config:,
    expected:,
  ))
}

fn relative_time_format_part_to_json(
  part: intlrelative.RelativeTimeFormatPart,
) -> json.Json {
  json.object(
    [
      #("t", relative_time_part_kind_to_json(part.kind)),
      #("v", json.string(part.value)),
    ]
    |> list.append(optional_json_field("u", part.unit, json.string)),
  )
}

fn relative_time_format_part_decoder() -> decode.Decoder(
  intlrelative.RelativeTimeFormatPart,
) {
  use kind <- decode.field("t", relative_time_part_kind_decoder())
  use value <- decode.field("v", decode.string)
  use unit <- decode.optional_field("u", None, decode.map(decode.string, Some))

  decode.success(intlrelative.RelativeTimeFormatPart(kind:, value:, unit:))
}

fn relative_time_part_kind_to_json(
  kind: intlrelative.RelativeTimePartKind,
) -> json.Json {
  case kind {
    intlrelative.RelativeTimePartLiteral -> json.string("l")
    intlrelative.RelativeTimePartInteger -> json.string("i")
    intlrelative.RelativeTimePartFraction -> json.string("f")
    intlrelative.RelativeTimePartDecimal -> json.string("d")
    intlrelative.RelativeTimePartUnit -> json.string("u")
    intlrelative.RelativeTimePartUnknown(variant) -> json.string(variant)
  }
}

fn relative_time_part_kind_decoder() -> decode.Decoder(
  intlrelative.RelativeTimePartKind,
) {
  use variant <- decode.then(decode.string)
  case variant {
    "l" -> decode.success(intlrelative.RelativeTimePartLiteral)
    "i" -> decode.success(intlrelative.RelativeTimePartInteger)
    "f" -> decode.success(intlrelative.RelativeTimePartFraction)
    "d" -> decode.success(intlrelative.RelativeTimePartDecimal)
    "u" -> decode.success(intlrelative.RelativeTimePartUnit)
    _ -> decode.success(intlrelative.RelativeTimePartUnknown(variant))
  }
}

pub type RelativeResolvedOptionsTestCase {
  RelativeResolvedOptionsTestCase(
    locale: String,
    config: intlrelative.RelativeTimeFormatConfig,
    expected: ExpectedRelativeOptions,
  )
}

pub fn relative_resolved_options_test_case_to_json(
  test_case: RelativeResolvedOptionsTestCase,
) -> json.Json {
  json.object([
    #("l", json.string(test_case.locale)),
    #("c", relative_time_format_config_to_json(test_case.config)),
    #("r", expected_relative_options_to_json(test_case.expected)),
  ])
}

pub fn relative_resolved_options_test_case_decoder() -> decode.Decoder(
  RelativeResolvedOptionsTestCase,
) {
  use locale <- decode.field("l", decode.string)
  use config <- decode.field("c", relative_time_format_config_decoder())
  use expected <- decode.field("r", expected_relative_options_decoder())

  decode.success(RelativeResolvedOptionsTestCase(locale:, config:, expected:))
}

fn relative_resolved_options_to_json(
  options: intlrelative.RelativeTimeResolvedOptions,
) -> json.Json {
  json.object([
    #("l", json.string(options.locale)),
    #("s", json.string(options.style)),
    #("n", json.string(options.numeric)),
    #("g", json.string(options.numbering_system)),
  ])
}

fn relative_resolved_options_decoder() -> decode.Decoder(
  intlrelative.RelativeTimeResolvedOptions,
) {
  use locale <- decode.field("l", decode.string)
  use style <- decode.field("s", decode.string)
  use numeric <- decode.field("n", decode.string)
  use numbering_system <- decode.field("g", decode.string)

  decode.success(intlrelative.RelativeTimeResolvedOptions(
    locale:,
    numbering_system:,
    style:,
    numeric:,
  ))
}
