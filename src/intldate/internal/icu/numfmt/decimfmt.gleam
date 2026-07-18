import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/numsys/numsys
import intldate/internal/icu/plural/plurrule.{type PluralOperands}
import intldate/internal/math

pub type PatternInfo {
  PatternInfo(
    grouping_used: Bool,
    primary_grouping_size: Int,
    secondary_grouping_size: Int,
    minimum_fraction_digits: Int,
    maximum_fraction_digits: Int,
  )
}

pub type DecimalFormatSymbols {
  DecimalFormatSymbols(
    decimal_separator: String,
    grouping_separator: String,
    minus_sign: String,
  )
}

pub type LocaleData {
  LocaleData(
    grouping_used: Bool,
    primary_grouping_size: Int,
    secondary_grouping_size: Int,
    minimum_grouping_digits: Int,
    minimum_fraction_digits: Int,
    maximum_fraction_digits: Int,
    decimal_separator: String,
    grouping_separator: String,
    minus_sign: String,
    digits: Digits,
  )
}

pub type Digits {
  Digits(
    ascii: Bool,
    values: #(
      String,
      String,
      String,
      String,
      String,
      String,
      String,
      String,
      String,
      String,
    ),
  )
}

pub type FormatDecimalResult {
  FormatDecimalResult(
    text: String,
    parts: List(#(String, String)),
    operands: PluralOperands,
  )
}

pub type DecimalFormat {
  DecimalFormat(bundle: Option(Bundle), locale_id: String)
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> 0
  }
}

pub fn localize_digits(str: String, digits: Digits) -> String {
  case digits.ascii {
    True -> str
    False -> {
      string.to_graphemes(str)
      |> list.map(fn(ch) {
        let code = char_code(ch)
        case code >= 48 && code <= 57 {
          True -> tuple_digit_at(digits.values, code - 48, ch)
          False -> ch
        }
      })
      |> string.join("")
    }
  }
}

pub fn prepare_digits(digits: String) -> Digits {
  case string.to_graphemes(digits) {
    [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9] ->
      Digits(ascii: digits == "0123456789", values: #(
        d0,
        d1,
        d2,
        d3,
        d4,
        d5,
        d6,
        d7,
        d8,
        d9,
      ))
    _ ->
      Digits(ascii: True, values: #(
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
      ))
  }
}

pub fn digits_are_ascii(digits: Digits) -> Bool {
  digits.ascii
}

fn tuple_digit_at(
  digits: #(
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
  ),
  index: Int,
  default: String,
) -> String {
  case digits, index {
    #(d0, _, _, _, _, _, _, _, _, _), 0 -> d0
    #(_, d1, _, _, _, _, _, _, _, _), 1 -> d1
    #(_, _, d2, _, _, _, _, _, _, _), 2 -> d2
    #(_, _, _, d3, _, _, _, _, _, _), 3 -> d3
    #(_, _, _, _, d4, _, _, _, _, _), 4 -> d4
    #(_, _, _, _, _, d5, _, _, _, _), 5 -> d5
    #(_, _, _, _, _, _, d6, _, _, _), 6 -> d6
    #(_, _, _, _, _, _, _, d7, _, _), 7 -> d7
    #(_, _, _, _, _, _, _, _, d8, _), 8 -> d8
    #(_, _, _, _, _, _, _, _, _, d9), 9 -> d9
    _, _ -> default
  }
}

pub fn get_locale_digits(bundle: Bundle, locale_id: String) -> Digits {
  let ns = numsys.create_instance_for_locale(bundle, locale_id)
  get_numbering_system_digits(ns)
}

fn get_numbering_system_digits(ns: resource.NumberingSystem) -> Digits {
  let description = numsys.numbering_system_get_description(ns)
  case !numsys.numbering_system_is_algorithmic(ns) {
    True -> prepare_digits(description)
    False -> prepare_digits("0123456789")
  }
}

fn selected_numbering_system_name(ns: resource.NumberingSystem) -> String {
  case
    !numsys.numbering_system_is_algorithmic(ns)
    && numsys.numbering_system_get_name(ns) != ""
  {
    True -> numsys.numbering_system_get_name(ns)
    False -> "latn"
  }
}

pub fn parse_pattern(pattern: String) -> PatternInfo {
  let #(int_part, frac_part) = case string.split_once(pattern, ".") {
    Ok(#(before, after)) -> #(before, after)
    Error(_) -> #(pattern, "")
  }
  let groups = string.split(int_part, ",")
  let grouping_used = list.length(groups) > 1
  let last_group = list_last(groups, "")
  let primary_grouping_size = list.length(string.to_graphemes(last_group))
  let secondary_grouping_size = case list.length(groups) > 2 {
    True -> list.length(string.to_graphemes(second_group_from_end(groups, "")))
    False -> primary_grouping_size
  }
  let minimum_fraction_digits =
    string.to_graphemes(frac_part)
    |> list.filter(fn(ch) { ch == "0" })
    |> list.length
  let maximum_fraction_digits = list.length(string.to_graphemes(frac_part))
  PatternInfo(
    grouping_used:,
    primary_grouping_size:,
    secondary_grouping_size:,
    minimum_fraction_digits:,
    maximum_fraction_digits:,
  )
}

fn list_last(items: List(a), default: a) -> a {
  case items {
    [] -> default
    [only] -> only
    [_, ..rest] -> list_last(rest, default)
  }
}

fn second_group_from_end(items: List(a), default: a) -> a {
  case items {
    [] -> default
    [_] -> default
    [item, _] -> item
    [_, ..rest] -> second_group_from_end(rest, default)
  }
}

type ResolvedNsData {
  ResolvedNsData(
    decimal_separator: Option(String),
    grouping_separator: Option(String),
    minus_sign: Option(String),
    decimal_format_pattern: Option(String),
  )
}

fn ns_data_fully_resolved(acc: ResolvedNsData) -> Bool {
  option.is_some(acc.decimal_separator)
  && option.is_some(acc.grouping_separator)
  && option.is_some(acc.minus_sign)
  && option.is_some(acc.decimal_format_pattern)
}

fn merge_ns_data(
  acc: ResolvedNsData,
  found: resource.NumberSystemSymbols,
) -> ResolvedNsData {
  ResolvedNsData(
    decimal_separator: option.or(acc.decimal_separator, found.decimal_separator),
    grouping_separator: option.or(
      acc.grouping_separator,
      found.grouping_separator,
    ),
    minus_sign: option.or(acc.minus_sign, found.minus_sign),
    decimal_format_pattern: option.or(
      acc.decimal_format_pattern,
      found.decimal_format_pattern,
    ),
  )
}

fn resolve_ns_data_loop(
  chain: List(String),
  ns_name: String,
  data: dict.Dict(String, dict.Dict(String, resource.NumberSystemSymbols)),
  acc: ResolvedNsData,
) -> ResolvedNsData {
  case ns_data_fully_resolved(acc) {
    True -> acc
    False ->
      case chain {
        [] -> acc
        [name, ..rest] -> {
          let acc = case dict.get(data, name) {
            Error(_) -> acc
            Ok(by_ns) ->
              case dict.get(by_ns, ns_name) {
                Error(_) -> acc
                Ok(found) -> merge_ns_data(acc, found)
              }
          }
          resolve_ns_data_loop(rest, ns_name, data, acc)
        }
      }
  }
}

fn resolve_ns_data(
  bundle: Bundle,
  locale_id: String,
  ns_name: String,
) -> ResolvedNsData {
  let base_name = uloc.get_base_name(Some(locale_id))
  let key = "decimal-symbols:" <> base_name <> "@" <> ns_name
  case cache.get_ets(key) {
    Ok(data) -> data
    Error(_) ->
      cache.put_ets(key, resolve_ns_data_uncached(bundle, base_name, ns_name))
  }
}

fn resolve_ns_data_uncached(
  bundle: Bundle,
  locale_id: String,
  ns_name: String,
) -> ResolvedNsData {
  let data = bundle.number_system_data_by_locale
  let chain = localechain.locale_chain(bundle.locale_parents, locale_id)
  resolve_ns_data_loop(
    chain,
    ns_name,
    data.locales,
    ResolvedNsData(None, None, None, None),
  )
}

pub fn load_decimal_separator(
  bundle: Bundle,
  locale_id: String,
  ns_name: String,
) -> Option(String) {
  resolve_ns_data(bundle, locale_id, ns_name).decimal_separator
}

pub fn load_decimal_format_symbols(
  bundle: Bundle,
  locale_id: String,
  ns_name: String,
) -> DecimalFormatSymbols {
  let resolved = resolve_ns_data(bundle, locale_id, ns_name)
  DecimalFormatSymbols(
    decimal_separator: option.unwrap(resolved.decimal_separator, "."),
    grouping_separator: option.unwrap(resolved.grouping_separator, ","),
    minus_sign: option.unwrap(resolved.minus_sign, "-"),
  )
}

pub fn load_locale_data(bundle: Bundle, locale_id: String) -> LocaleData {
  let base_name = uloc.get_base_name(Some(locale_id))
  let ns = numsys.create_instance_for_locale(bundle, locale_id)
  let ns_name = selected_numbering_system_name(ns)
  let key = "decimal-locale-data:" <> base_name <> "@" <> ns_name
  case cache.get_ets(key) {
    Ok(data) -> data
    Error(_) ->
      cache.put_ets(
        key,
        load_locale_data_uncached(bundle, base_name, ns_name, ns),
      )
  }
}

fn resolve_minimum_grouping_digits(bundle: Bundle, base_name: String) -> Int {
  let data = bundle.number_elements_by_locale
  let chain = localechain.locale_chain(bundle.locale_parents, base_name)
  case
    find_number_element_in_chain(data.locales, chain, "minimumGroupingDigits")
  {
    Some(value) ->
      case int.parse(value) {
        Ok(n) if n >= 1 -> n
        _ -> 1
      }
    None -> 1
  }
}

fn find_number_element_in_chain(
  locales: dict.Dict(String, dict.Dict(String, String)),
  chain: List(String),
  item_key: String,
) -> Option(String) {
  case chain {
    [] -> None
    [name, ..rest] ->
      case dict.get(locales, name) {
        Error(_) -> find_number_element_in_chain(locales, rest, item_key)
        Ok(elements) ->
          case dict.get(elements, item_key) {
            Ok(value) if value != "" -> Some(value)
            _ -> find_number_element_in_chain(locales, rest, item_key)
          }
      }
  }
}

fn load_locale_data_uncached(
  bundle: Bundle,
  base_name: String,
  ns_name: String,
  ns: resource.NumberingSystem,
) -> LocaleData {
  let resolved = resolve_ns_data_uncached(bundle, base_name, ns_name)
  let pattern = option.unwrap(resolved.decimal_format_pattern, "#,##0.###")
  let info = parse_pattern(pattern)
  LocaleData(
    grouping_used: info.grouping_used,
    primary_grouping_size: info.primary_grouping_size,
    secondary_grouping_size: info.secondary_grouping_size,
    minimum_grouping_digits: resolve_minimum_grouping_digits(bundle, base_name),
    minimum_fraction_digits: info.minimum_fraction_digits,
    maximum_fraction_digits: info.maximum_fraction_digits,
    decimal_separator: option.unwrap(resolved.decimal_separator, "."),
    grouping_separator: option.unwrap(resolved.grouping_separator, ","),
    minus_sign: option.unwrap(resolved.minus_sign, "-"),
    digits: get_numbering_system_digits(ns),
  )
}

pub fn round_half_even(number: Float, maximum_fraction_digits: Int) -> Float {
  let factor = int.to_float(math.pow10(maximum_fraction_digits))
  let scaled = number *. factor
  let floor = float.floor(scaled)
  let diff = scaled -. floor
  let epsilon = 0.000000001
  let floor_int = float.round(floor)
  let rounded = case diff >. 0.5 +. epsilon, diff <. 0.5 -. epsilon {
    True, _ -> floor_int + 1
    _, True -> floor_int
    _, _ ->
      case floor_int % 2 == 0 {
        True -> floor_int
        False -> floor_int + 1
      }
  }
  int.to_float(rounded) /. factor
}

fn group_integer_parts(
  int_string: String,
  grouping_used: Bool,
  primary_grouping_size: Int,
  secondary_grouping_size: Int,
  minimum_grouping_digits: Int,
  grouping_separator: String,
) -> List(#(String, String)) {
  let len = string.length(int_string)
  case
    !grouping_used
    || len <= primary_grouping_size
    || len < primary_grouping_size + minimum_grouping_digits
  {
    True -> [#("integer", int_string)]
    False -> {
      let last =
        string.slice(
          int_string,
          len - primary_grouping_size,
          primary_grouping_size,
        )
      let rest = string.slice(int_string, 0, len - primary_grouping_size)
      group_integer_parts_loop(
        rest,
        [#("integer", last)],
        secondary_grouping_size,
        grouping_separator,
      )
    }
  }
}

fn group_integer_parts_loop(
  rest: String,
  acc: List(#(String, String)),
  secondary_grouping_size: Int,
  grouping_separator: String,
) -> List(#(String, String)) {
  let rest_len = string.length(rest)
  case rest_len > secondary_grouping_size {
    True -> {
      let chunk =
        string.slice(
          rest,
          rest_len - secondary_grouping_size,
          secondary_grouping_size,
        )
      let new_rest = string.slice(rest, 0, rest_len - secondary_grouping_size)
      group_integer_parts_loop(
        new_rest,
        [#("integer", chunk), #("group", grouping_separator), ..acc],
        secondary_grouping_size,
        grouping_separator,
      )
    }
    False ->
      case rest_len > 0 {
        True -> [#("integer", rest), #("group", grouping_separator), ..acc]
        False -> acc
      }
  }
}

fn strip_trailing_zeros(s: String, min_length: Int) -> String {
  case string.ends_with(s, "0") && string.length(s) > min_length {
    True -> strip_trailing_zeros(string.drop_end(s, 1), min_length)
    False -> s
  }
}

fn digits_to_int(s: String) -> Int {
  case s == "" {
    True -> 0
    False -> result_or_zero(int.parse(s))
  }
}

fn result_or_zero(r: Result(Int, Nil)) -> Int {
  case r {
    Ok(v) -> v
    Error(_) -> 0
  }
}

pub fn format_decimal(
  bundle: Bundle,
  locale_id: String,
  number: Float,
) -> FormatDecimalResult {
  let data = load_locale_data(bundle, locale_id)
  let is_negative = number <. 0.0 || is_negative_zero(number)
  let rounded =
    round_half_even(float.absolute_value(number), data.maximum_fraction_digits)
  let i = float.truncate(rounded)
  let scale = math.pow10(data.maximum_fraction_digits)
  let scaled = float.round(rounded *. int.to_float(scale))
  let #(frac_string, frac_string_no_trailing_zeros) = case
    data.maximum_fraction_digits > 0
  {
    True -> {
      let full_frac_string =
        string.pad_start(
          int.to_string(scaled - i * scale),
          data.maximum_fraction_digits,
          "0",
        )
      let no_trailing = strip_trailing_zeros(full_frac_string, 0)
      let with_min =
        strip_trailing_zeros(full_frac_string, data.minimum_fraction_digits)
      #(with_min, no_trailing)
    }
    False -> #("", "")
  }
  let integer_parts =
    group_integer_parts(
      int.to_string(i),
      data.grouping_used,
      data.primary_grouping_size,
      data.secondary_grouping_size,
      data.minimum_grouping_digits,
      data.grouping_separator,
    )
  let integer_text =
    integer_parts
    |> list.map(fn(p) { p.1 })
    |> string.concat
  let unsigned_text = case frac_string == "" {
    True -> integer_text
    False -> integer_text <> data.decimal_separator <> frac_string
  }
  let text = case is_negative {
    True -> data.minus_sign <> unsigned_text
    False -> unsigned_text
  }
  let fraction_parts = case frac_string == "" {
    True -> []
    False -> [#("decimal", data.decimal_separator), #("fraction", frac_string)]
  }
  let sign_parts = case is_negative {
    True -> [#("minusSign", data.minus_sign)]
    False -> []
  }
  let parts =
    list.append(sign_parts, list.append(integer_parts, fraction_parts))
    |> list.map(fn(p) {
      let #(kind, value) = p
      case kind {
        "integer" | "fraction" -> #(kind, localize_digits(value, data.digits))
        _ -> #(kind, value)
      }
    })
  let v = string.length(frac_string)
  let f = case v == 0 {
    True -> 0
    False -> digits_to_int(frac_string)
  }
  let w = string.length(frac_string_no_trailing_zeros)
  let t = case w == 0 {
    True -> 0
    False -> digits_to_int(frac_string_no_trailing_zeros)
  }
  FormatDecimalResult(
    text: localize_digits(text, data.digits),
    parts:,
    operands: plurrule.PluralOperands(
      n: Some(rounded),
      i: Some(int.to_float(i)),
      f: Some(int.to_float(f)),
      t: Some(int.to_float(t)),
      v: Some(int.to_float(v)),
      w: Some(int.to_float(w)),
      e: Some(0.0),
      c: Some(0.0),
    ),
  )
}

fn is_negative_zero(x: Float) -> Bool {
  x == 0.0 && 1.0 /. x <. 0.0
}
