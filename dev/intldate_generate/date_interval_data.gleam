import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import intldate/internal/icu/icudata/resource.{
  DateIntervalCalendarData, DateIntervalDataByLocale, IntervalFormats,
}
import intldate_generate/decoder
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/shared
import simplifile

type RawIntervalEntry {
  RawIntervalFallback(String)
  RawIntervalPatterns(dict.Dict(String, String))
}

fn interval_formats_decoder() -> decode.Decoder(resource.IntervalFormats) {
  use entries <- decode.then(decode.dict(
    decode.string,
    decode.one_of(decode.map(decode.string, RawIntervalFallback), [
      decode.map(decode.dict(decode.string, decode.string), RawIntervalPatterns),
    ]),
  ))
  let #(patterns, fallback) =
    dict.fold(entries, #(dict.new(), None), fn(acc, key, entry) {
      let #(patterns, fallback) = acc
      case key, entry {
        "fallback", RawIntervalFallback(value) -> #(patterns, Some(value))
        _, RawIntervalPatterns(fields) -> #(
          dict.insert(patterns, key, fields),
          fallback,
        )
        _, _ -> acc
      }
    })
  decode.success(IntervalFormats(patterns:, fallback:))
}

fn date_time_combining_pattern_decoder() -> decode.Decoder(String) {
  use patterns <- decode.then(decode.list(decoder.resource_string()))
  case shared.list_at(patterns, 8) {
    Ok(pattern) -> decode.success(pattern)
    Error(_) -> decode.failure("", "DateTimePatterns has no index 8")
  }
}

fn available_format_decoder() -> decode.Decoder(resource.AvailableFormat) {
  decode.one_of(
    decode.map(decoder.resource_string(), resource.AvailableFormatPattern),
    [
      decode.map(decode.dict(decode.string, decode.string), fn(_) {
        resource.AvailableFormatUnavailable
      }),
    ],
  )
}

fn date_interval_calendar_data_decoder() -> decode.Decoder(
  resource.DateIntervalCalendarData,
) {
  use interval_formats <- decode.then(decoder.calendar_field(
    ["intervalFormats"],
    interval_formats_decoder(),
  ))
  use date_time_combining_pattern <- decode.then(decoder.calendar_field(
    ["DateTimePatterns"],
    date_time_combining_pattern_decoder(),
  ))
  use date_time_patterns <- decode.then(decoder.calendar_field(
    ["DateTimePatterns"],
    decode.list(decoder.resource_string()),
  ))
  use date_time_patterns_at_time <- decode.then(decoder.calendar_field(
    ["DateTimePatterns%atTime"],
    decode.list(decoder.resource_string()),
  ))
  use append_items <- decode.then(decoder.calendar_field(
    ["appendItems"],
    decode.dict(decode.string, decoder.resource_string()),
  ))
  use available_formats <- decode.then(decoder.calendar_field(
    ["availableFormats"],
    decode.dict(decode.string, available_format_decoder()),
  ))
  decode.success(DateIntervalCalendarData(
    interval_formats:,
    date_time_combining_pattern:,
    date_time_patterns:,
    date_time_patterns_at_time:,
    append_items:,
    available_formats:,
  ))
}

fn parse_locale_date_interval_data(contents: String) {
  icurb.parse(contents, {
    use raw <- decode.optional_field(
      "calendar",
      dict.new(),
      decode.dict(decode.string, date_interval_calendar_data_decoder()),
    )
    decode.success(raw)
  })
}

fn date_interval_calendar_data_is_empty(
  data: resource.DateIntervalCalendarData,
) -> Bool {
  data.interval_formats == None
  && data.date_time_combining_pattern == None
  && data.date_time_patterns == None
  && data.date_time_patterns_at_time == None
  && data.append_items == None
  && data.available_formats == None
}

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_date_interval_data(contents) {
        Ok(by_cal) -> {
          let by_cal =
            dict.filter(by_cal, fn(_, data) {
              !date_interval_calendar_data_is_empty(data)
            })
          case dict.is_empty(by_cal) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, by_cal), failed)
          }
        }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Date interval data parsing", failed)
  DateIntervalDataByLocale(locales:)
}
