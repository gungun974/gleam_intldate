import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc

pub type DayPeriod {
  DayPeriodUnknown
  Midnight
  Noon
  Morning1
  Afternoon1
  Evening1
  Night1
  Morning2
  Afternoon2
  Evening2
  Night2
  Am
  Pm
}

const cutoff_type_before = 0

const cutoff_type_after = 1

const cutoff_type_from = 2

const cutoff_type_at = 3

pub type DayPeriodRules {
  DayPeriodRules(
    has_midnight: Bool,
    has_noon: Bool,
    day_period_for_hour: List(#(Int, DayPeriod)),
  )
}

fn init_hours(hour: Int) -> List(#(Int, DayPeriod)) {
  case hour >= 24 {
    True -> []
    False -> [#(hour, DayPeriodUnknown), ..init_hours(hour + 1)]
  }
}

fn hours_get(hours: List(#(Int, DayPeriod)), hour: Int) -> DayPeriod {
  case hours {
    [] -> DayPeriodUnknown
    [#(h, period), ..rest] ->
      case h == hour {
        True -> period
        False -> hours_get(rest, hour)
      }
  }
}

fn hours_put(
  hours: List(#(Int, DayPeriod)),
  hour: Int,
  period: DayPeriod,
) -> List(#(Int, DayPeriod)) {
  case hours {
    [] -> []
    [#(h, current), ..rest] ->
      case h == hour {
        True -> [#(h, period), ..rest]
        False -> [#(h, current), ..hours_put(rest, hour, period)]
      }
  }
}

fn rules_get(
  rules: List(#(Int, DayPeriodRules)),
  rule_set_num: Int,
) -> DayPeriodRules {
  case rules {
    [] -> create_day_period_rules()
    [#(n, rule), ..rest] ->
      case n == rule_set_num {
        True -> rule
        False -> rules_get(rest, rule_set_num)
      }
  }
}

fn rules_put(
  rules: List(#(Int, DayPeriodRules)),
  rule_set_num: Int,
  rule: DayPeriodRules,
) -> List(#(Int, DayPeriodRules)) {
  case rules {
    [] -> [#(rule_set_num, rule)]
    [#(n, current), ..rest] ->
      case n == rule_set_num {
        True -> [#(n, rule), ..rest]
        False -> [#(n, current), ..rules_put(rest, rule_set_num, rule)]
      }
  }
}

pub fn create_day_period_rules() -> DayPeriodRules {
  DayPeriodRules(
    has_midnight: False,
    has_noon: False,
    day_period_for_hour: init_hours(0),
  )
}

pub fn get_day_period_for_hour(rules: DayPeriodRules, hour: Int) -> DayPeriod {
  hours_get(rules.day_period_for_hour, hour)
}

pub fn day_period_rules_add(
  rules: DayPeriodRules,
  start_hour: Int,
  limit_hour: Int,
  period: DayPeriod,
) -> DayPeriodRules {
  add_loop(rules, start_hour, limit_hour, period)
}

fn add_loop(
  rules: DayPeriodRules,
  i: Int,
  limit_hour: Int,
  period: DayPeriod,
) -> DayPeriodRules {
  case i == limit_hour {
    True -> rules
    False -> {
      let i = case i == 24 {
        True -> 0
        False -> i
      }
      let rules =
        DayPeriodRules(
          ..rules,
          day_period_for_hour: hours_put(rules.day_period_for_hour, i, period),
        )
      add_loop(rules, i + 1, limit_hour, period)
    }
  }
}

fn all_hours_are_set(rules: DayPeriodRules) -> Bool {
  all_hours_are_set_hours_loop(rules.day_period_for_hour)
}

fn all_hours_are_set_hours_loop(hours: List(#(Int, DayPeriod))) -> Bool {
  case hours {
    [] -> True
    [#(_, period), ..tail] ->
      case period == DayPeriodUnknown {
        True -> False
        False -> all_hours_are_set_hours_loop(tail)
      }
  }
}

fn get_day_period_from_string(type_str: String) -> DayPeriod {
  case type_str {
    "midnight" -> Midnight
    "noon" -> Noon
    "morning1" -> Morning1
    "afternoon1" -> Afternoon1
    "evening1" -> Evening1
    "night1" -> Night1
    "morning2" -> Morning2
    "afternoon2" -> Afternoon2
    "evening2" -> Evening2
    "night2" -> Night2
    "am" -> Am
    "pm" -> Pm
    _ -> DayPeriodUnknown
  }
}

fn get_cutoff_type_from_string(type_str: String) -> Int {
  case type_str {
    "from" -> cutoff_type_from
    "before" -> cutoff_type_before
    "after" -> cutoff_type_after
    "at" -> cutoff_type_at
    _ -> -1
  }
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

fn is_digit(c: String) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
}

fn digit_value(c: String) -> Int {
  char_code(c) - 48
}

fn parse_hour(time: String) -> Result(Int, String) {
  let len = string.length(time)
  let hour_limit = len - 3
  case hour_limit != 1 && hour_limit != 2 {
    True -> Error("U_INVALID_FORMAT_ERROR")
    False ->
      case
        string.slice(time, hour_limit, 1) != ":"
        || string.slice(time, hour_limit + 1, 1) != "0"
        || string.slice(time, hour_limit + 2, 1) != "0"
      {
        True -> Error("U_INVALID_FORMAT_ERROR")
        False -> {
          let d0 = string.slice(time, 0, 1)
          case is_digit(d0) {
            False -> Error("U_INVALID_FORMAT_ERROR")
            True -> {
              let hour = digit_value(d0)
              case hour_limit == 2 {
                False -> Ok(hour)
                True -> {
                  let d1 = string.slice(time, 1, 1)
                  case is_digit(d1) {
                    False -> Error("U_INVALID_FORMAT_ERROR")
                    True -> {
                      let hour = hour * 10 + digit_value(d1)
                      case hour > 24 {
                        True -> Error("U_INVALID_FORMAT_ERROR")
                        False -> Ok(hour)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
  }
}

fn parse_set_num(set_num_str: String) -> Result(Int, String) {
  case string.starts_with(set_num_str, "set") {
    False -> Error("U_INVALID_FORMAT_ERROR")
    True -> {
      let digits = string.drop_start(set_num_str, 3)
      case parse_set_num_digits(code_points(digits), 0) {
        Error(e) -> Error(e)
        Ok(0) -> Error("U_INVALID_FORMAT_ERROR")
        Ok(n) -> Ok(n)
      }
    }
  }
}

fn parse_set_num_digits(chars: List(String), acc: Int) -> Result(Int, String) {
  case chars {
    [] -> Ok(acc)
    [c, ..rest] ->
      case is_digit(c) {
        False -> Error("U_INVALID_FORMAT_ERROR")
        True -> parse_set_num_digits(rest, 10 * acc + digit_value(c))
      }
  }
}

pub type DayPeriodRulesData {
  DayPeriodRulesData(
    locale_to_rule_set_num: List(#(String, Int)),
    rules: List(#(Int, DayPeriodRules)),
  )
}

type CutoffEntry {
  CutoffEntry(hour: Int, mask: Int)
}

fn cutoffs_get(cutoffs: List(CutoffEntry), hour: Int) -> Int {
  case cutoffs {
    [] -> 0
    [entry, ..rest] ->
      case entry.hour == hour {
        True -> entry.mask
        False -> cutoffs_get(rest, hour)
      }
  }
}

fn cutoffs_or(
  cutoffs: List(CutoffEntry),
  hour: Int,
  bit: Int,
) -> List(CutoffEntry) {
  case cutoffs {
    [] -> [CutoffEntry(hour, bit)]
    [entry, ..rest] ->
      case entry.hour == hour {
        True -> [CutoffEntry(hour, int.bitwise_or(entry.mask, bit)), ..rest]
        False -> [entry, ..cutoffs_or(rest, hour, bit)]
      }
  }
}

fn bit_set(mask: Int, bit: Int) -> Bool {
  int.bitwise_and(mask, bit) != 0
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

fn resource_string_text(rd: resource.ResourceData, res: Int) -> String {
  case
    resource.resource_value_get_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> s.text
    None -> ""
  }
}

fn cutoff_values_for_subres(
  rd: resource.ResourceData,
  subres: Int,
) -> List(String) {
  case
    resource.resource_value_get_array(resource.create_resource_value(
      Some(rd),
      subres,
    ))
  {
    Some(arr) ->
      case arr.get_res {
        Some(get_res) -> array_strings_loop(rd, get_res, 0, arr.length)
        None -> [resource_string_text(rd, subres)]
      }
    None -> [resource_string_text(rd, subres)]
  }
}

fn array_strings_loop(
  rd: resource.ResourceData,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(String) {
  case i >= length {
    True -> []
    False -> [
      resource_string_text(rd, get_res(i)),
      ..array_strings_loop(rd, get_res, i + 1, length)
    ]
  }
}

fn apply_cutoff_values(
  cutoffs: List(CutoffEntry),
  values: List(String),
  cutoff_type: Int,
) -> Result(List(CutoffEntry), String) {
  case values {
    [] -> Ok(cutoffs)
    [value, ..rest] ->
      case parse_hour(value) {
        Error(e) -> Error(e)
        Ok(hour) ->
          apply_cutoff_values(
            cutoffs_or(cutoffs, hour, int.bitwise_shift_left(1, cutoff_type)),
            rest,
            cutoff_type,
          )
      }
  }
}

fn process_period_definition(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  cutoffs: List(CutoffEntry),
) -> Result(List(CutoffEntry), String) {
  case entries {
    [] -> Ok(cutoffs)
    [#(key, subres), ..rest] -> {
      let cutoff_type = get_cutoff_type_from_string(key)
      let values = cutoff_values_for_subres(rd, subres)
      case apply_cutoff_values(cutoffs, values, cutoff_type) {
        Error(e) -> Error(e)
        Ok(cutoffs) -> process_period_definition(rd, rest, cutoffs)
      }
    }
  }
}

fn build_rule_from_cutoffs(
  rule: DayPeriodRules,
  period: DayPeriod,
  cutoffs: List(CutoffEntry),
  start_hour: Int,
) -> Result(DayPeriodRules, String) {
  case start_hour > 24 {
    True -> Ok(rule)
    False -> {
      let mask = cutoffs_get(cutoffs, start_hour)
      case bit_set(mask, int.bitwise_shift_left(1, cutoff_type_at)) {
        True ->
          case start_hour == 0 && period == Midnight {
            True -> {
              let rule = DayPeriodRules(..rule, has_midnight: True)
              build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
            }
            False ->
              case start_hour == 12 && period == Noon {
                True -> {
                  let rule = DayPeriodRules(..rule, has_noon: True)
                  build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
                }
                False -> Error("U_INVALID_FORMAT_ERROR")
              }
          }
        False ->
          case
            bit_set(mask, int.bitwise_shift_left(1, cutoff_type_from))
            || bit_set(mask, int.bitwise_shift_left(1, cutoff_type_after))
          {
            False ->
              build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
            True ->
              case find_limit_hour(cutoffs, start_hour, start_hour + 1) {
                Error(e) -> Error(e)
                Ok(limit_hour) -> {
                  let rule =
                    day_period_rules_add(rule, start_hour, limit_hour, period)
                  build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
                }
              }
          }
      }
    }
  }
}

fn find_limit_hour(
  cutoffs: List(CutoffEntry),
  start_hour: Int,
  hour: Int,
) -> Result(Int, String) {
  case hour == start_hour {
    True -> Error("U_INVALID_FORMAT_ERROR")
    False -> {
      let hour = case hour == 25 {
        True -> 0
        False -> hour
      }
      case
        bit_set(
          cutoffs_get(cutoffs, hour),
          int.bitwise_shift_left(1, cutoff_type_before),
        )
      {
        True -> Ok(hour)
        False -> find_limit_hour(cutoffs, start_hour, hour + 1)
      }
    }
  }
}

fn process_rule_set_entries(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  rules: List(#(Int, DayPeriodRules)),
  rule_set_num: Int,
) -> Result(List(#(Int, DayPeriodRules)), String) {
  case entries {
    [] -> Ok(rules)
    [#(key, res), ..rest] -> {
      let period = get_day_period_from_string(key)
      case period == DayPeriodUnknown {
        True -> Error("U_INVALID_FORMAT_ERROR")
        False -> {
          let period_definition = resource.get_table(rd, res)
          let period_entries = table_keys_and_res(period_definition)
          case process_period_definition(rd, period_entries, []) {
            Error(e) -> Error(e)
            Ok(cutoffs) -> {
              let rule = rules_get(rules, rule_set_num)
              case build_rule_from_cutoffs(rule, period, cutoffs, 0) {
                Error(e) -> Error(e)
                Ok(rule) -> {
                  let rules = rules_put(rules, rule_set_num, rule)
                  process_rule_set_entries(rd, rest, rules, rule_set_num)
                }
              }
            }
          }
        }
      }
    }
  }
}

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}

fn build_locale_map(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  map: List(#(String, Int)),
  max_num: Int,
) -> Result(#(List(#(String, Int)), Int), String) {
  case entries {
    [] -> Ok(#(map, max_num))
    [#(locale, res), ..rest] -> {
      case parse_set_num(resource_string_text(rd, res)) {
        Error(e) -> Error(e)
        Ok(set_num) -> {
          let map = [#(locale, set_num), ..map]
          let max_num = int_max(max_num, set_num)
          build_locale_map(rd, rest, map, max_num)
        }
      }
    }
  }
}

fn build_rules_map(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  rules: List(#(Int, DayPeriodRules)),
  max_num: Int,
) -> Result(#(List(#(Int, DayPeriodRules)), Int), String) {
  case entries {
    [] -> Ok(#(rules, max_num))
    [#(set_name, res), ..rest] ->
      case parse_set_num(set_name) {
        Error(e) -> Error(e)
        Ok(set_num) -> {
          let max_num = int_max(max_num, set_num)
          let rule_set_table = resource.get_table(rd, res)
          let entries_of_set = table_keys_and_res(rule_set_table)
          case process_rule_set_entries(rd, entries_of_set, rules, set_num) {
            Error(e) -> Error(e)
            Ok(rules) ->
              case all_hours_are_set(rules_get(rules, set_num)) {
                False -> Error("U_INVALID_FORMAT_ERROR")
                True -> build_rules_map(rd, rest, rules, max_num)
              }
          }
        }
      }
  }
}

pub fn load_day_period_rules(
  bundle: Bundle,
) -> Result(DayPeriodRulesData, String) {
  case resbund.open_direct(bundle, "dayPeriods") {
    None -> Error("U_MISSING_RESOURCE_ERROR")
    Some(rd) -> {
      let root = resource.get_table(rd, rd.root_res)
      let top_entries = table_keys_and_res(root)
      case load_top_entries(rd, top_entries, [], [], 0) {
        Error(e) -> Error(e)
        Ok(#(locale_map, rules, _max_num)) ->
          Ok(DayPeriodRulesData(
            locale_to_rule_set_num: locale_map,
            rules: rules,
          ))
      }
    }
  }
}

fn load_top_entries(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  locale_map: List(#(String, Int)),
  rules: List(#(Int, DayPeriodRules)),
  max_num: Int,
) -> Result(#(List(#(String, Int)), List(#(Int, DayPeriodRules)), Int), String) {
  case entries {
    [] -> Ok(#(locale_map, rules, max_num))
    [#(key, res), ..rest] ->
      case key {
        "locales" -> {
          let locales_table = resource.get_table(rd, res)
          let locales_entries = table_keys_and_res(locales_table)
          case build_locale_map(rd, locales_entries, locale_map, max_num) {
            Error(e) -> Error(e)
            Ok(#(locale_map, max_num)) ->
              load_top_entries(rd, rest, locale_map, rules, max_num)
          }
        }
        "rules" -> {
          let rules_table = resource.get_table(rd, res)
          let rules_entries = table_keys_and_res(rules_table)
          case build_rules_map(rd, rules_entries, rules, max_num) {
            Error(e) -> Error(e)
            Ok(#(rules, max_num)) ->
              load_top_entries(rd, rest, locale_map, rules, max_num)
          }
        }
        _ -> load_top_entries(rd, rest, locale_map, rules, max_num)
      }
  }
}

fn locale_map_get(entries: List(#(String, Int)), key: String) -> Option(Int) {
  case entries {
    [] -> None
    [#(k, v), ..rest] ->
      case k == key {
        True -> Some(v)
        False -> locale_map_get(rest, key)
      }
  }
}

fn get_instance_loop(
  data: DayPeriodRulesData,
  name: Option(String),
) -> Option(DayPeriodRules) {
  case name {
    None -> None
    Some(n) ->
      case locale_map_get(data.locale_to_rule_set_num, n) {
        Some(rule_set_num) if rule_set_num != 0 ->
          finalize_instance(data, rule_set_num)
        _ -> get_instance_loop(data, resbund.chop_locale(n))
      }
  }
}

fn finalize_instance(
  data: DayPeriodRulesData,
  rule_set_num: Int,
) -> Option(DayPeriodRules) {
  case rule_set_num <= 0 {
    True -> None
    False -> {
      let rule = rules_get(data.rules, rule_set_num)
      case get_day_period_for_hour(rule, 0) == DayPeriodUnknown {
        True -> None
        False -> Some(rule)
      }
    }
  }
}

pub fn get_instance(
  bundle: Bundle,
  locale_id: String,
) -> Option(DayPeriodRules) {
  case load_day_period_rules(bundle) {
    Error(_) -> None
    Ok(data) -> {
      let name = case uloc.get_base_name(Some(locale_id)) {
        "" -> "root"
        n -> n
      }
      get_instance_loop(data, Some(name))
    }
  }
}

pub fn get_day_period_rule_set(
  bundle: Bundle,
  locale_id: String,
) -> Option(DayPeriodRules) {
  get_instance(bundle, locale_id)
}
