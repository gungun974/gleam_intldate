import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/chronology
import intldate/internal/skeleton

pub type Weekday {
  Weekday(
    narrow: dict.Dict(Int, String),
    short: dict.Dict(Int, String),
    long: dict.Dict(Int, String),
  )
}

fn indexed_list_decoder() -> decode.Decoder(dict.Dict(Int, String)) {
  use items <- decode.then(decode.list(decode.string))
  decode.success(
    list.index_fold(items, dict.new(), fn(acc, item, index) {
      dict.insert(acc, index, item)
    }),
  )
}

fn weekday_decoder() -> decode.Decoder(Weekday) {
  use narrow <- decode.field("narrow", indexed_list_decoder())
  use short <- decode.field("short", indexed_list_decoder())
  use long <- decode.field("long", indexed_list_decoder())
  decode.success(Weekday(narrow:, short:, long:))
}

pub type Era {
  Era(
    narrow: #(String, String),
    short: #(String, String),
    long: #(String, String),
  )
}

pub type Month {
  Month(
    narrow: dict.Dict(Int, String),
    short: dict.Dict(Int, String),
    long: dict.Dict(Int, String),
  )
}

fn month_decoder() -> decode.Decoder(Month) {
  use narrow <- decode.field("narrow", indexed_list_decoder())
  use short <- decode.field("short", indexed_list_decoder())
  use long <- decode.field("long", indexed_list_decoder())
  decode.success(Month(narrow:, short:, long:))
}

pub type CalendarEra {
  CalendarEra(
    narrow: dict.Dict(Int, String),
    short: dict.Dict(Int, String),
    long: dict.Dict(Int, String),
  )
}

pub type CalendarData {
  CalendarData(
    calendar: chronology.Chronology,
    month: Month,
    month_standalone: Option(Month),
    era: CalendarEra,
    year_names: dict.Dict(Int, String),
    leap_month: Option(String),
    formats: List(skeleton.Formats),
  )
}

fn int_keyed_decoder() -> decode.Decoder(dict.Dict(Int, String)) {
  use raw <- decode.then(decode.dict(decode.string, decode.string))
  decode.success(
    dict.fold(raw, dict.new(), fn(acc, key_str, value_str) {
      case int.parse(key_str) {
        Ok(int_key) -> dict.insert(acc, int_key, value_str)
        Error(_) -> acc
      }
    }),
  )
}

fn calendar_era_decoder() -> decode.Decoder(CalendarEra) {
  use narrow <- decode.optional_field("narrow", dict.new(), int_keyed_decoder())
  use short <- decode.optional_field("short", dict.new(), int_keyed_decoder())
  use long <- decode.optional_field("long", dict.new(), int_keyed_decoder())
  decode.success(CalendarEra(narrow:, short:, long:))
}

fn calendar_data_decoder(
  calendar: chronology.Chronology,
  formats: List(skeleton.Formats),
) -> decode.Decoder(CalendarData) {
  use month <- decode.field("month", month_decoder())
  use month_standalone <- decode.optional_field(
    "monthStandalone",
    None,
    decode.map(month_decoder(), Some),
  )
  use era <- decode.optional_field(
    "era",
    CalendarEra(dict.new(), dict.new(), dict.new()),
    calendar_era_decoder(),
  )
  use year_names <- decode.optional_field(
    "yearNames",
    dict.new(),
    int_keyed_decoder(),
  )
  use leap_month <- decode.optional_field(
    "leapMonth",
    None,
    decode.map(decode.string, Some),
  )
  decode.success(CalendarData(
    calendar:,
    month:,
    month_standalone:,
    era:,
    year_names:,
    leap_month:,
    formats:,
  ))
}

pub type TimeZone {
  TimeZone(long: List(String), short: List(String))
}

fn time_zone_decoder() -> decode.Decoder(TimeZone) {
  use long <- decode.optional_field("long", [], decode.list(decode.string))
  use short <- decode.optional_field("short", [], decode.list(decode.string))
  decode.success(TimeZone(
    long: case long {
      [] -> short
      _ -> long
    },
    short:,
  ))
}

pub type DateTimeConnectors {
  DateTimeConnectors(full: String, long: String, medium: String, short: String)
}

fn date_time_connectors_decoder() -> decode.Decoder(DateTimeConnectors) {
  use full <- decode.field("full", decode.string)
  use long <- decode.field("long", decode.string)
  use medium <- decode.field("medium", decode.string)
  use short <- decode.field("short", decode.string)
  decode.success(DateTimeConnectors(full:, long:, medium:, short:))
}

fn interval_value_decoder() -> decode.Decoder(dict.Dict(String, String)) {
  decode.one_of(decode.dict(decode.string, decode.string), or: [
    decode.map(decode.string, fn(_) { dict.new() }),
  ])
}

pub type HourCycle {
  H11
  H12
  H23
  H24
}

pub type Locale {
  Locale(
    id: String,
    am: String,
    pm: String,
    weekday: Weekday,
    time_zone_name: dict.Dict(String, TimeZone),
    gmt_format: String,
    hour_format: String,
    date_time_connectors: DateTimeConnectors,
    interval_format_fallback: Option(String),
    hour_cycle: HourCycle,
    default_calendar: chronology.Chronology,
    numbering_system: List(String),
  )
}

fn find_interval_format(
  skeleton: String,
  interval_formats: dict.Dict(String, dict.Dict(String, String)),
) -> Option(dict.Dict(String, String)) {
  case string.split_once(skeleton, ", ") {
    Error(_) -> None
    Ok(#(date_part, time_part)) -> {
      let canonical = canonicalize_time_part(time_part)
      case canonical == time_part {
        True -> None
        False ->
          case dict.get(interval_formats, date_part <> ", " <> canonical) {
            Ok(patterns) -> Some(patterns)
            Error(_) -> None
          }
      }
    }
  }
}

fn canonicalize_time_part(time_part: String) -> String {
  time_part
  |> string.to_utf_codepoints
  |> list.filter_map(fn(code_point) {
    case is_time_field_letter(string.utf_codepoint_to_int(code_point)) {
      True -> Ok(code_point)
      False -> Error(Nil)
    }
  })
  |> string.from_utf_codepoints
  |> collapse_repeats
}

fn is_time_field_letter(code: Int) -> Bool {
  case code {
    97 | 98 | 66 -> False
    _ -> { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
  }
}

fn collapse_repeats(content: String) -> String {
  string.to_graphemes(content)
  |> list.fold("", fn(acc, grapheme) {
    case string.ends_with(acc, grapheme) {
      True -> acc
      False -> acc <> grapheme
    }
  })
}

pub type CalendarFormats {
  CalendarFormats(
    available: dict.Dict(String, String),
    date: dict.Dict(String, String),
    time: dict.Dict(String, String),
    full: String,
    long: String,
    medium: String,
    short: String,
    marker: Bool,
  )
}

fn calendar_formats_decoder() -> decode.Decoder(CalendarFormats) {
  use available <- decode.field(
    "available",
    decode.dict(decode.string, decode.string),
  )
  use date <- decode.field("date", decode.dict(decode.string, decode.string))
  use time <- decode.field("time", decode.dict(decode.string, decode.string))
  use full <- decode.field("full", decode.string)
  use long <- decode.field("long", decode.string)
  use medium <- decode.field("medium", decode.string)
  use short <- decode.field("short", decode.string)
  use marker <- decode.field("marker", decode.bool)
  decode.success(CalendarFormats(
    available:,
    date:,
    time:,
    full:,
    long:,
    medium:,
    short:,
    marker:,
  ))
}

type BuiltFormats {
  BuiltFormats(
    all: dict.Dict(String, String),
    date: dict.Dict(String, String),
    time: dict.Dict(String, String),
  )
}

fn pick_template(
  calendar_formats: CalendarFormats,
  info: skeleton.SkeletonInfo,
) -> String {
  case info.month_long, info.month_short {
    True, _ ->
      case info.has_weekday {
        True -> calendar_formats.full
        False -> calendar_formats.long
      }
    _, True -> calendar_formats.medium
    _, _ -> calendar_formats.short
  }
}

fn build_calendar_formats(calendar_formats: CalendarFormats) -> BuiltFormats {
  let available =
    dict.filter(calendar_formats.available, fn(skeleton_key, pattern) {
      !skeleton.has_unsupported_field(skeleton_key)
      && !skeleton.has_unsupported_field(pattern)
    })

  let base =
    available
    |> dict.merge(calendar_formats.date)
    |> dict.merge(calendar_formats.time)

  let #(date_formats, time_formats) =
    dict.fold(
      available,
      #(calendar_formats.date, calendar_formats.time),
      fn(acc, skeleton_key, pattern) {
        let #(date_fmts, time_fmts) = acc
        let info = skeleton.skeleton_info(skeleton_key)
        case info.date_only, info.time_only {
          True, _ -> #(dict.insert(date_fmts, skeleton_key, pattern), time_fmts)
          _, True -> #(date_fmts, dict.insert(time_fmts, skeleton_key, pattern))
          _, _ -> #(date_fmts, time_fmts)
        }
      },
    )

  let all =
    dict.fold(time_formats, base, fn(acc, time_skeleton, time_pattern) {
      dict.fold(date_formats, acc, fn(acc, date_skeleton, date_pattern) {
        let raw =
          pick_template(calendar_formats, skeleton.skeleton_info(date_skeleton))
        let pattern = case calendar_formats.marker {
          True -> date_pattern <> "\u{E000}" <> time_pattern
          False ->
            raw
            |> string.replace("{0}", time_pattern)
            |> string.replace("{1}", date_pattern)
        }
        let skeleton_key =
          raw
          |> string.replace("{0}", time_skeleton)
          |> string.replace("{1}", date_skeleton)
        dict.insert(acc, skeleton_key, pattern)
      })
    })

  BuiltFormats(all:, date: date_formats, time: time_formats)
}

fn lookup_time_intervals(
  base_intervals: dict.Dict(String, dict.Dict(String, String)),
  time_skeleton: String,
) -> dict.Dict(String, String) {
  case dict.get(base_intervals, time_skeleton) {
    Ok(found) ->
      case dict.is_empty(found) {
        False -> found
        True -> lookup_alt_time_intervals(base_intervals, time_skeleton)
      }
    Error(_) -> lookup_alt_time_intervals(base_intervals, time_skeleton)
  }
}

fn lookup_alt_time_intervals(
  base_intervals: dict.Dict(String, dict.Dict(String, String)),
  time_skeleton: String,
) -> dict.Dict(String, String) {
  let alt24 =
    time_skeleton
    |> string.replace("h", "H")
    |> string.replace("K", "k")
  let alt12 =
    time_skeleton
    |> string.replace("H", "h")
    |> string.replace("k", "K")

  case alt24 != time_skeleton {
    True -> dict_get_or_empty(base_intervals, alt24)
    False ->
      case alt12 != time_skeleton {
        True -> dict_get_or_empty(base_intervals, alt12)
        False -> dict.new()
      }
  }
}

fn dict_get_or_empty(
  base_intervals: dict.Dict(String, dict.Dict(String, String)),
  key: String,
) -> dict.Dict(String, String) {
  case dict.get(base_intervals, key) {
    Ok(found) -> found
    Error(_) -> dict.new()
  }
}

fn synthesize_intervals(
  calendar_formats: CalendarFormats,
  date_formats: dict.Dict(String, String),
  time_formats: dict.Dict(String, String),
  base_intervals: dict.Dict(String, dict.Dict(String, String)),
) -> dict.Dict(String, dict.Dict(String, String)) {
  dict.fold(time_formats, base_intervals, fn(acc, time_skeleton, _time_pattern) {
    dict.fold(date_formats, acc, fn(acc, date_skeleton, date_pattern) {
      let raw =
        pick_template(calendar_formats, skeleton.skeleton_info(date_skeleton))
      let skeleton_key =
        raw
        |> string.replace("{0}", time_skeleton)
        |> string.replace("{1}", date_skeleton)
      case dict.get(acc, skeleton_key) {
        Ok(_) -> acc
        Error(_) -> {
          let time_intervals =
            lookup_time_intervals(base_intervals, time_skeleton)
          let synthesized =
            dict.fold(
              time_intervals,
              dict.new(),
              fn(interval_acc, field, time_pattern) {
                dict.insert(
                  interval_acc,
                  field,
                  raw
                    |> string.replace("{0}", time_pattern)
                    |> string.replace("{1}", date_pattern),
                )
              },
            )
          case dict.is_empty(synthesized) {
            True -> acc
            False -> dict.insert(acc, skeleton_key, synthesized)
          }
        }
      }
    })
  })
}

fn build_formats(
  raw_formats: dict.Dict(String, String),
  interval_formats: dict.Dict(String, dict.Dict(String, String)),
  interval_format_fallback: Option(String),
) -> List(skeleton.Formats) {
  let #(patterns, _) =
    dict.fold(
      raw_formats,
      #([], dict.new()),
      fn(inner, skeleton_key, raw_pattern) {
        let #(acc, cache) = inner
        let cache_key = #(skeleton_key, raw_pattern)

        case dict.get(cache, cache_key) {
          Ok(format) -> #([format, ..acc], cache)
          Error(_) -> {
            let range_patterns = case dict.get(interval_formats, skeleton_key) {
              Ok(patterns) -> Some(patterns)
              Error(_) -> find_interval_format(skeleton_key, interval_formats)
            }

            let format =
              skeleton.parse_date_time_skeleton(
                skeleton_key,
                raw_pattern,
                range_patterns,
                interval_format_fallback,
              )

            #([format, ..acc], dict.insert(cache, cache_key, format))
          }
        }
      },
    )

  patterns
}

fn locale_decoder(id: String) -> decode.Decoder(Locale) {
  use am <- decode.field("am", decode.string)
  use pm <- decode.field("pm", decode.string)
  use weekday <- decode.field("weekday", weekday_decoder())
  use time_zone_name <- decode.field(
    "timeZoneName",
    decode.dict(decode.string, time_zone_decoder()),
  )
  use gmt_format <- decode.field("gmtFormat", decode.string)
  use hour_format <- decode.field("hourFormat", decode.string)
  use date_time_connectors <- decode.optional_field(
    "dateTimeConnectors",
    DateTimeConnectors(full: ", ", long: ", ", medium: ", ", short: ", "),
    date_time_connectors_decoder(),
  )

  use interval_format_fallback <- decode.then(decode.optionally_at(
    ["intervalFormats", "intervalFormatFallback"],
    None,
    decode.map(decode.string, Some),
  ))
  use hour_cycle <- decode.field("hourCycle", decode.string)
  use default_calendar <- decode.optional_field(
    "defaultCalendar",
    "gregory",
    decode.string,
  )
  use numbering_system <- decode.field("nu", decode.list(decode.string))

  decode.success(Locale(
    id:,
    am:,
    pm:,
    weekday:,
    time_zone_name:,
    gmt_format:,
    hour_format:,
    date_time_connectors:,
    interval_format_fallback:,
    hour_cycle: case hour_cycle {
      "h11" -> H11
      "h12" -> H12
      "h23" -> H23
      "h24" -> H24
      _ -> H23
    },
    default_calendar: case default_calendar {
      "buddhist" -> chronology.CalendarBuddhist
      "chinese" -> chronology.CalendarChinese
      "coptic" -> chronology.CalendarCoptic
      "dangi" -> chronology.CalendarDangi
      "ethioaa" -> chronology.CalendarEthioaa
      "ethiopic" -> chronology.CalendarEthiopic
      "hebrew" -> chronology.CalendarHebrew
      "indian" -> chronology.CalendarIndian
      "islamic" -> chronology.CalendarIslamic
      "japanese" -> chronology.CalendarJapanese
      "persian" -> chronology.CalendarPersian
      "roc" -> chronology.CalendarRoc
      _ -> chronology.CalendarGregory
    },
    numbering_system:,
  ))
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

const locale_cache_key = "intldate#locale"

const calendar_cache_key = "intldate#calendar"

@external(erlang, "intldate_locale_ffi", "load_locale_data")
fn load_locale_data(locale: String) -> Result(Dynamic, Nil) {
  let _ = locale
  Error(Nil)
}

pub fn load_locale(tag: Option(String)) -> Result(Locale, Nil) {
  load_first(case tag {
    None -> ["en"]
    Some(locale) -> {
      case string.split(locale, "-") {
        ["zh", region] if region == "TW" || region == "HK" || region == "MO" -> [
          locale,
          "zh-Hant",
          "zh",
        ]
        ["zh", region] if region == "CN" || region == "SG" || region == "MY" -> [
          locale,
          "zh-Hans",
          "zh",
        ]
        [base, ..] -> [locale, base]
        [] -> [locale]
      }
    }
  })
}

fn load_first(candidates: List(String)) -> Result(Locale, Nil) {
  case candidates {
    [] -> Error(Nil)
    [candidate, ..rest] ->
      case load(candidate) {
        Ok(loaded_locale) -> Ok(loaded_locale)
        Error(_) -> load_first(rest)
      }
  }
}

fn load(locale: String) -> Result(Locale, Nil) {
  let cache_id = locale_cache_key <> "#" <> locale

  case cache_lookup(cache_id) {
    Ok(cached) -> Ok(cached)
    Error(_) ->
      case load_locale_data(locale) {
        Error(_) -> Error(Nil)
        Ok(data) ->
          case decode.run(data, locale_decoder(locale)) {
            Ok(parsed) -> {
              let _ = cache_insert(cache_id, parsed)
              Ok(parsed)
            }
            Error(_) -> Error(Nil)
          }
      }
  }
}

pub fn load_calendar(
  locale: Locale,
  calendar: chronology.Chronology,
) -> Result(CalendarData, Nil) {
  let calendar_id = case calendar {
    chronology.CalendarGregory | chronology.CalendarIso8601 -> "gregory"
    chronology.CalendarBuddhist -> "buddhist"
    chronology.CalendarChinese -> "chinese"
    chronology.CalendarCoptic -> "coptic"
    chronology.CalendarDangi -> "dangi"
    chronology.CalendarEthioaa -> "ethioaa"
    chronology.CalendarEthiopic -> "ethiopic"
    chronology.CalendarHebrew -> "hebrew"
    chronology.CalendarIndian -> "indian"
    chronology.CalendarJapanese -> "japanese"
    chronology.CalendarPersian -> "persian"
    chronology.CalendarRoc -> "roc"
    chronology.CalendarIslamic
    | chronology.CalendarIslamicUmalqura
    | chronology.CalendarIslamicTbla
    | chronology.CalendarIslamicCivil
    | chronology.CalendarIslamicRgsa -> "islamic"
  }

  let cache_id = calendar_cache_key <> "#" <> locale.id <> "#" <> calendar_id

  case cache_lookup(cache_id) {
    Ok(cached) -> Ok(CalendarData(..cached, calendar:))
    Error(_) -> {
      case load_locale_data(locale.id) {
        Error(_) -> Error(Nil)
        Ok(data) ->
          case
            decode.run(data, {
              use calendar_formats <- decode.subfield(
                ["formats", calendar_id],
                calendar_formats_decoder(),
              )
              use gregory_formats <- decode.subfield(
                ["formats", "gregory"],
                calendar_formats_decoder(),
              )

              use base_intervals <- decode.optional_field(
                "intervalFormats",
                dict.new(),
                decode.dict(decode.string, interval_value_decoder()),
              )

              let gregory_built = build_calendar_formats(gregory_formats)
              let interval_formats =
                synthesize_intervals(
                  gregory_formats,
                  gregory_built.date,
                  gregory_built.time,
                  base_intervals,
                )
                |> dict.delete("intervalFormatFallback")

              let built = build_calendar_formats(calendar_formats)
              let formats =
                build_formats(
                  built.all,
                  interval_formats,
                  locale.interval_format_fallback,
                )

              use calendars <- decode.subfield(
                ["calendars", calendar_id],
                calendar_data_decoder(calendar, formats),
              )
              decode.success(calendars)
            })
          {
            Ok(parsed) -> {
              let _ = cache_insert(cache_id, parsed)
              Ok(parsed)
            }
            Error(_) -> Error(Nil)
          }
      }
    }
  }
}
