import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/icudata/resource.{CalendarSymbolsByLocale}
import intldate_generate/decoder
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/shared
import simplifile

fn resolvable_leaf_field(
  path: List(String),
  inner: decode.Decoder(t),
) -> decode.Decoder(Option(resource.CalendarLeaf(t))) {
  decode.one_of(
    decode.subfield(path, icurb.resolvable(inner), fn(value) {
      case value {
        icurb.Value(v) -> decode.success(Some(resource.CalendarLeafValue(v)))
        icurb.AliasTo(target) ->
          decode.success(Some(resource.CalendarLeafAliasTo(target)))
      }
    }),
    [decode.success(None)],
  )
}

fn width_names_decoder() -> decode.Decoder(resource.WidthNames) {
  use wide <- decode.then(resolvable_leaf_field(
    ["wide"],
    decode.list(decode.string),
  ))
  use abbreviated <- decode.then(resolvable_leaf_field(
    ["abbreviated"],
    decode.list(decode.string),
  ))
  use narrow <- decode.then(resolvable_leaf_field(
    ["narrow"],
    decode.list(decode.string),
  ))
  use short <- decode.then(resolvable_leaf_field(
    ["short"],
    decode.list(decode.string),
  ))
  decode.success(resource.WidthNames(wide:, abbreviated:, narrow:, short:))
}

fn empty_width_names() -> resource.WidthNames {
  resource.WidthNames(None, None, None, None)
}

fn context_names_decoder() -> decode.Decoder(resource.ContextNames) {
  use format <- decode.optional_field(
    "format",
    empty_width_names(),
    width_names_decoder(),
  )
  use stand_alone <- decode.optional_field(
    "stand-alone",
    empty_width_names(),
    width_names_decoder(),
  )
  decode.success(resource.ContextNames(format:, stand_alone:))
}

fn width_table_decoder() -> decode.Decoder(resource.WidthTable) {
  use wide <- decode.then(resolvable_leaf_field(
    ["wide"],
    decode.dict(decode.string, decode.string),
  ))
  use abbreviated <- decode.then(resolvable_leaf_field(
    ["abbreviated"],
    decode.dict(decode.string, decode.string),
  ))
  use narrow <- decode.then(resolvable_leaf_field(
    ["narrow"],
    decode.dict(decode.string, decode.string),
  ))
  decode.success(resource.WidthTable(wide:, abbreviated:, narrow:))
}

fn empty_width_table() -> resource.WidthTable {
  resource.WidthTable(None, None, None)
}

fn context_table_decoder() -> decode.Decoder(resource.ContextTable) {
  use format <- decode.optional_field(
    "format",
    empty_width_table(),
    width_table_decoder(),
  )
  use stand_alone <- decode.optional_field(
    "stand-alone",
    empty_width_table(),
    width_table_decoder(),
  )
  decode.success(resource.ContextTable(format:, stand_alone:))
}

fn leap_string_decoder() -> decode.Decoder(String) {
  decode.subfield(["leap"], decode.string, decode.success)
}

fn month_pattern_widths_decoder() -> decode.Decoder(resource.MonthPatternWidths) {
  use wide <- decode.then(resolvable_leaf_field(["wide"], leap_string_decoder()))
  use abbreviated <- decode.then(resolvable_leaf_field(
    ["abbreviated"],
    leap_string_decoder(),
  ))
  use narrow <- decode.then(resolvable_leaf_field(
    ["narrow"],
    leap_string_decoder(),
  ))
  decode.success(resource.MonthPatternWidths(wide:, abbreviated:, narrow:))
}

fn empty_month_pattern_widths() -> resource.MonthPatternWidths {
  resource.MonthPatternWidths(None, None, None)
}

fn month_patterns_data_decoder() -> decode.Decoder(resource.MonthPatternsData) {
  use format <- decode.optional_field(
    "format",
    empty_month_pattern_widths(),
    month_pattern_widths_decoder(),
  )
  use stand_alone <- decode.optional_field(
    "stand-alone",
    empty_month_pattern_widths(),
    month_pattern_widths_decoder(),
  )
  use numeric <- decode.then(resolvable_leaf_field(
    ["numeric", "all", "leap"],
    decode.string,
  ))
  decode.success(resource.MonthPatternsData(format:, stand_alone:, numeric:))
}

fn calendar_symbols_decoder() -> decode.Decoder(resource.CalendarSymbols) {
  use month_names <- decode.then(decoder.calendar_field(
    ["monthNames"],
    context_names_decoder(),
  ))
  use day_names <- decode.then(decoder.calendar_field(
    ["dayNames"],
    context_names_decoder(),
  ))
  use quarters <- decode.then(decoder.calendar_field(
    ["quarters"],
    context_names_decoder(),
  ))
  use eras <- decode.then(decoder.calendar_field(
    ["eras"],
    width_table_decoder(),
  ))
  use am_pm_markers <- decode.then(decoder.calendar_field(
    ["AmPmMarkers"],
    decode.list(decode.string),
  ))
  use am_pm_markers_abbr <- decode.then(decoder.calendar_field(
    ["AmPmMarkersAbbr"],
    decode.list(decode.string),
  ))
  use am_pm_markers_narrow <- decode.then(decoder.calendar_field(
    ["AmPmMarkersNarrow"],
    decode.list(decode.string),
  ))
  use day_period <- decode.then(decoder.calendar_field(
    ["dayPeriod"],
    context_table_decoder(),
  ))
  use cyclic_years_abbreviated <- decode.then(decoder.calendar_field(
    ["cyclicNameSets"],
    decode.subfield(
      ["years", "format", "abbreviated"],
      decode.list(decode.string),
      decode.success,
    ),
  ))
  use month_patterns <- decode.then(decoder.calendar_field(
    ["monthPatterns"],
    month_patterns_data_decoder(),
  ))
  decode.success(resource.CalendarSymbols(
    month_names:,
    day_names:,
    quarters:,
    eras:,
    am_pm_markers:,
    am_pm_markers_abbr:,
    am_pm_markers_narrow:,
    day_period:,
    cyclic_years_abbreviated:,
    month_patterns:,
  ))
}

fn parse_locale_calendar(contents: String) {
  icurb.parse(contents, {
    use raw <- decode.optional_field(
      "calendar",
      dict.new(),
      decode.dict(decode.string, calendar_symbols_decoder()),
    )
    decode.success(raw)
  })
}

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_calendar(contents) {
        Ok(by_cal) ->
          case dict.is_empty(by_cal) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, by_cal), failed)
          }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Calendar symbol parsing", failed)
  CalendarSymbolsByLocale(locales:)
}
