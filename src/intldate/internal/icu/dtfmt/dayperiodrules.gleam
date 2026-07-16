import gleam/dict
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/resource.{
  type DayPeriod, type DayPeriodRules, DayPeriodUnknown,
}
import intldate/internal/icu/locale/uloc

pub fn get_day_period_for_hour(rules: DayPeriodRules, hour: Int) -> DayPeriod {
  case dict.get(rules.day_period_for_hour, hour) {
    Ok(period) -> period
    Error(_) -> DayPeriodUnknown
  }
}

fn find_rule_set_num(
  locales: dict.Dict(String, Int),
  name: String,
) -> Option(Int) {
  case dict.get(locales, name) {
    Ok(rule_set_num) -> Some(rule_set_num)
    Error(_) ->
      case bundle.chop_locale(name) {
        None -> None
        Some(next_name) -> find_rule_set_num(locales, next_name)
      }
  }
}

fn finalize_instance(
  rules: dict.Dict(Int, DayPeriodRules),
  rule_set_num: Int,
) -> Option(DayPeriodRules) {
  case rule_set_num <= 0 {
    True -> None
    False ->
      case dict.get(rules, rule_set_num) {
        Error(_) -> None
        Ok(rule) ->
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
  let data = bundle.day_period_rules
  let name = case uloc.get_base_name(Some(locale_id)) {
    "" -> bundle.root_locale_name
    n -> n
  }
  case find_rule_set_num(data.locales, name) {
    None -> None
    Some(rule_set_num) -> finalize_instance(data.rules, rule_set_num)
  }
}

pub fn get_day_period_rule_set(
  bundle: Bundle,
  locale_id: String,
) -> Option(DayPeriodRules) {
  get_instance(bundle, locale_id)
}
