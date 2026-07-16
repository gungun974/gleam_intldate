import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/resource.{type JapaneseEra}

pub fn load_japanese_eras(bundle: Bundle) -> List(JapaneseEra) {
  bundle.supplemental_data.japanese_eras
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

fn find_era(
  eras: List(JapaneseEra),
  year: Int,
  month: Int,
  day: Int,
) -> Option(JapaneseEra) {
  find_era_loop(eras, year, month, day, None)
}

fn find_era_loop(
  eras: List(JapaneseEra),
  year: Int,
  month: Int,
  day: Int,
  oldest: Option(JapaneseEra),
) -> Option(JapaneseEra) {
  case eras {
    [] -> oldest
    [era, ..rest] ->
      case is_on_or_after(year, month, day, era) {
        True -> Some(era)
        False -> find_era_loop(rest, year, month, day, Some(era))
      }
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

  let #(era_index, year) = case
    find_era(eras, f.extended_year, month_one_based, f.common.day_of_month)
  {
    Some(era) -> #(era.index, f.extended_year - era.year + 1)
    None -> #(0, f.extended_year)
  }

  gregocal.CalendarFields(..f, era: era_index, year:)
}
