import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/calendar/calendar
import intldate/internal/icu/calendar/gregocal.{type CalendarFields}
import intldate/internal/icu/calendar/hebrwcal
import intldate/internal/icu/calendar/timezone
import intldate/internal/icu/dtfmt/dayperiodrules
import intldate/internal/icu/dtfmt/dtfmtsym
import intldate/internal/icu/dtfmt/tznames
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/zonemeta
import intldate/internal/icu/numfmt/decimfmt
import intldate/internal/math

pub type PatternToken {
  LiteralToken(text: String)
  FieldToken(ch: String, count: Int)
}

pub type HourMinuteSplit {
  HourMinuteSplit(prefix: String, sep: String, suffix: String)
}

pub type SubFormatContext {
  SubFormatContext(
    bundle: Bundle,
    chain: List(bundle.LocaleChainEntry),
    locale_id: String,
    cal_type: String,
    fields: CalendarFields,
    raw_offset: Int,
    dst_offset: Int,
    canonical_tzid: Option(String),
    tzid: String,
    epoch_millis: Int,
    digits: decimfmt.Digits,
    gannen_year_numbering: Bool,
    has_date_anchor_field: Bool,
    has_minute: Bool,
    has_second: Bool,
    tokens: List(PatternToken),
  )
}

pub type RenderedFormatPart {
  RenderedFormatPart(
    type_: String,
    ch: Option(String),
    value: String,
    start: Int,
    end: Int,
  )
}

pub type FormatResult {
  FormatResult(formatted: String, parts: List(RenderedFormatPart))
}

pub type DateFormatter {
  DateFormatter(
    bundle: Bundle,
    locale_id: String,
    cal_type: String,
    tz: String,
    pattern: String,
    chain: List(bundle.LocaleChainEntry),
    canonical_tzid: Option(String),
    digits: decimfmt.Digits,
    gannen_year_numbering: Bool,
    has_date_anchor_field: Bool,
    has_minute: Bool,
    has_second: Bool,
    tokens: List(PatternToken),
  )
}

pub type FormatForFieldsResult {
  FormatForFieldsResult(formatted: String, parts: List(RenderedFormatPart))
}

fn zonemeta_bundle(bundle: Bundle) -> Bundle {
  bundle
}

fn code_points(s: String) -> List(String) {
  string.to_graphemes(s)
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

fn is_ascii_letter(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

pub fn tokenize_pattern(pattern: String) -> List(PatternToken) {
  tokenize_pattern_loop(code_points(pattern))
}

fn tokenize_pattern_loop(chars: List(String)) -> List(PatternToken) {
  case chars {
    [] -> []
    ["'", "'", ..rest] -> [LiteralToken("'"), ..tokenize_pattern_loop(rest)]
    ["'", ..rest] -> {
      let #(text, rest) = read_quoted_literal(rest, "")
      [LiteralToken(text), ..tokenize_pattern_loop(rest)]
    }
    [c, ..rest] ->
      case is_ascii_letter(c) {
        True -> {
          let #(count, rest) = count_same_char(rest, c, 1)
          [FieldToken(c, count), ..tokenize_pattern_loop(rest)]
        }
        False -> [LiteralToken(c), ..tokenize_pattern_loop(rest)]
      }
  }
}

fn read_quoted_literal(
  chars: List(String),
  acc: String,
) -> #(String, List(String)) {
  case chars {
    [] -> #(acc, [])
    ["'", "'", ..rest] -> read_quoted_literal(rest, acc <> "'")
    ["'", ..rest] -> #(acc, rest)
    [c, ..rest] -> read_quoted_literal(rest, acc <> c)
  }
}

fn count_same_char(
  chars: List(String),
  target: String,
  count: Int,
) -> #(Int, List(String)) {
  case chars {
    [c, ..rest] if c == target -> count_same_char(rest, target, count + 1)
    _ -> #(count, chars)
  }
}

fn proper_mod(value: Int, modulus: Int) -> Int {
  { { value % modulus } + modulus } % modulus
}

fn zero_pad(
  value: Int,
  min_digits: Int,
  max_digits: Int,
  digits: decimfmt.Digits,
) -> String {
  let modulus = math.pow10(max_digits)
  let v = proper_mod(value, modulus)
  let s = int.to_string(int.absolute_value(v))
  let s = string.pad_start(s, min_digits, "0")
  let signed = case v < 0 {
    True -> "-" <> s
    False -> s
  }
  case decimfmt.digits_are_ascii(digits) {
    True -> signed
    False -> decimfmt.localize_digits(signed, digits)
  }
}

fn zero_padding_number(
  value: Int,
  min_digits: Int,
  max_digits: Int,
  digits: decimfmt.Digits,
) -> String {
  zero_pad(value, min_digits, max_digits, digits)
}

fn month_quarter_width(count: Int) -> String {
  case count {
    3 -> "abbreviated"
    4 -> "wide"
    _ -> "narrow"
  }
}

fn weekday_width(count: Int) -> String {
  case count <= 3 {
    True -> "abbreviated"
    False ->
      case count == 4 {
        True -> "wide"
        False ->
          case count == 5 {
            True -> "narrow"
            False -> "short"
          }
      }
  }
}

fn era_width(count: Int) -> String {
  case count <= 3 {
    True -> "abbreviated"
    False ->
      case count == 4 {
        True -> "wide"
        False -> "narrow"
      }
  }
}

fn day_period_width(count: Int) -> String {
  case count <= 3 {
    True -> "abbreviated"
    False ->
      case count == 5 {
        True -> "narrow"
        False -> "wide"
      }
  }
}

fn format_japanese_year(year: Int) -> String {
  case year == 1 {
    True -> "元"
    False -> int.to_string(year)
  }
}

fn pattern_contains_nen(pattern: String) -> Bool {
  string.contains(pattern, "年")
}

fn uses_gannen_year_numbering(
  cal_type: String,
  locale_id: String,
  pattern: String,
) -> Bool {
  cal_type == "japanese"
  && uloc.get_language(Some(locale_id)) == "ja"
  && pattern_contains_nen(pattern)
}

fn related_year_difference(cal_type: String) -> Int {
  case cal_type {
    "coptic" -> 284
    "ethiopic" -> 8
    "ethiopic-amete-alem" -> 8
    "indian" -> 79
    "persian" -> 622
    "hebrew" -> -3760
    _ -> 0
  }
}

fn is_islamic_cal_type(cal_type: String) -> Bool {
  case cal_type {
    "islamic"
    | "islamic-rgsa"
    | "islamic-civil"
    | "islamic-tbla"
    | "islamic-umalqura" -> True
    _ -> False
  }
}

fn trunc_div(a: Int, b: Int) -> Int {
  a / b
}

fn gregoyear_from_islamic_start(year: Int) -> Int {
  let shift = case year >= 1397 {
    True -> {
      let cycle = trunc_div(year - 1397, 67)
      let offset = { year - 1397 } % 67
      case offset >= 33 {
        True -> 2 * cycle + 1
        False -> 2 * cycle
      }
    }
    False -> {
      let cycle = trunc_div(year - 1396, 67) - 1
      let offset = -{ { year - 1396 } % 67 }
      case offset <= 33 {
        True -> 2 * cycle + 1
        False -> 2 * cycle
      }
    }
  }
  year + 579 - shift
}

fn get_related_year(cal_type: String, extended_year: Int) -> Int {
  case is_islamic_cal_type(cal_type) {
    True -> gregoyear_from_islamic_start(extended_year)
    False -> extended_year + related_year_difference(cal_type)
  }
}

fn pad2(n: Int, digits: decimfmt.Digits) -> String {
  let s = case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
  case decimfmt.digits_are_ascii(digits) {
    True -> s
    False -> decimfmt.localize_digits(s, digits)
  }
}

fn format_offset_iso8601(
  offset_millis: Int,
  is_basic: Bool,
  use_utc_indicator: Bool,
  is_short: Bool,
  ignore_seconds: Bool,
) -> String {
  let abs_offset = int.absolute_value(offset_millis)
  case
    use_utc_indicator
    && { abs_offset < 1000 || { ignore_seconds && abs_offset < 60_000 } }
  {
    True -> "Z"
    False -> {
      let min_fields = case is_short {
        True -> 0
        False -> 1
      }
      let max_fields = case ignore_seconds {
        True -> 1
        False -> 2
      }
      let sep = case is_basic {
        True -> ""
        False -> ":"
      }

      let f0 = abs_offset / 3_600_000
      let rem1 = abs_offset % 3_600_000
      let f1 = rem1 / 60_000
      let rem2 = rem1 % 60_000
      let f2 = rem2 / 1000
      let fields = #(f0, f1, f2)

      let last_idx = find_last_idx(fields, max_fields, min_fields)

      let sign = case offset_millis < 0 {
        True ->
          case any_nonzero(fields, 0, last_idx) {
            True -> "-"
            False -> "+"
          }
        False -> "+"
      }

      sign <> build_offset_fields(fields, 0, last_idx, sep)
    }
  }
}

fn field_at(fields: #(Int, Int, Int), idx: Int) -> Int {
  let #(a, b, c) = fields
  case idx {
    0 -> a
    1 -> b
    _ -> c
  }
}

fn find_last_idx(fields: #(Int, Int, Int), from: Int, min_fields: Int) -> Int {
  case from > min_fields && field_at(fields, from) == 0 {
    True -> find_last_idx(fields, from - 1, min_fields)
    False -> from
  }
}

fn any_nonzero(fields: #(Int, Int, Int), idx: Int, last_idx: Int) -> Bool {
  case idx > last_idx {
    True -> False
    False ->
      case field_at(fields, idx) != 0 {
        True -> True
        False -> any_nonzero(fields, idx + 1, last_idx)
      }
  }
}

fn build_offset_fields(
  fields: #(Int, Int, Int),
  idx: Int,
  last_idx: Int,
  sep: String,
) -> String {
  case idx > last_idx {
    True -> ""
    False -> {
      let prefix = case sep != "" && idx != 0 {
        True -> sep
        False -> ""
      }
      prefix
      <> string.pad_start(int.to_string(field_at(fields, idx)), 2, "0")
      <> build_offset_fields(fields, idx + 1, last_idx, sep)
    }
  }
}

fn split_hour_minute_pattern(hm: String) -> HourMinuteSplit {
  case string.split_once(hm, "mm") {
    Error(_) -> HourMinuteSplit(prefix: "", sep: "", suffix: hm)
    Ok(#(before_m, after_m)) -> {
      let m_idx = string.length(before_m)
      let before_m = string.slice(hm, 0, m_idx)
      let h_end = last_h_index(before_m) + 1
      let h_start = find_h_start(before_m, h_end - 1)
      HourMinuteSplit(
        prefix: string.slice(hm, 0, h_start),
        sep: string.slice(hm, h_end, m_idx - h_end),
        suffix: after_m,
      )
    }
  }
}

fn last_h_index(s: String) -> Int {
  last_h_index_loop(code_points(s), 0, -1)
}

fn last_h_index_loop(chars: List(String), i: Int, best: Int) -> Int {
  case chars {
    [] -> best
    [c, ..rest] -> {
      let best = case c == "H" {
        True -> i
        False -> best
      }
      last_h_index_loop(rest, i + 1, best)
    }
  }
}

fn find_h_start(s: String, h_end_minus_one: Int) -> Int {
  find_h_start_loop(s, h_end_minus_one)
}

fn find_h_start_loop(s: String, i: Int) -> Int {
  case i > 0 && string.slice(s, i - 1, 1) == "H" {
    True -> find_h_start_loop(s, i - 1)
    False -> i
  }
}

fn find_zone_strings_chain(
  bundle: Bundle,
  locale_id: String,
) -> List(tznames.ZoneChainEntry) {
  tznames.get_zone_strings_chain(bundle, locale_id)
}

fn get_zone_strings_table(
  bundle: Bundle,
  zone_chain: List(tznames.ZoneChainEntry),
  key: String,
) -> Option(String) {
  tznames.get_zone_strings_global(bundle, zone_chain, key)
}

fn format_offset_localized_gmt(
  bundle: Bundle,
  locale_id: String,
  offset_millis: Int,
  is_short: Bool,
  digits: decimfmt.Digits,
) -> String {
  let zone_chain = find_zone_strings_chain(bundle, locale_id)
  let gmt_format = case
    get_zone_strings_table(bundle, zone_chain, "gmtFormat")
  {
    Some(f) -> f
    None -> "GMT{0}"
  }
  let hour_format = case
    get_zone_strings_table(bundle, zone_chain, "hourFormat")
  {
    Some(f) -> f
    None -> "+HH:mm;-HH:mm"
  }
  let #(pos_pattern, neg_pattern) = case string.split_once(hour_format, ";") {
    Ok(#(a, b)) -> #(a, b)
    Error(_) -> #(hour_format, hour_format)
  }
  let positive = offset_millis >= 0
  let split = case positive {
    True -> split_hour_minute_pattern(pos_pattern)
    False -> split_hour_minute_pattern(neg_pattern)
  }

  let off = int.absolute_value(offset_millis)
  let h = off / 3_600_000
  let off = off % 3_600_000
  let m = off / 60_000
  let off = off % 60_000
  let s = off / 1000

  let hour_str = case is_short {
    True -> decimfmt.localize_digits(int.to_string(h), digits)
    False -> pad2(h, digits)
  }
  let hm = split.prefix <> hour_str
  let hm = case s != 0 {
    True -> hm <> split.sep <> pad2(m, digits) <> split.sep <> pad2(s, digits)
    False ->
      case m != 0 || !is_short {
        True -> hm <> split.sep <> pad2(m, digits)
        False -> hm
      }
  }
  let hm = hm <> split.suffix
  string_replace_once(gmt_format, "{0}", hm)
}

fn string_replace_once(
  s: String,
  needle: String,
  replacement: String,
) -> String {
  case string.split_once(s, needle) {
    Error(_) -> s
    Ok(#(before, after)) -> before <> replacement <> after
  }
}

fn sub_format_era(ctx: SubFormatContext, count: Int) -> String {
  case ctx.cal_type == "iso8601" {
    True -> ""
    False ->
      case ctx.cal_type == "chinese" || ctx.cal_type == "dangi" {
        True -> zero_padding_number(ctx.fields.era, 1, 9, ctx.digits)
        False ->
          option.unwrap(
            dtfmtsym.get_era_name(
              ctx.bundle,
              ctx.chain,
              ctx.cal_type,
              era_width(count),
              ctx.fields.era,
            ),
            "",
          )
      }
  }
}

fn sub_format_year(ctx: SubFormatContext, ch: String, count: Int) -> String {
  case ch {
    "y" ->
      case ctx.gannen_year_numbering {
        True -> format_japanese_year(ctx.fields.year)
        False ->
          case count == 2 {
            True -> zero_padding_number(ctx.fields.year, 2, 2, ctx.digits)
            False -> zero_padding_number(ctx.fields.year, count, 10, ctx.digits)
          }
      }
    "Y" ->
      case count == 2 {
        True ->
          zero_padding_number(
            ctx.fields.common.year_of_week_of_year,
            2,
            2,
            ctx.digits,
          )
        False ->
          zero_padding_number(
            ctx.fields.common.year_of_week_of_year,
            count,
            10,
            ctx.digits,
          )
      }
    "u" -> zero_padding_number(ctx.fields.extended_year, count, 10, ctx.digits)
    "r" ->
      zero_padding_number(
        get_related_year(ctx.cal_type, ctx.fields.extended_year),
        count,
        10,
        ctx.digits,
      )
    "U" -> {
      let cyclic_name = case
        ctx.cal_type == "chinese" || ctx.cal_type == "dangi"
      {
        True ->
          dtfmtsym.get_cyclic_year_name(
            ctx.bundle,
            ctx.chain,
            ctx.cal_type,
            ctx.fields.year,
          )
        False -> None
      }
      case cyclic_name {
        Some(name) -> name
        None ->
          case count == 2 {
            True -> zero_padding_number(ctx.fields.year, 2, 2, ctx.digits)
            False -> zero_padding_number(ctx.fields.year, count, 10, ctx.digits)
          }
      }
    }
    _ -> ""
  }
}

fn sub_format_quarter(ctx: SubFormatContext, ch: String, count: Int) -> String {
  case count <= 2 {
    True ->
      zero_padding_number(ctx.fields.common.quarter + 1, count, 10, ctx.digits)
    False -> {
      let context = case ch == "Q" {
        True -> "format"
        False -> "stand-alone"
      }
      option.unwrap(
        dtfmtsym.get_quarter_name(
          ctx.bundle,
          ctx.chain,
          ctx.cal_type,
          context,
          month_quarter_width(count),
          ctx.fields.common.quarter,
        ),
        "",
      )
    }
  }
}

fn hebrew_adjusted_month(ctx: SubFormatContext, count: Int) -> Int {
  let month = ctx.fields.common.month
  let leap = hebrwcal.is_leap_year(ctx.fields.year)
  case count >= 3 {
    True ->
      case leap && month == 6 {
        True -> 13
        False -> month
      }
    False ->
      case !leap && month >= 6 {
        True -> month - 1
        False -> month
      }
  }
}

fn sub_format_month(ctx: SubFormatContext, ch: String, count: Int) -> String {
  let month = case ctx.cal_type == "hebrew" {
    True -> hebrew_adjusted_month(ctx, count)
    False -> ctx.fields.common.month
  }
  let is_leap_month = case
    ctx.cal_type == "chinese" || ctx.cal_type == "dangi"
  {
    True -> ctx.fields.common.is_leap_month
    False -> False
  }
  case count <= 2 {
    True -> {
      let number_text = zero_padding_number(month + 1, count, 10, ctx.digits)
      case is_leap_month {
        False -> number_text
        True ->
          dtfmtsym.apply_leap_month_pattern(
            dtfmtsym.get_leap_month_pattern(
              ctx.bundle,
              ctx.chain,
              ctx.cal_type,
              "format",
              "numeric",
            ),
            number_text,
          )
      }
    }
    False ->
      case
        ctx.cal_type == "iso8601"
        && { count == 4 || { count == 3 && ctx.has_date_anchor_field } }
      {
        True -> ""
        False -> {
          let context = case ch == "M" {
            True -> "format"
            False -> "stand-alone"
          }
          let month_text =
            option.unwrap(
              dtfmtsym.get_month_name(
                ctx.bundle,
                ctx.chain,
                ctx.cal_type,
                context,
                month_quarter_width(count),
                month,
              ),
              "",
            )
          case is_leap_month {
            False -> month_text
            True ->
              dtfmtsym.apply_leap_month_pattern(
                dtfmtsym.get_leap_month_pattern(
                  ctx.bundle,
                  ctx.chain,
                  ctx.cal_type,
                  context,
                  month_quarter_width(count),
                ),
                month_text,
              )
          }
        }
      }
  }
}

fn sub_format_weekday(ctx: SubFormatContext, ch: String, count: Int) -> String {
  let context = case ch == "c" {
    True -> "stand-alone"
    False -> "format"
  }
  case ch == "c" && count <= 2 {
    True ->
      zero_padding_number(
        ctx.fields.common.day_of_week_local,
        1,
        10,
        ctx.digits,
      )
    False ->
      case ch == "e" && count <= 2 {
        True ->
          zero_padding_number(
            ctx.fields.common.day_of_week_local,
            count,
            10,
            ctx.digits,
          )
        False ->
          option.unwrap(
            dtfmtsym.get_day_name(
              ctx.bundle,
              ctx.chain,
              ctx.cal_type,
              context,
              weekday_width(count),
              ctx.fields.common.day_of_week,
            ),
            "",
          )
      }
  }
}

fn sub_format_day_period(
  ctx: SubFormatContext,
  ch: String,
  count: Int,
) -> String {
  case ch == "a" {
    True ->
      option.unwrap(
        dtfmtsym.get_am_pm(
          ctx.bundle,
          ctx.chain,
          ctx.cal_type,
          day_period_width(count),
          ctx.fields.common.am_pm,
        ),
        "",
      )
    False -> {
      let minute = case ctx.has_minute {
        True -> ctx.fields.common.minute
        False -> 0
      }
      let second = case ctx.has_second {
        True -> ctx.fields.common.second
        False -> 0
      }
      case ch == "b" {
        True -> sub_format_day_period_b(ctx, count, minute, second)
        False -> sub_format_day_period_flexible(ctx, count, minute, second)
      }
    }
  }
}

fn am_pm_fallback(ctx: SubFormatContext, count: Int) -> String {
  option.unwrap(
    dtfmtsym.get_am_pm(
      ctx.bundle,
      ctx.chain,
      ctx.cal_type,
      day_period_width(count),
      ctx.fields.common.am_pm,
    ),
    "",
  )
}

fn sub_format_day_period_b(
  ctx: SubFormatContext,
  count: Int,
  minute: Int,
  second: Int,
) -> String {
  let is_noon =
    ctx.fields.common.hour_of_day == 12 && minute == 0 && second == 0
  case is_noon {
    True ->
      case
        dtfmtsym.get_day_period_name(
          ctx.bundle,
          ctx.chain,
          ctx.cal_type,
          "format",
          day_period_width(count),
          "noon",
        )
      {
        Some(s) -> s
        None -> am_pm_fallback(ctx, count)
      }
    False -> am_pm_fallback(ctx, count)
  }
}

fn sub_format_day_period_flexible(
  ctx: SubFormatContext,
  count: Int,
  minute: Int,
  second: Int,
) -> String {
  case dayperiodrules.get_day_period_rule_set(ctx.bundle, ctx.locale_id) {
    None -> am_pm_fallback(ctx, count)
    Some(rule_set) -> {
      let hour_of_day = ctx.fields.common.hour_of_day
      let period_name = case
        hour_of_day == 0 && minute == 0 && second == 0 && rule_set.has_midnight
      {
        True -> "midnight"
        False ->
          case
            hour_of_day == 12 && minute == 0 && second == 0 && rule_set.has_noon
          {
            True -> "noon"
            False -> day_period_for_hour_name(rule_set, hour_of_day)
          }
      }
      let s = case
        period_name != "am" && period_name != "pm" && period_name != "midnight"
      {
        True ->
          dtfmtsym.get_day_period_name(
            ctx.bundle,
            ctx.chain,
            ctx.cal_type,
            "format",
            day_period_width(count),
            period_name,
          )
        False -> None
      }
      let #(period_name, s) = case
        { s == None || s == Some("") }
        && { period_name == "midnight" || period_name == "noon" }
      {
        True -> {
          let period_name = day_period_for_hour_name(rule_set, hour_of_day)
          let s = case period_name != "am" && period_name != "pm" {
            True ->
              dtfmtsym.get_day_period_name(
                ctx.bundle,
                ctx.chain,
                ctx.cal_type,
                "format",
                day_period_width(count),
                period_name,
              )
            False -> None
          }
          #(period_name, s)
        }
        False -> #(period_name, s)
      }
      case
        period_name == "am" || period_name == "pm" || s == None || s == Some("")
      {
        True -> am_pm_fallback(ctx, count)
        False -> option.unwrap(s, "")
      }
    }
  }
}

fn day_period_for_hour_name(
  rule_set: resource.DayPeriodRules,
  hour_of_day: Int,
) -> String {
  case dayperiodrules.get_day_period_for_hour(rule_set, hour_of_day) {
    resource.Midnight -> "midnight"
    resource.Noon -> "noon"
    resource.Morning1 -> "morning1"
    resource.Afternoon1 -> "afternoon1"
    resource.Evening1 -> "evening1"
    resource.Night1 -> "night1"
    resource.Morning2 -> "morning2"
    resource.Afternoon2 -> "afternoon2"
    resource.Evening2 -> "evening2"
    resource.Night2 -> "night2"
    resource.Am -> "am"
    resource.Pm -> "pm"
    resource.DayPeriodUnknown -> "am"
  }
}

fn sub_format_hour_field(
  ctx: SubFormatContext,
  ch: String,
  count: Int,
) -> String {
  case ch {
    "H" ->
      zero_padding_number(ctx.fields.common.hour_of_day, count, 10, ctx.digits)
    "k" -> {
      let v = case ctx.fields.common.hour_of_day == 0 {
        True -> 24
        False -> ctx.fields.common.hour_of_day
      }
      zero_padding_number(v, count, 10, ctx.digits)
    }
    "h" -> {
      let v = case ctx.fields.common.hour == 0 {
        True -> 12
        False -> ctx.fields.common.hour
      }
      zero_padding_number(v, count, 10, ctx.digits)
    }
    "K" -> zero_padding_number(ctx.fields.common.hour, count, 10, ctx.digits)
    "m" -> zero_padding_number(ctx.fields.common.minute, count, 10, ctx.digits)
    "s" -> zero_padding_number(ctx.fields.common.second, count, 10, ctx.digits)
    "S" -> {
      let ms_text =
        string.pad_start(int.to_string(ctx.fields.common.millisecond), 3, "0")
      let take = case count < 3 {
        True -> count
        False -> 3
      }
      let ms_text = string.slice(ms_text, 0, take)
      let ms_text = string.pad_end(ms_text, count, "0")
      case decimfmt.digits_are_ascii(ctx.digits) {
        True -> ms_text
        False -> decimfmt.localize_digits(ms_text, ctx.digits)
      }
    }
    "A" ->
      zero_padding_number(
        ctx.fields.common.hour_of_day
          * 3_600_000
          + ctx.fields.common.minute
          * 60_000
          + ctx.fields.common.second
          * 1000
          + ctx.fields.common.millisecond,
        count,
        10,
        ctx.digits,
      )
    _ -> ""
  }
}

fn sub_format_zone(
  bundle: Bundle,
  locale_id: String,
  ch: String,
  count: Int,
  raw_offset: Int,
  dst_offset: Int,
  canonical_tzid: Option(String),
  epoch_millis: Int,
  tzid: String,
  digits: decimfmt.Digits,
) -> String {
  let offset = raw_offset + dst_offset
  case ch {
    "O" ->
      case count == 1 {
        True ->
          format_offset_localized_gmt(bundle, locale_id, offset, True, digits)
        False ->
          format_offset_localized_gmt(bundle, locale_id, offset, False, digits)
      }
    "X" ->
      case count {
        1 -> format_offset_iso8601(offset, True, True, True, True)
        2 -> format_offset_iso8601(offset, True, True, False, True)
        3 -> format_offset_iso8601(offset, False, True, False, True)
        4 -> format_offset_iso8601(offset, True, True, False, False)
        _ -> format_offset_iso8601(offset, False, True, False, False)
      }
    "x" ->
      case count {
        1 -> format_offset_iso8601(offset, True, False, True, True)
        2 -> format_offset_iso8601(offset, True, False, False, True)
        3 -> format_offset_iso8601(offset, False, False, False, True)
        4 -> format_offset_iso8601(offset, True, False, False, False)
        _ -> format_offset_iso8601(offset, False, False, False, False)
      }
    "Z" ->
      case count < 4 {
        True -> format_offset_iso8601(offset, True, False, False, False)
        False ->
          case count == 5 {
            True -> format_offset_iso8601(offset, False, True, False, False)
            False ->
              format_offset_localized_gmt(
                bundle,
                locale_id,
                offset,
                False,
                digits,
              )
          }
      }
    "z" ->
      case canonical_tzid {
        None ->
          format_offset_localized_gmt(
            bundle,
            locale_id,
            offset,
            count < 4,
            digits,
          )
        Some(cid) -> {
          let zone_chain = tznames.get_zone_strings_chain(bundle, locale_id)
          let name =
            tznames.get_specific_name(
              bundle,
              zone_chain,
              cid,
              epoch_millis,
              dst_offset != 0,
              count >= 4,
            )
          case name {
            Some(n) -> n
            None ->
              format_offset_localized_gmt(
                bundle,
                locale_id,
                offset,
                count < 4,
                digits,
              )
          }
        }
      }
    "v" ->
      case canonical_tzid {
        None ->
          format_offset_localized_gmt(
            bundle,
            locale_id,
            offset,
            count < 4,
            digits,
          )
        Some(cid) -> {
          let zone_chain = tznames.get_zone_strings_chain(bundle, locale_id)
          let name = case
            tznames.get_generic_name(
              bundle,
              locale_id,
              zone_chain,
              cid,
              epoch_millis,
              raw_offset,
              dst_offset,
              count >= 4,
            )
          {
            Some(n) -> Some(n)
            None ->
              tznames.get_generic_location_name(
                bundle,
                locale_id,
                zone_chain,
                cid,
              )
          }
          case name {
            Some(n) -> n
            None ->
              format_offset_localized_gmt(
                bundle,
                locale_id,
                offset,
                count < 4,
                digits,
              )
          }
        }
      }
    "V" ->
      case canonical_tzid {
        None ->
          format_offset_localized_gmt(bundle, locale_id, offset, True, digits)
        Some(cid) ->
          case count {
            1 -> {
              let #(short_id, _cache) =
                zonemeta.get_short_id(
                  zonemeta_bundle(bundle),
                  zonemeta.new_canonical_id_cache(),
                  cid,
                )
              option.unwrap(short_id, "unk")
            }
            2 -> tzid
            3 -> {
              let zone_chain = tznames.get_zone_strings_chain(bundle, locale_id)
              case tznames.get_exemplar_city(bundle, zone_chain, cid) {
                Some(city) -> city
                None ->
                  case
                    tznames.get_exemplar_city(bundle, zone_chain, "Etc/Unknown")
                  {
                    Some(city) -> city
                    None -> "Unknown"
                  }
              }
            }
            _ -> {
              let zone_chain = tznames.get_zone_strings_chain(bundle, locale_id)
              case
                tznames.get_generic_location_name(
                  bundle,
                  locale_id,
                  zone_chain,
                  cid,
                )
              {
                Some(loc) -> loc
                None ->
                  format_offset_localized_gmt(
                    bundle,
                    locale_id,
                    offset,
                    False,
                    digits,
                  )
              }
            }
          }
      }
    _ ->
      format_offset_localized_gmt(bundle, locale_id, offset, count < 4, digits)
  }
}

fn sub_format(ctx: SubFormatContext, ch: String, count: Int) -> String {
  case ch {
    "G" -> sub_format_era(ctx, count)
    "y" | "Y" | "u" | "r" | "U" -> sub_format_year(ctx, ch, count)
    "Q" | "q" -> sub_format_quarter(ctx, ch, count)
    "M" | "L" -> sub_format_month(ctx, ch, count)
    "w" ->
      zero_padding_number(ctx.fields.common.week_of_year, count, 10, ctx.digits)
    "W" ->
      zero_padding_number(
        ctx.fields.common.week_of_month,
        count,
        10,
        ctx.digits,
      )
    "d" ->
      zero_padding_number(ctx.fields.common.day_of_month, count, 10, ctx.digits)
    "D" ->
      zero_padding_number(ctx.fields.common.day_of_year, count, 10, ctx.digits)
    "F" ->
      zero_padding_number(
        ctx.fields.common.day_of_week_in_month,
        count,
        10,
        ctx.digits,
      )
    "E" | "c" | "e" -> sub_format_weekday(ctx, ch, count)
    "a" | "b" | "B" -> sub_format_day_period(ctx, ch, count)
    "H" | "k" | "h" | "K" | "m" | "s" | "S" | "A" ->
      sub_format_hour_field(ctx, ch, count)
    "v" | "z" | "Z" | "O" | "X" | "x" | "V" ->
      sub_format_zone(
        ctx.bundle,
        ctx.locale_id,
        ch,
        count,
        ctx.raw_offset,
        ctx.dst_offset,
        ctx.canonical_tzid,
        ctx.epoch_millis,
        ctx.tzid,
        ctx.digits,
      )
    _ -> ""
  }
}

const field_type_g = "era"

const field_type_y = "year"

fn field_type_name(ch: String) -> String {
  case ch {
    "G" -> field_type_g
    "y" -> field_type_y
    "Y" -> "yearOfWeekOfYear"
    "u" -> "extendedYear"
    "r" -> "relatedYear"
    "U" -> "yearName"
    "Q" | "q" -> "quarter"
    "M" | "L" -> "month"
    "w" -> "weekOfYear"
    "W" -> "weekOfMonth"
    "d" -> "day"
    "D" -> "dayOfYear"
    "F" -> "dayOfWeekInMonth"
    "E" | "c" | "e" -> "weekday"
    "a" | "b" | "B" -> "dayPeriod"
    "H" | "k" | "h" | "K" -> "hour"
    "m" -> "minute"
    "s" -> "second"
    "S" -> "fractionalSecond"
    "A" -> "millisecondsInDay"
    "v" | "z" | "Z" | "O" | "X" | "x" -> "timeZoneName"
    "V" -> "timeZoneName"
    _ -> "unknown"
  }
}

type TokenAnalysis {
  TokenAnalysis(has_date_anchor_field: Bool, has_minute: Bool, has_second: Bool)
}

fn analyze_tokens(tokens: List(PatternToken)) -> TokenAnalysis {
  analyze_tokens_loop(tokens, False, False, False)
}

fn analyze_tokens_loop(
  tokens: List(PatternToken),
  has_date_anchor_field: Bool,
  has_minute: Bool,
  has_second: Bool,
) -> TokenAnalysis {
  case tokens {
    [] -> TokenAnalysis(has_date_anchor_field:, has_minute:, has_second:)
    [FieldToken(ch, _), ..rest] -> {
      let has_date_anchor_field =
        has_date_anchor_field
        || ch == "y"
        || ch == "Y"
        || ch == "u"
        || ch == "d"
      let has_minute = has_minute || ch == "m"
      let has_second = has_second || ch == "s"
      analyze_tokens_loop(rest, has_date_anchor_field, has_minute, has_second)
    }
    [_, ..rest] ->
      analyze_tokens_loop(rest, has_date_anchor_field, has_minute, has_second)
  }
}

fn create_sub_format_context(
  formatter: DateFormatter,
  fields: CalendarFields,
  raw_offset: Int,
  dst_offset: Int,
  epoch_millis: Int,
  has_date_anchor_field_override: Option(Bool),
) -> SubFormatContext {
  let has_date_anchor_field = case has_date_anchor_field_override {
    Some(v) -> v
    None -> formatter.has_date_anchor_field
  }
  SubFormatContext(
    bundle: formatter.bundle,
    chain: formatter.chain,
    locale_id: formatter.locale_id,
    cal_type: formatter.cal_type,
    fields:,
    raw_offset:,
    dst_offset:,
    canonical_tzid: formatter.canonical_tzid,
    tzid: formatter.tz,
    epoch_millis:,
    digits: formatter.digits,
    gannen_year_numbering: formatter.gannen_year_numbering,
    has_date_anchor_field:,
    has_minute: formatter.has_minute,
    has_second: formatter.has_second,
    tokens: formatter.tokens,
  )
}

pub fn format(
  formatter: DateFormatter,
  fields: CalendarFields,
  raw_offset: Int,
  dst_offset: Int,
  epoch_millis: Int,
  has_date_anchor_field_override: Option(Bool),
) -> FormatResult {
  let ctx =
    create_sub_format_context(
      formatter,
      fields,
      raw_offset,
      dst_offset,
      epoch_millis,
      has_date_anchor_field_override,
    )
  render_tokens(ctx, ctx.tokens, "", 0, [])
}

fn render_tokens(
  ctx: SubFormatContext,
  tokens: List(PatternToken),
  out: String,
  start: Int,
  parts: List(RenderedFormatPart),
) -> FormatResult {
  case tokens {
    [] -> FormatResult(formatted: out, parts: list.reverse(parts))
    [tok, ..rest] -> {
      let #(rendered, ch_opt) = case tok {
        LiteralToken(text) -> #(text, None)
        FieldToken(ch, count) -> #(sub_format(ctx, ch, count), Some(ch))
      }
      let out = out <> rendered
      let end = start + string.length(rendered)
      case end > start {
        False -> render_tokens(ctx, rest, out, end, parts)
        True -> {
          let type_ = case ch_opt {
            None -> "literal"
            Some(ch) -> field_type_name(ch)
          }
          let parts = case parts, type_ {
            [
              RenderedFormatPart("literal", _, prev_value, prev_start, _),
              ..prev_rest
            ],
              "literal"
            -> [
              RenderedFormatPart(
                type_: "literal",
                ch: None,
                value: prev_value <> rendered,
                start: prev_start,
                end:,
              ),
              ..prev_rest
            ]
            _, _ -> [
              RenderedFormatPart(
                type_:,
                ch: ch_opt,
                value: rendered,
                start:,
                end:,
              ),
              ..parts
            ]
          }
          render_tokens(ctx, rest, out, end, parts)
        }
      }
    }
  }
}

pub fn udat_open(
  bundle: Bundle,
  locale_id: String,
  cal_type: String,
  tz: String,
  pattern: String,
) -> DateFormatter {
  let base_name = uloc.get_base_name(Some(locale_id))
  let chain = bundle.open_locale_chain(bundle, base_name)
  let canonical_tzid = case tz == "" {
    True -> None
    False -> {
      let #(result, _cache) =
        zonemeta.get_canonical_time_zone_id(
          zonemeta_bundle(bundle),
          zonemeta.new_canonical_id_cache(),
          tz,
        )
      case result.canonical_id {
        Some(cid) -> Some(cid)
        None -> Some(tz)
      }
    }
  }
  let digits = decimfmt.get_locale_digits(bundle, locale_id)
  let tokens = tokenize_pattern(pattern)
  let analysis = analyze_tokens(tokens)
  DateFormatter(
    bundle:,
    locale_id:,
    cal_type:,
    tz:,
    pattern:,
    chain:,
    canonical_tzid:,
    digits:,
    gannen_year_numbering: uses_gannen_year_numbering(
      cal_type,
      locale_id,
      pattern,
    ),
    has_date_anchor_field: analysis.has_date_anchor_field,
    has_minute: analysis.has_minute,
    has_second: analysis.has_second,
    tokens:,
  )
}

fn compute_and_format(
  formatter: DateFormatter,
  epoch_millis: Int,
) -> FormatResult {
  let off =
    timezone.get_offset(
      zonemeta_bundle(formatter.bundle),
      formatter.tz,
      epoch_millis,
    )
  let fields =
    calendar.compute_fields_for_calendar(
      formatter.cal_type,
      formatter.bundle,
      formatter.locale_id,
      epoch_millis,
      off.raw_offset + off.dst_offset,
    )
  format(formatter, fields, off.raw_offset, off.dst_offset, epoch_millis, None)
}

pub fn udat_format(formatter: DateFormatter, epoch_millis: Int) -> String {
  compute_and_format(formatter, epoch_millis).formatted
}

pub fn udat_format_for_fields(
  formatter: DateFormatter,
  epoch_millis: Int,
) -> FormatForFieldsResult {
  let r = compute_and_format(formatter, epoch_millis)
  FormatForFieldsResult(formatted: r.formatted, parts: r.parts)
}
