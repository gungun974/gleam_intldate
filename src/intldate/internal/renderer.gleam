import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar.{Date, TimeOfDay}
import gleam/time/duration
import intldate/internal/chronology.{
  type Chronology, CalendarGregory, CalendarIso8601,
}
import intldate/internal/locale.{type HourCycle, H11, H12, H23, H24}
import intldate/internal/pattern
import intldate/internal/skeleton

const removal_penalty = 120

const addition_penalty = 20

const different_numeric_type_penalty = 15

const long_less_penalty = 8

const long_more_penalty = 6

const short_less_penalty = 6

const short_more_penalty = 3

const sig_year_weight = 320_000_000_000

const sig_month_weight = 1_600_000_000

const sig_day_weight = 8_000_000

const sig_hour_weight = 40_000

const sig_minute_weight = 200

const sig_second_weight = 1

pub type Style {
  StyleTwoDigit
  StyleNumeric
  StyleNarrow
  StyleShort
  StyleLong
}

fn style_index(style: Style) -> Int {
  case style {
    StyleTwoDigit -> 0
    StyleNumeric -> 1
    StyleNarrow -> 2
    StyleShort -> 3
    StyleLong -> 4
  }
}

fn style_numeric(style: Style) -> Bool {
  case style {
    StyleTwoDigit | StyleNumeric -> True
    _ -> False
  }
}

fn cfg_tz_style(time_zone_name: Option(TimeZoneName)) -> Option(Style) {
  case time_zone_name {
    Some(TimeZoneNameShort)
    | Some(TimeZoneNameShortOffset)
    | Some(TimeZoneNameShortGeneric) -> Some(StyleShort)
    Some(TimeZoneNameLong)
    | Some(TimeZoneNameLongOffset)
    | Some(TimeZoneNameLongGeneric) -> Some(StyleLong)
    None -> None
  }
}

fn apply_defaults(config: DateTimeFormatConfig) -> DateTimeFormatConfig {
  let has_component =
    config.weekday != None
    || config.year != None
    || config.month != None
    || config.day != None
    || config.hour != None
    || config.minute != None
    || config.second != None

  let need_defaults = !has_component

  DateTimeFormatConfig(
    ..config,
    year: case config.year, need_defaults {
      None, True -> Some(StyleNumeric)
      style, _ -> style
    },
    month: case config.month, need_defaults {
      None, True -> Some(StyleNumeric)
      style, _ -> style
    },
    day: case config.day, need_defaults {
      None, True -> Some(StyleNumeric)
      style, _ -> style
    },
  )
}

fn fmt_weekday(formats: skeleton.Formats) -> Option(Style) {
  case formats.weekday {
    Some(skeleton.WeekdayLong) -> Some(StyleLong)
    Some(skeleton.WeekdayShort) -> Some(StyleShort)
    Some(skeleton.WeekdayNarrow) -> Some(StyleNarrow)
    None -> None
  }
}

fn fmt_era(formats: skeleton.Formats) -> Option(Style) {
  case formats.era {
    Some(skeleton.EraLong) -> Some(StyleLong)
    Some(skeleton.EraShort) -> Some(StyleShort)
    Some(skeleton.EraNarrow) -> Some(StyleNarrow)
    None -> None
  }
}

fn fmt_year(formats: skeleton.Formats) -> Option(Style) {
  case formats.year {
    Some(skeleton.YearNumeric) -> Some(StyleNumeric)
    Some(skeleton.YearTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn fmt_month(formats: skeleton.Formats) -> Option(Style) {
  case formats.month {
    Some(skeleton.MonthNumeric) -> Some(StyleNumeric)
    Some(skeleton.MonthTwoDigit) -> Some(StyleTwoDigit)
    Some(skeleton.MonthNarrow) -> Some(StyleNarrow)
    Some(skeleton.MonthShort) -> Some(StyleShort)
    Some(skeleton.MonthLong) -> Some(StyleLong)
    None -> None
  }
}

fn fmt_day(formats: skeleton.Formats) -> Option(Style) {
  case formats.day {
    Some(skeleton.DayNumeric) -> Some(StyleNumeric)
    Some(skeleton.DayTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn fmt_hour(formats: skeleton.Formats) -> Option(Style) {
  case formats.hour {
    Some(skeleton.HourNumeric) -> Some(StyleNumeric)
    Some(skeleton.HourTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn fmt_minute(formats: skeleton.Formats) -> Option(Style) {
  case formats.minute {
    Some(skeleton.MinuteNumeric) -> Some(StyleNumeric)
    Some(skeleton.MinuteTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn fmt_second(formats: skeleton.Formats) -> Option(Style) {
  case formats.second {
    Some(skeleton.SecondNumeric) -> Some(StyleNumeric)
    Some(skeleton.SecondTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn fmt_tz(formats: skeleton.Formats) -> Option(Style) {
  case formats.time_zone_name {
    Some(skeleton.TimeZoneShort)
    | Some(skeleton.TimeZoneShortOffset)
    | Some(skeleton.TimeZoneShortGeneric) -> Some(StyleShort)
    Some(skeleton.TimeZoneLong)
    | Some(skeleton.TimeZoneLongOffset)
    | Some(skeleton.TimeZoneLongGeneric) -> Some(StyleLong)
    None -> None
  }
}

fn fmt_fractional(formats: skeleton.Formats) -> Option(Style) {
  case formats.fractional_second_digits {
    Some(_) -> Some(StyleNumeric)
    None -> None
  }
}

fn rfmt_weekday(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.weekday {
    Some(skeleton.WeekdayLong) -> Some(StyleLong)
    Some(skeleton.WeekdayShort) -> Some(StyleShort)
    Some(skeleton.WeekdayNarrow) -> Some(StyleNarrow)
    None -> None
  }
}

fn rfmt_era(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.era {
    Some(skeleton.EraLong) -> Some(StyleLong)
    Some(skeleton.EraShort) -> Some(StyleShort)
    Some(skeleton.EraNarrow) -> Some(StyleNarrow)
    None -> None
  }
}

fn rfmt_year(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.year {
    Some(skeleton.YearNumeric) -> Some(StyleNumeric)
    Some(skeleton.YearTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn rfmt_month(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.month {
    Some(skeleton.MonthNumeric) -> Some(StyleNumeric)
    Some(skeleton.MonthTwoDigit) -> Some(StyleTwoDigit)
    Some(skeleton.MonthNarrow) -> Some(StyleNarrow)
    Some(skeleton.MonthShort) -> Some(StyleShort)
    Some(skeleton.MonthLong) -> Some(StyleLong)
    None -> None
  }
}

fn rfmt_day(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.day {
    Some(skeleton.DayNumeric) -> Some(StyleNumeric)
    Some(skeleton.DayTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn rfmt_hour(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.hour {
    Some(skeleton.HourNumeric) -> Some(StyleNumeric)
    Some(skeleton.HourTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn rfmt_minute(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.minute {
    Some(skeleton.MinuteNumeric) -> Some(StyleNumeric)
    Some(skeleton.MinuteTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn rfmt_second(formats: skeleton.Formats) -> Option(Style) {
  case formats.pattern_styles.second {
    Some(skeleton.SecondNumeric) -> Some(StyleNumeric)
    Some(skeleton.SecondTwoDigit) -> Some(StyleTwoDigit)
    None -> None
  }
}

fn delta_penalty(original: Style, found: Style) -> Int {
  case int.clamp(style_index(found) - style_index(original), -2, 2) + 2 {
    4 -> long_more_penalty
    3 -> short_more_penalty
    1 -> short_less_penalty
    0 -> long_less_penalty
    _ -> 0
  }
}

fn best_fit_prop_score(
  opt_style: Option(Style),
  fmt_style: Option(Style),
) -> Int {
  case opt_style, fmt_style {
    None, Some(_) -> -addition_penalty
    Some(_), None -> -removal_penalty
    Some(opt_value), Some(fmt_value) ->
      case opt_value == fmt_value {
        True -> 0
        False ->
          case style_numeric(opt_value) != style_numeric(fmt_value) {
            True -> -different_numeric_type_penalty
            False -> -delta_penalty(opt_value, fmt_value)
          }
      }
    None, None -> 0
  }
}

fn basic_prop_score(opt_style: Option(Style), fmt_style: Option(Style)) -> Int {
  case opt_style, fmt_style {
    None, Some(_) -> -addition_penalty
    Some(_), None -> -removal_penalty
    Some(opt_value), Some(fmt_value) ->
      case opt_value == fmt_value {
        True -> 0
        False -> -delta_penalty(opt_value, fmt_value)
      }
    None, None -> 0
  }
}

fn field_pairs(
  config: DateTimeFormatConfig,
  formats: skeleton.Formats,
) -> List(#(Option(Style), Option(Style))) {
  [
    #(config.weekday, fmt_weekday(formats)),
    #(config.era, fmt_era(formats)),
    #(config.year, fmt_year(formats)),
    #(config.month, fmt_month(formats)),
    #(config.day, fmt_day(formats)),
    #(None, None),
    #(config.hour, fmt_hour(formats)),
    #(config.minute, fmt_minute(formats)),
    #(config.second, fmt_second(formats)),
    #(None, fmt_fractional(formats)),
    #(cfg_tz_style(config.time_zone_name), fmt_tz(formats)),
  ]
}

fn best_fit_score(
  config: DateTimeFormatConfig,
  formats: skeleton.Formats,
) -> Int {
  let hour12_score = case
    config.hour12 == Some(True),
    formats.hour12 == Some(True)
  {
    True, False -> -removal_penalty
    False, True -> -addition_penalty
    _, _ -> 0
  }
  let pattern_era_score = case
    config.era,
    formats.era,
    formats.pattern_styles.era
  {
    None, None, Some(_) -> -addition_penalty
    _, _, _ -> 0
  }
  list.fold(
    field_pairs(config, formats),
    hour12_score + pattern_era_score,
    fn(acc, pair) { acc + best_fit_prop_score(pair.0, pair.1) },
  )
}

fn basic_score(config: DateTimeFormatConfig, formats: skeleton.Formats) -> Int {
  list.fold(field_pairs(config, formats), 0, fn(acc, pair) {
    acc + basic_prop_score(pair.0, pair.1)
  })
}

fn significance_score(
  config: DateTimeFormatConfig,
  formats: skeleton.Formats,
) -> Int {
  best_fit_prop_score(config.year, fmt_year(formats))
  * sig_year_weight
  + best_fit_prop_score(config.month, fmt_month(formats))
  * sig_month_weight
  + best_fit_prop_score(config.day, fmt_day(formats))
  * sig_day_weight
  + best_fit_prop_score(config.hour, fmt_hour(formats))
  * sig_hour_weight
  + best_fit_prop_score(config.minute, fmt_minute(formats))
  * sig_minute_weight
  + best_fit_prop_score(config.second, fmt_second(formats))
  * sig_second_weight
}

fn pick_best(
  formats: List(skeleton.Formats),
  score_fn: fn(skeleton.Formats) -> Int,
  tiebreak_fn: fn(skeleton.Formats) -> Int,
) -> skeleton.Formats {
  let assert [first, ..rest] = formats
  let #(best, _, _) =
    list.fold(rest, #(first, score_fn(first), tiebreak_fn(first)), fn(acc, fmt) {
      let #(best_fmt, best_score, best_tiebreak) = acc
      let score = score_fn(fmt)
      let tiebreak = tiebreak_fn(fmt)
      let take =
        score > best_score
        || { score == best_score && tiebreak > best_tiebreak }
        || {
          score == best_score
          && tiebreak == best_tiebreak
          && fmt.canonical
          && !best_fmt.canonical
        }
      case take {
        True -> #(fmt, score, tiebreak)
        False -> #(best_fmt, best_score, best_tiebreak)
      }
    })
  best
}

type ResolvedStyles {
  ResolvedStyles(
    weekday: Option(Style),
    era: Option(Style),
    year: Option(Style),
    month: Option(Style),
    day: Option(Style),
    hour: Option(Style),
    minute: Option(Style),
    second: Option(Style),
  )
}

fn adjust_style(best: Option(Style), req: Option(Style)) -> Option(Style) {
  case req {
    None -> best
    Some(req_style) ->
      case best {
        None -> None
        Some(best_style) ->
          case style_numeric(best_style), style_numeric(req_style) {
            True, True ->
              case best_style == StyleTwoDigit || req_style == StyleTwoDigit {
                True -> Some(StyleTwoDigit)
                False -> Some(StyleNumeric)
              }
            True, False -> best
            _, _ ->
              case best_style == req_style {
                True -> best
                False -> Some(req_style)
              }
          }
      }
  }
}

fn resolve_styles(
  best: skeleton.Formats,
  config: DateTimeFormatConfig,
  adjust: Bool,
) -> ResolvedStyles {
  ResolvedStyles(
    weekday: case adjust {
      True -> adjust_style(rfmt_weekday(best), config.weekday)
      False -> rfmt_weekday(best)
    },
    era: case adjust {
      True -> adjust_style(rfmt_era(best), config.era)
      False -> rfmt_era(best)
    },
    year: case adjust {
      True -> adjust_style(rfmt_year(best), config.year)
      False -> rfmt_year(best)
    },
    month: case adjust {
      True -> adjust_style(rfmt_month(best), config.month)
      False -> rfmt_month(best)
    },
    day: case adjust {
      True -> adjust_style(rfmt_day(best), config.day)
      False -> rfmt_day(best)
    },
    hour: case adjust {
      True -> adjust_style(rfmt_hour(best), config.hour)
      False -> rfmt_hour(best)
    },
    minute: rfmt_minute(best),
    second: rfmt_second(best),
  )
}

fn resolve_hour_cycle(
  hour_cycle_default: HourCycle,
  hour12: Option(Bool),
) -> HourCycle {
  case hour12 {
    None -> hour_cycle_default
    Some(True) ->
      case hour_cycle_default {
        H11 | H23 -> H11
        _ -> H12
      }
    Some(False) ->
      case hour_cycle_default {
        H24 -> H24
        _ -> H23
      }
  }
}

type EraSource {
  CalendarEraSource(locale.CalendarEra, Int)
}

type Ctx {
  Ctx(
    locale: locale.Locale,
    config: DateTimeFormatConfig,
    resolved: ResolvedStyles,
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    second: Int,
    weekday: Int,
    is_dst: Bool,
    offset: duration.Duration,
    zone_name: String,
    hour_cycle: HourCycle,
    months: locale.Month,
    era_source: EraSource,
    related_year: Int,
    year_name: String,
    is_leap_month: Bool,
    leap_pattern: Option(String),
  )
}

pub fn render(
  locale: locale.Locale,
  config: DateTimeFormatConfig,
  date: calendar.Date,
  time: calendar.TimeOfDay,
  is_dst: Bool,
  offset: duration.Duration,
  zone_name: String,
) -> Result(String, Nil) {
  let config = apply_defaults(config)

  let hour_cycle = resolve_hour_cycle(locale.hour_cycle, config.hour12)

  let config = case
    config.hour != None || config.minute != None || config.second != None
  {
    True ->
      DateTimeFormatConfig(
        ..config,
        hour12: Some(hour_cycle == H11 || hour_cycle == H12),
      )
    False -> config
  }

  let calendar = option.unwrap(config.calendar, locale.default_calendar)

  let calendar = case locale.load_calendar(locale, calendar) {
    Ok(calendar) -> Ok(calendar)
    Error(_) ->
      case locale.load_calendar(locale, CalendarGregory) {
        Ok(calendar) -> Ok(calendar)
        Error(_) -> Error(Nil)
      }
  }

  case calendar {
    Error(_) -> Error(Nil)
    Ok(calendar) -> {
      let #(best, resolved) = case config.format_matcher {
        Some(FormatMatcherBasic) -> {
          let best =
            pick_best(calendar.formats, basic_score(config, _), fn(_) { 0 })
          #(best, resolve_styles(best, config, False))
        }
        _ -> {
          let best =
            pick_best(
              calendar.formats,
              best_fit_score(config, _),
              significance_score(config, _),
            )
          #(best, resolve_styles(best, config, True))
        }
      }

      let Date(year:, month:, day:) = date
      let TimeOfDay(hours:, minutes:, seconds:, ..) = time
      let month = calendar.month_to_int(month)
      let weekday = day_of_week(year, month, day)

      Ok(case calendar.calendar {
        CalendarIso8601 ->
          int.to_string(year)
          <> "-"
          <> two_digit(month)
          <> "-"
          <> two_digit(day)
        _ -> {
          let converted =
            chronology.convert(calendar.calendar, year, month, day)

          let selected_pattern = case best.hour {
            Some(_) -> {
              case hour_cycle {
                H11 | H12 -> best.pattern12
                _ -> best.pattern
              }
            }
            None -> best.pattern
          }
          let selected_pattern = case
            config.hour == None
            && config.minute == None
            && config.second == None
            && config.time_zone_name != None
          {
            True -> drop_time_fields(selected_pattern)
            False -> selected_pattern
          }
          render_pattern(
            selected_pattern,
            Ctx(
              locale:,
              config:,
              resolved:,
              year: converted.year,
              month: converted.month,
              day: converted.day,
              hour: hours,
              minute: minutes,
              second: seconds,
              weekday:,
              is_dst:,
              offset:,
              zone_name:,
              hour_cycle:,
              months: calendar.month,
              era_source: CalendarEraSource(calendar.era, converted.era_index),
              related_year: converted.related_year,
              year_name: case
                dict.get(calendar.year_names, converted.year_name_index)
              {
                Ok(name) -> name
                Error(_) -> ""
              },
              is_leap_month: converted.is_leap_month,
              leap_pattern: calendar.leap_month,
            ),
          )
        }
      })
    }
  }
}

fn is_time_field(field: pattern.Pattern) -> Bool {
  case field {
    pattern.AmPm
    | pattern.AmPmNoonMidnight
    | pattern.FlexibleDayPeriod
    | pattern.Hour12
    | pattern.Hour24
    | pattern.Hour11
    | pattern.Hour24From1
    | pattern.PreferredHour
    | pattern.PreferredHourNoPeriod
    | pattern.FlexibleHour
    | pattern.Minute
    | pattern.Second
    | pattern.FractionalSecond
    | pattern.MillisecondsInDay -> True
    _ -> False
  }
}

fn drop_time_fields(nodes: List(pattern.Node)) -> List(pattern.Node) {
  let #(kept, pending) =
    list.fold(list.reverse(nodes), #([], []), fn(acc, node) {
      let #(kept, pending) = acc
      case node {
        pattern.NodeText(_) -> #(kept, [node, ..pending])
        pattern.NodeField(pattern.Field(field, _)) ->
          case is_time_field(field) {
            True -> #(kept, [])
            False -> #([node, ..list.append(pending, kept)], [])
          }
      }
    })
  list.append(pending, kept)
}

fn render_pattern(nodes: List(pattern.Node), ctx: Ctx) -> String {
  nodes
  |> list.map(fn(node) {
    case node {
      pattern.NodeText(text) -> text
      pattern.NodeField(pattern.Field(field, _)) -> render_field(field, ctx)
    }
  })
  |> string.concat
  |> string.replace("\u{E000}", select_connector(ctx.locale, ctx.resolved))
  |> normalize_spaces
}

fn select_connector(locale: locale.Locale, resolved: ResolvedStyles) -> String {
  let connectors = locale.date_time_connectors
  case resolved.month {
    Some(StyleLong) ->
      case resolved.weekday {
        Some(_) -> connectors.full
        None -> connectors.long
      }
    Some(StyleShort) -> connectors.medium
    _ -> connectors.short
  }
}

fn normalize_spaces(text: String) -> String {
  text
  |> string.replace("\u{00A0}", " ")
  |> string.replace("\u{202F}", " ")
  |> string.replace("\u{2009}", " ")
}

fn render_field(field: pattern.Pattern, ctx: Ctx) -> String {
  case field {
    pattern.Era -> render_era(ctx)
    pattern.CalendarYear | pattern.WeekYear | pattern.ExtendedYear ->
      localize_digits(
        ctx.locale.numbering_system,
        render_number(ctx.resolved.year, year_value(ctx.year)),
      )
    pattern.RelatedGregorianYear ->
      localize_digits(
        ctx.locale.numbering_system,
        int.to_string(ctx.related_year),
      )
    pattern.CyclicYearName -> ctx.year_name
    pattern.Month | pattern.StandAloneMonth ->
      localize_digits(ctx.locale.numbering_system, render_month(ctx))
    pattern.DayOfMonth
    | pattern.DayOfYear
    | pattern.DayOfWeekInMonth
    | pattern.ModifiedJulianDay ->
      localize_digits(
        ctx.locale.numbering_system,
        render_number(ctx.resolved.day, ctx.day),
      )
    pattern.DayOfWeek | pattern.LocalDayOfWeek | pattern.StandAloneDayOfWeek ->
      render_weekday(ctx)
    pattern.Hour12 | pattern.Hour24 | pattern.Hour11 | pattern.Hour24From1 ->
      localize_digits(
        ctx.locale.numbering_system,
        render_number(ctx.resolved.hour, hour_value(ctx)),
      )
    pattern.Minute ->
      localize_digits(
        ctx.locale.numbering_system,
        render_number(ctx.resolved.minute, ctx.minute),
      )
    pattern.Second | pattern.FractionalSecond | pattern.MillisecondsInDay ->
      localize_digits(
        ctx.locale.numbering_system,
        render_number(ctx.resolved.second, ctx.second),
      )
    pattern.AmPm | pattern.AmPmNoonMidnight | pattern.FlexibleDayPeriod ->
      case ctx.hour > 11 {
        True -> ctx.locale.pm
        False -> ctx.locale.am
      }
    pattern.ShortSpecificZone
    | pattern.IsoBasicZone
    | pattern.ShortLocalizedGmt
    | pattern.ShortGenericZone
    | pattern.TimeZoneId
    | pattern.IsoBasicZoneX
    | pattern.IsoBasicZonex ->
      localize_digits(ctx.locale.numbering_system, render_tz(ctx))
    _ -> ""
  }
}

fn render_number(style: Option(Style), value: Int) -> String {
  case style {
    Some(StyleTwoDigit) -> two_digit(value)
    _ -> int.to_string(value)
  }
}

fn year_value(year: Int) -> Int {
  case year <= 0 {
    True -> 1 - year
    False -> year
  }
}

fn hour_value(ctx: Ctx) -> Int {
  case ctx.hour_cycle {
    H11 -> ctx.hour % 12
    H12 ->
      case ctx.hour % 12 {
        0 -> 12
        mod_hour -> mod_hour
      }
    H24 ->
      case ctx.hour {
        0 -> 24
        raw_hour -> raw_hour
      }
    _ -> ctx.hour
  }
}

fn render_month(ctx: Ctx) -> String {
  let name = case ctx.resolved.month {
    Some(StyleTwoDigit) -> two_digit(ctx.month)
    Some(StyleNarrow) -> name_at(ctx.months.narrow, ctx.month - 1)
    Some(StyleShort) -> name_at(ctx.months.short, ctx.month - 1)
    Some(StyleLong) -> name_at(ctx.months.long, ctx.month - 1)
    _ -> int.to_string(ctx.month)
  }
  case ctx.is_leap_month, ctx.leap_pattern {
    True, Some(pat) -> string.replace(pat, "{0}", name)
    _, _ -> name
  }
}

fn render_weekday(ctx: Ctx) -> String {
  case ctx.resolved.weekday {
    Some(StyleNarrow) -> name_at(ctx.locale.weekday.narrow, ctx.weekday)
    Some(StyleShort) -> name_at(ctx.locale.weekday.short, ctx.weekday)
    _ -> name_at(ctx.locale.weekday.long, ctx.weekday)
  }
}

fn render_era(ctx: Ctx) -> String {
  case ctx.era_source {
    CalendarEraSource(era, index) -> {
      let names = case ctx.resolved.era {
        Some(StyleNarrow) -> era.narrow
        Some(StyleShort) -> era.short
        _ -> era.long
      }
      case dict.get(names, index) {
        Ok(name) -> name
        Error(_) -> "ERA" <> int.to_string(index)
      }
    }
  }
}

fn render_tz(ctx: Ctx) -> String {
  let data = dict.get(ctx.locale.time_zone_name, ctx.zone_name)
  case ctx.config.time_zone_name {
    Some(TimeZoneNameShort) -> tz_from_list(data, "short", False, ctx)
    Some(TimeZoneNameLong) -> tz_from_list(data, "long", False, ctx)
    Some(TimeZoneNameShortGeneric) -> tz_from_list(data, "short", True, ctx)
    Some(TimeZoneNameLongGeneric) -> tz_from_list(data, "long", True, ctx)
    Some(TimeZoneNameShortOffset) -> offset_gmt(ctx, "short")
    Some(TimeZoneNameLongOffset) -> offset_gmt(ctx, "long")
    None -> ""
  }
}

fn tz_from_list(
  data: Result(locale.TimeZone, Nil),
  which: String,
  generic: Bool,
  ctx: Ctx,
) -> String {
  let gmt_style = case which {
    "short" -> "short"
    _ -> "long"
  }
  case data {
    Error(_) -> offset_gmt(ctx, gmt_style)
    Ok(time_zone_data) -> {
      let names = case which {
        "short" -> time_zone_data.short
        _ -> time_zone_data.long
      }
      case names, generic {
        [_standard, _daylight, generic_name, ..], True -> generic_name
        [], _ -> offset_gmt(ctx, gmt_style)
        [standard], _ -> standard
        [standard, daylight, ..], _ ->
          case ctx.is_dst {
            True ->
              case standard == daylight {
                True -> offset_gmt(ctx, gmt_style)
                False -> daylight
              }
            False -> standard
          }
      }
    }
  }
}

fn offset_gmt(ctx: Ctx, style: String) -> String {
  offset_to_gmt_string(
    ctx.locale.gmt_format,
    ctx.locale.hour_format,
    ctx.offset,
    style,
  )
}

fn offset_to_gmt_string(
  gmt_format: String,
  hour_format: String,
  offset: duration.Duration,
  style: String,
) -> String {
  let offset_ms = duration.to_milliseconds(offset)
  let offset_in_minutes = offset_ms / 60_000
  let mins = int.absolute_value(offset_in_minutes) % 60
  let hours = int.absolute_value(offset_in_minutes) / 60
  let #(positive, negative) = case string.split_once(hour_format, ";") {
    Ok(#(p, n)) -> #(p, n)
    Error(_) -> #(hour_format, hour_format)
  }
  let pattern = case offset_ms < 0 {
    True -> negative
    False -> positive
  }

  let offset_str = case style {
    "long" ->
      pattern
      |> string.replace("HH", two_digit(hours))
      |> string.replace("H", int.to_string(hours))
      |> string.replace("mm", two_digit(mins))
      |> string.replace("m", int.to_string(mins))
    _ ->
      case mins != 0 || hours != 0 {
        False -> ""
        True -> {
          let pattern = case mins == 0 {
            True -> strip_minute_run(pattern)
            False -> pattern
          }
          pattern
          |> replace_char_run("H", int.to_string(hours))
          |> replace_char_run("m", int.to_string(mins))
        }
      }
  }

  string.replace(gmt_format, "{0}", offset_str)
}

fn strip_minute_run(pattern: String) -> String {
  strip_minute_run_loop(string.to_graphemes(pattern), [])
  |> list.reverse
  |> string.concat
}

fn strip_minute_run_loop(
  chars: List(String),
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> acc
    [":", "m", ..rest] -> strip_minute_run_loop(drop_run(rest, "m"), acc)
    ["m", ..rest] -> strip_minute_run_loop(drop_run(rest, "m"), acc)
    [char, ..rest] -> strip_minute_run_loop(rest, [char, ..acc])
  }
}

fn replace_char_run(
  pattern: String,
  target: String,
  replacement: String,
) -> String {
  replace_char_run_loop(string.to_graphemes(pattern), target, replacement, [])
  |> list.reverse
  |> string.concat
}

fn replace_char_run_loop(
  chars: List(String),
  target: String,
  replacement: String,
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> acc
    [char, ..rest] ->
      case char == target {
        True ->
          replace_char_run_loop(drop_run(rest, target), target, replacement, [
            replacement,
            ..acc
          ])
        False -> replace_char_run_loop(rest, target, replacement, [char, ..acc])
      }
  }
}

fn drop_run(chars: List(String), target: String) -> List(String) {
  case chars {
    [char, ..rest] if char == target -> drop_run(rest, target)
    _ -> chars
  }
}

fn numbering_system_base(numbering_system: List(String)) -> Option(Int) {
  case numbering_system {
    ["arab", ..] -> Some(0x0660)
    ["arabext", ..] -> Some(0x06F0)
    ["adlm", ..] -> Some(0x1E950)
    ["deva", ..] -> Some(0x0966)
    ["beng", ..] -> Some(0x09E6)
    ["hmnp", ..] -> Some(0x1E140)
    ["cakm", ..] -> Some(0x11136)
    ["olck", ..] -> Some(0x1C50)
    ["tibt", ..] -> Some(0x0F20)
    ["mtei", ..] -> Some(0xABF0)
    ["mymr", ..] -> Some(0x1040)
    ["nkoo", ..] -> Some(0x07C0)
    _ -> None
  }
}

fn digit_value(grapheme: String) -> Option(Int) {
  case grapheme {
    "0" -> Some(0)
    "1" -> Some(1)
    "2" -> Some(2)
    "3" -> Some(3)
    "4" -> Some(4)
    "5" -> Some(5)
    "6" -> Some(6)
    "7" -> Some(7)
    "8" -> Some(8)
    "9" -> Some(9)
    _ -> None
  }
}

fn localize_digits(numbering_system: List(String), text: String) -> String {
  case numbering_system_base(numbering_system) {
    None -> text
    Some(base) ->
      string.to_graphemes(text)
      |> list.map(fn(grapheme) {
        case digit_value(grapheme) {
          Some(digit) ->
            case string.utf_codepoint(base + digit) {
              Ok(codepoint) -> string.from_utf_codepoints([codepoint])
              Error(_) -> grapheme
            }
          None -> grapheme
        }
      })
      |> string.concat
  }
}

fn two_digit(value: Int) -> String {
  let digit_str = int.to_string(value)
  let digit_str = case string.length(digit_str) < 2 {
    True -> "0" <> digit_str
    False -> digit_str
  }
  string.slice(digit_str, string.length(digit_str) - 2, 2)
}

fn name_at(names: dict.Dict(Int, String), index: Int) -> String {
  case dict.get(names, index) {
    Ok(name) -> name
    Error(_) -> ""
  }
}

fn day_of_week(year: Int, month: Int, day: Int) -> Int {
  let adjusted_year = case month <= 2 {
    True -> year - 1
    False -> year
  }
  let era_year = case adjusted_year >= 0 {
    True -> adjusted_year
    False -> adjusted_year - 399
  }
  let era_num = era_year / 400
  let yoe = adjusted_year - era_num * 400
  let month_prime = case month > 2 {
    True -> month - 3
    False -> month + 9
  }
  let doy = { 153 * month_prime + 2 } / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  let days = era_num * 146_097 + doe - 719_468
  { { days + 4 } % 7 + 7 } % 7
}

pub type TimeZoneName {
  TimeZoneNameShort
  TimeZoneNameLong
  TimeZoneNameShortOffset
  TimeZoneNameLongOffset
  TimeZoneNameShortGeneric
  TimeZoneNameLongGeneric
}

pub type FormatMatcher {
  FormatMatcherBestFit
  FormatMatcherBasic
}

pub type DateTimeFormatConfig {
  DateTimeFormatConfig(
    calendar: Option(Chronology),
    weekday: Option(Style),
    era: Option(Style),
    year: Option(Style),
    month: Option(Style),
    day: Option(Style),
    hour: Option(Style),
    minute: Option(Style),
    second: Option(Style),
    time_zone_name: Option(TimeZoneName),
    format_matcher: Option(FormatMatcher),
    hour12: Option(Bool),
  )
}
