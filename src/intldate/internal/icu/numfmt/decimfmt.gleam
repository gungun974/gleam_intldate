import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
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
    minimum_fraction_digits: Int,
    maximum_fraction_digits: Int,
    decimal_separator: String,
    grouping_separator: String,
    minus_sign: String,
    digits: String,
  )
}

pub type FormatDecimalResult {
  FormatDecimalResult(text: String, operands: PluralOperands)
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

pub fn localize_digits(str: String, digits: String) -> String {
  case digits == "" || digits == "0123456789" {
    True -> str
    False -> {
      let localized_digits = digits_tuple(digits)
      string.to_graphemes(str)
      |> list.map(fn(ch) {
        let code = char_code(ch)
        case code >= 48 && code <= 57 {
          True -> tuple_digit_at(localized_digits, code - 48, ch)
          False -> ch
        }
      })
      |> string.join("")
    }
  }
}

fn digits_tuple(
  digits: String,
) -> #(
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
) {
  case string.to_graphemes(digits) {
    [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9] -> #(
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
    )
    _ -> #("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
  }
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

pub fn get_locale_digits(bundle: Bundle, locale_id: String) -> String {
  let ns = numsys.create_instance_for_locale(bundle, locale_id)
  let description = numsys.numbering_system_get_description(ns)
  case
    !numsys.numbering_system_is_algorithmic(ns)
    && list.length(string.to_graphemes(description)) == 10
  {
    True -> description
    False -> "0123456789"
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

fn resource_string_text(rd: resource.ResourceData, res: Int) -> Option(String) {
  case
    resource.resource_value_get_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> Some(s.text)
    None -> None
  }
}

fn table_keys_and_res(
  table: resource.ResourceTableView,
) -> List(#(String, Int)) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      table_keys_and_res_loop(get_key, get_res, 0, table.length)
    _, _ -> []
  }
}

fn table_keys_and_res_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(#(String, Int)) {
  case i >= length {
    True -> []
    False -> [
      #(get_key(i), get_res(i)),
      ..table_keys_and_res_loop(get_key, get_res, i + 1, length)
    ]
  }
}

type SymbolsAcc {
  SymbolsAcc(
    decimal_separator: Option(String),
    grouping_separator: Option(String),
    minus_sign: Option(String),
  )
}

pub fn load_decimal_format_symbols(
  bundle: Bundle,
  locale_id: String,
  ns_name: String,
) -> DecimalFormatSymbols {
  let chain = resbund.open_locale_chain(bundle, locale_id)
  let acc =
    load_decimal_format_symbols_loop(
      bundle,
      chain,
      ns_name,
      SymbolsAcc(None, None, None),
    )
  DecimalFormatSymbols(
    decimal_separator: option.unwrap(acc.decimal_separator, "."),
    grouping_separator: option.unwrap(acc.grouping_separator, ","),
    minus_sign: option.unwrap(acc.minus_sign, "-"),
  )
}

fn load_decimal_format_symbols_loop(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  ns_name: String,
  acc: SymbolsAcc,
) -> SymbolsAcc {
  case
    option.is_some(acc.decimal_separator)
    && option.is_some(acc.grouping_separator)
    && option.is_some(acc.minus_sign)
  {
    True -> acc
    False ->
      case chain {
        [] -> acc
        [level, ..rest] ->
          case
            resbund.get_by_path(
              bundle,
              [level],
              "NumberElements/" <> ns_name <> "/symbols",
              0,
            )
          {
            None -> load_decimal_format_symbols_loop(bundle, rest, ns_name, acc)
            Some(found) -> {
              let table = resource.get_table(found.res_data, found.res)
              let entries = table_keys_and_res(table)
              let acc = apply_symbol_entries(entries, found.res_data, acc)
              load_decimal_format_symbols_loop(bundle, rest, ns_name, acc)
            }
          }
      }
  }
}

fn apply_symbol_entries(
  entries: List(#(String, Int)),
  res_data: resource.ResourceData,
  acc: SymbolsAcc,
) -> SymbolsAcc {
  case entries {
    [] -> acc
    [#(key, res), ..rest] -> {
      let acc = case key, acc.decimal_separator {
        "decimal", None ->
          SymbolsAcc(
            ..acc,
            decimal_separator: resource_string_text(res_data, res),
          )
        _, _ -> acc
      }
      let acc = case key, acc.grouping_separator {
        "group", None ->
          SymbolsAcc(
            ..acc,
            grouping_separator: resource_string_text(res_data, res),
          )
        _, _ -> acc
      }
      let acc = case key, acc.minus_sign {
        "minusSign", None ->
          SymbolsAcc(..acc, minus_sign: resource_string_text(res_data, res))
        _, _ -> acc
      }
      apply_symbol_entries(rest, res_data, acc)
    }
  }
}

pub fn load_locale_data(bundle: Bundle, locale_id: String) -> LocaleData {
  let base_name = uloc.get_base_name(Some(locale_id))
  let ns = numsys.create_instance_for_locale(bundle, locale_id)
  let ns_name = case
    !numsys.numbering_system_is_algorithmic(ns)
    && numsys.numbering_system_get_name(ns) != ""
  {
    True -> numsys.numbering_system_get_name(ns)
    False -> "latn"
  }
  let chain = resbund.open_locale_chain(bundle, base_name)
  let pattern = case
    resbund.get_by_path(
      bundle,
      chain,
      "NumberElements/" <> ns_name <> "/patterns/decimalFormat",
      0,
    )
  {
    None -> "#,##0.###"
    Some(found) ->
      option.unwrap(
        resource_string_text(found.res_data, found.res),
        "#,##0.###",
      )
  }
  let symbols = load_decimal_format_symbols(bundle, base_name, ns_name)
  let info = parse_pattern(pattern)
  LocaleData(
    grouping_used: info.grouping_used,
    primary_grouping_size: info.primary_grouping_size,
    secondary_grouping_size: info.secondary_grouping_size,
    minimum_fraction_digits: info.minimum_fraction_digits,
    maximum_fraction_digits: info.maximum_fraction_digits,
    decimal_separator: symbols.decimal_separator,
    grouping_separator: symbols.grouping_separator,
    minus_sign: symbols.minus_sign,
    digits: get_locale_digits(bundle, locale_id),
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

fn group_integer(
  int_string: String,
  grouping_used: Bool,
  primary_grouping_size: Int,
  secondary_grouping_size: Int,
  grouping_separator: String,
) -> String {
  let len = string.length(int_string)
  case !grouping_used || len <= primary_grouping_size {
    True -> int_string
    False -> {
      let result =
        string.slice(
          int_string,
          len - primary_grouping_size,
          primary_grouping_size,
        )
      let rest = string.slice(int_string, 0, len - primary_grouping_size)
      group_integer_loop(
        rest,
        result,
        secondary_grouping_size,
        grouping_separator,
      )
    }
  }
}

fn group_integer_loop(
  rest: String,
  result: String,
  secondary_grouping_size: Int,
  grouping_separator: String,
) -> String {
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
      group_integer_loop(
        new_rest,
        chunk <> grouping_separator <> result,
        secondary_grouping_size,
        grouping_separator,
      )
    }
    False ->
      case rest_len > 0 {
        True -> rest <> grouping_separator <> result
        False -> result
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
  let integer_text =
    group_integer(
      int.to_string(i),
      data.grouping_used,
      data.primary_grouping_size,
      data.secondary_grouping_size,
      data.grouping_separator,
    )
  let unsigned_text = case frac_string == "" {
    True -> integer_text
    False -> integer_text <> data.decimal_separator <> frac_string
  }
  let text = case is_negative {
    True -> data.minus_sign <> unsigned_text
    False -> unsigned_text
  }
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
