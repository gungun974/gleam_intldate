import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string
import intldate/internal/icu/icudata/resource
import intldate_generate/icurb
import intldate_generate/save
import intldate_generate/shared
import simplifile

type RawDayPeriods {
  RawDayPeriods(
    locales: dict.Dict(String, String),
    rules: dict.Dict(String, dict.Dict(String, dict.Dict(String, List(String)))),
  )
}

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/dayPeriods.txt")

  let assert Ok(raw) = parse_day_period_rules_raw(contents)
  let assert Ok(data) = build_day_period_rules_data(raw)
  save.save_day_period_rules_data(data)
  data
}

fn parse_day_period_rules_raw(contents: String) {
  icurb.parse(contents, {
    use locales <- decode.field(
      "locales",
      decode.dict(decode.string, decode.string),
    )

    use rules <- decode.field(
      "rules",
      decode.dict(
        decode.string,
        decode.dict(
          decode.string,
          decode.dict(
            decode.string,
            decode.one_of(decode.list(decode.string), [
              {
                use value <- decode.then(decode.string)
                decode.success([value])
              },
            ]),
          ),
        ),
      ),
    )

    decode.success(RawDayPeriods(locales:, rules:))
  })
}

const day_period_cutoff_before = 0

const day_period_cutoff_after = 1

const day_period_cutoff_from = 2

const day_period_cutoff_at = 3

fn get_day_period_from_string(type_str: String) -> resource.DayPeriod {
  case type_str {
    "midnight" -> resource.Midnight
    "noon" -> resource.Noon
    "morning1" -> resource.Morning1
    "afternoon1" -> resource.Afternoon1
    "evening1" -> resource.Evening1
    "night1" -> resource.Night1
    "morning2" -> resource.Morning2
    "afternoon2" -> resource.Afternoon2
    "evening2" -> resource.Evening2
    "night2" -> resource.Night2
    "am" -> resource.Am
    "pm" -> resource.Pm
    _ -> resource.DayPeriodUnknown
  }
}

fn get_cutoff_type_from_string(type_str: String) -> Int {
  case type_str {
    "from" -> day_period_cutoff_from
    "before" -> day_period_cutoff_before
    "after" -> day_period_cutoff_after
    "at" -> day_period_cutoff_at
    _ -> -1
  }
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
          case shared.is_digit(d0) {
            False -> Error("U_INVALID_FORMAT_ERROR")
            True -> {
              let hour = shared.digit_value(d0)
              case hour_limit == 2 {
                False -> Ok(hour)
                True -> {
                  let d1 = string.slice(time, 1, 1)
                  case shared.is_digit(d1) {
                    False -> Error("U_INVALID_FORMAT_ERROR")
                    True -> {
                      let hour = hour * 10 + shared.digit_value(d1)
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
      case parse_set_num_digits(string.to_graphemes(digits), 0) {
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
      case shared.is_digit(c) {
        False -> Error("U_INVALID_FORMAT_ERROR")
        True -> parse_set_num_digits(rest, 10 * acc + shared.digit_value(c))
      }
  }
}

fn bit_set(mask: Int, bit: Int) -> Bool {
  int.bitwise_and(mask, bit) != 0
}

fn cutoffs_or(
  cutoffs: dict.Dict(Int, Int),
  hour: Int,
  bit: Int,
) -> dict.Dict(Int, Int) {
  case dict.get(cutoffs, hour) {
    Ok(mask) -> dict.insert(cutoffs, hour, int.bitwise_or(mask, bit))
    Error(_) -> dict.insert(cutoffs, hour, bit)
  }
}

fn cutoffs_get(cutoffs: dict.Dict(Int, Int), hour: Int) -> Int {
  case dict.get(cutoffs, hour) {
    Ok(mask) -> mask
    Error(_) -> 0
  }
}

fn apply_cutoff_values(
  cutoffs: dict.Dict(Int, Int),
  values: List(String),
  cutoff_type: Int,
) -> Result(dict.Dict(Int, Int), String) {
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
  entries: List(#(String, List(String))),
  cutoffs: dict.Dict(Int, Int),
) -> Result(dict.Dict(Int, Int), String) {
  case entries {
    [] -> Ok(cutoffs)
    [#(key, values), ..rest] -> {
      let cutoff_type = get_cutoff_type_from_string(key)
      case apply_cutoff_values(cutoffs, values, cutoff_type) {
        Error(e) -> Error(e)
        Ok(cutoffs) -> process_period_definition(rest, cutoffs)
      }
    }
  }
}

fn day_period_rules_add(
  rule: resource.DayPeriodRules,
  start_hour: Int,
  limit_hour: Int,
  period: resource.DayPeriod,
) -> resource.DayPeriodRules {
  day_period_rules_add_loop(rule, start_hour, limit_hour, period)
}

fn day_period_rules_add_loop(
  rule: resource.DayPeriodRules,
  i: Int,
  limit_hour: Int,
  period: resource.DayPeriod,
) -> resource.DayPeriodRules {
  case i == limit_hour {
    True -> rule
    False -> {
      let i = case i == 24 {
        True -> 0
        False -> i
      }
      let rule =
        resource.DayPeriodRules(
          ..rule,
          day_period_for_hour: dict.insert(rule.day_period_for_hour, i, period),
        )
      day_period_rules_add_loop(rule, i + 1, limit_hour, period)
    }
  }
}

fn find_limit_hour(
  cutoffs: dict.Dict(Int, Int),
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
          int.bitwise_shift_left(1, day_period_cutoff_before),
        )
      {
        True -> Ok(hour)
        False -> find_limit_hour(cutoffs, start_hour, hour + 1)
      }
    }
  }
}

fn build_rule_from_cutoffs(
  rule: resource.DayPeriodRules,
  period: resource.DayPeriod,
  cutoffs: dict.Dict(Int, Int),
  start_hour: Int,
) -> Result(resource.DayPeriodRules, String) {
  case start_hour > 24 {
    True -> Ok(rule)
    False -> {
      let mask = cutoffs_get(cutoffs, start_hour)
      case bit_set(mask, int.bitwise_shift_left(1, day_period_cutoff_at)) {
        True ->
          case start_hour == 0 && period == resource.Midnight {
            True -> {
              let rule = resource.DayPeriodRules(..rule, has_midnight: True)
              build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
            }
            False ->
              case start_hour == 12 && period == resource.Noon {
                True -> {
                  let rule = resource.DayPeriodRules(..rule, has_noon: True)
                  build_rule_from_cutoffs(rule, period, cutoffs, start_hour + 1)
                }
                False -> Error("U_INVALID_FORMAT_ERROR")
              }
          }
        False ->
          case
            bit_set(mask, int.bitwise_shift_left(1, day_period_cutoff_from))
            || bit_set(mask, int.bitwise_shift_left(1, day_period_cutoff_after))
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

fn hours_0_23() -> List(Int) {
  hours_0_23_loop(0)
}

fn hours_0_23_loop(hour: Int) -> List(Int) {
  case hour > 23 {
    True -> []
    False -> [hour, ..hours_0_23_loop(hour + 1)]
  }
}

fn create_day_period_rules() -> resource.DayPeriodRules {
  resource.DayPeriodRules(
    has_midnight: False,
    has_noon: False,
    day_period_for_hour: hours_0_23()
      |> list.fold(dict.new(), fn(acc, hour) {
        dict.insert(acc, hour, resource.DayPeriodUnknown)
      }),
  )
}

fn all_hours_are_set(rule: resource.DayPeriodRules) -> Bool {
  hours_0_23()
  |> list.all(fn(hour) {
    dict.get(rule.day_period_for_hour, hour) != Ok(resource.DayPeriodUnknown)
  })
}

fn process_rule_set_entries(
  entries: List(#(String, dict.Dict(String, List(String)))),
  rule: resource.DayPeriodRules,
) -> Result(resource.DayPeriodRules, String) {
  case entries {
    [] -> Ok(rule)
    [#(key, period_definition), ..rest] -> {
      let period = get_day_period_from_string(key)
      case period == resource.DayPeriodUnknown {
        True -> Error("U_INVALID_FORMAT_ERROR")
        False ->
          case
            process_period_definition(
              dict.to_list(period_definition),
              dict.new(),
            )
          {
            Error(e) -> Error(e)
            Ok(cutoffs) ->
              case build_rule_from_cutoffs(rule, period, cutoffs, 0) {
                Error(e) -> Error(e)
                Ok(rule) -> process_rule_set_entries(rest, rule)
              }
          }
      }
    }
  }
}

fn build_locale_map(
  entries: List(#(String, String)),
  map: dict.Dict(String, Int),
) -> Result(dict.Dict(String, Int), String) {
  case entries {
    [] -> Ok(map)
    [#(locale, set_name), ..rest] ->
      case parse_set_num(set_name) {
        Error(e) -> Error(e)
        Ok(set_num) -> build_locale_map(rest, dict.insert(map, locale, set_num))
      }
  }
}

fn build_rules_map(
  entries: List(#(String, dict.Dict(String, dict.Dict(String, List(String))))),
  rules: dict.Dict(Int, resource.DayPeriodRules),
) -> Result(dict.Dict(Int, resource.DayPeriodRules), String) {
  case entries {
    [] -> Ok(rules)
    [#(set_name, rule_set), ..rest] ->
      case parse_set_num(set_name) {
        Error(e) -> Error(e)
        Ok(set_num) ->
          case
            process_rule_set_entries(
              dict.to_list(rule_set),
              create_day_period_rules(),
            )
          {
            Error(e) -> Error(e)
            Ok(rule) ->
              case all_hours_are_set(rule) {
                False -> Error("U_INVALID_FORMAT_ERROR")
                True -> build_rules_map(rest, dict.insert(rules, set_num, rule))
              }
          }
      }
  }
}

fn build_day_period_rules_data(
  raw: RawDayPeriods,
) -> Result(resource.DayPeriodRulesData, String) {
  case build_locale_map(dict.to_list(raw.locales), dict.new()) {
    Error(e) -> Error(e)
    Ok(locales) ->
      case build_rules_map(dict.to_list(raw.rules), dict.new()) {
        Error(e) -> Error(e)
        Ok(rules) -> Ok(resource.DayPeriodRulesData(locales:, rules:))
      }
  }
}
