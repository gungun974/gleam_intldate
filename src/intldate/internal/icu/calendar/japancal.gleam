import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource

pub type JapaneseEra {
  JapaneseEra(year: Int, month: Int, day: Int, named: Bool)
}

fn era_at_index(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  index: Int,
) -> Option(JapaneseEra) {
  case
    resbund.get_by_path(
      bundle,
      chain,
      "calendarData/japanese/eras/" <> int.to_string(index) <> "/start",
      0,
    )
  {
    None -> None
    Some(found) -> {
      let named = case
        resbund.get_by_path(
          bundle,
          chain,
          "calendarData/japanese/eras/" <> int.to_string(index) <> "/named",
          0,
        )
      {
        None -> True
        Some(named_found) -> {
          let value =
            resource.create_resource_value(
              Some(named_found.res_data),
              named_found.res,
            )
          case resource.resource_value_get_string(value) {
            Some(s) -> s.text != "false"
            None -> True
          }
        }
      }
      let value =
        resource.create_resource_value(Some(found.res_data), found.res)
      case resource.resource_value_get_int_vector(value) {
        Some([year, month, day, ..]) ->
          Some(JapaneseEra(year:, month:, day:, named:))
        _ -> None
      }
    }
  }
}

fn load_eras_loop(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  index: Int,
  acc: List(JapaneseEra),
) -> List(JapaneseEra) {
  case era_at_index(bundle, chain, index) {
    None -> list_reverse(acc)
    Some(era) -> load_eras_loop(bundle, chain, index + 1, [era, ..acc])
  }
}

fn list_reverse(list: List(a)) -> List(a) {
  list_reverse_loop(list, [])
}

fn list_reverse_loop(list: List(a), acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [head, ..tail] -> list_reverse_loop(tail, [head, ..acc])
  }
}

fn drop_trailing_unnamed(eras: List(JapaneseEra)) -> List(JapaneseEra) {
  let reversed = list_reverse(eras)
  list_reverse(drop_leading_unnamed(reversed))
}

fn drop_leading_unnamed(eras: List(JapaneseEra)) -> List(JapaneseEra) {
  case eras {
    [head, ..tail] ->
      case head.named {
        False -> drop_leading_unnamed(tail)
        True -> eras
      }
    [] -> []
  }
}

pub fn load_japanese_eras(bundle: Bundle) -> List(JapaneseEra) {
  let rd = resbund.open_direct_or_panic(bundle, "supplementalData")
  let chain = [resbund.LocaleChainEntry("supplementalData", Some(rd))]
  load_eras_loop(bundle, chain, 0, [])
  |> drop_trailing_unnamed
}

fn is_on_or_after(year: Int, month: Int, day: Int, era: JapaneseEra) -> Bool {
  case year != era.year {
    True -> year > era.year
    False ->
      case month != era.month {
        True -> month > era.month
        False -> day >= era.day
      }
  }
}

fn find_era_index(
  eras: List(JapaneseEra),
  year: Int,
  month: Int,
  day: Int,
) -> Int {
  let reversed = list_reverse(eras)
  find_era_index_from_reversed(
    reversed,
    year,
    month,
    day,
    list.length(eras) - 1,
  )
}

fn find_era_index_from_reversed(
  reversed_eras: List(JapaneseEra),
  year: Int,
  month: Int,
  day: Int,
  start_index: Int,
) -> Int {
  case reversed_eras {
    [] -> 0
    [era, ..rest] ->
      case is_on_or_after(year, month, day, era) {
        True -> start_index
        False ->
          find_era_index_from_reversed(rest, year, month, day, start_index - 1)
      }
  }
}

fn era_at(eras: List(JapaneseEra), index: Int) -> Option(JapaneseEra) {
  case eras, index {
    [], _ -> None
    [head, ..], 0 -> Some(head)
    [_, ..tail], _ -> era_at(tail, index - 1)
  }
}

pub fn compute_japanese_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  let f =
    gregocal.compute_fields(
      bundle,
      locale_id,
      epoch_millis,
      zone_offset_millis,
      None,
    )
  let eras = load_japanese_eras(bundle)
  let month_one_based = f.common.month + 1

  let era_index =
    find_era_index(
      eras,
      f.extended_year,
      month_one_based,
      f.common.day_of_month,
    )

  let year = case era_at(eras, era_index) {
    Some(era) -> f.extended_year - era.year + 1
    None -> f.extended_year
  }

  gregocal.CalendarFields(..f, era: era_index, year:)
}
