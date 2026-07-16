import gleam/dict
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/uloc
import intldate/internal/math

pub const ucal_sunday = 1

pub type WeekData {
  WeekData(first_day_of_week: Int, minimal_days_in_first_week: Int)
}

pub type CommonFields {
  CommonFields(
    month: Int,
    day_of_month: Int,
    day_of_week: Int,
    day_of_week_local: Int,
    day_of_year: Int,
    day_of_week_in_month: Int,
    week_of_year: Int,
    week_of_month: Int,
    year_of_week_of_year: Int,
    quarter: Int,
    hour_of_day: Int,
    hour: Int,
    minute: Int,
    second: Int,
    millisecond: Int,
    am_pm: Int,
    is_leap_month: Bool,
  )
}

pub type CalendarFields {
  CalendarFields(era: Int, year: Int, extended_year: Int, common: CommonFields)
}

fn build_likely_subtags_state(
  bundle: Bundle,
) -> Option(loclikelysubtags.LikelySubtagsState) {
  case loclikelysubtags.create_likely_subtags(bundle) {
    Ok(state) -> Some(state)
    Error(_) -> None
  }
}

pub fn get_region_for_supplemental_data(
  bundle: Bundle,
  locale_id: String,
) -> String {
  let language = uloc.get_language(Some(locale_id))
  let region = uloc.get_region(Some(locale_id))
  case language == "" || region == "" {
    False -> region
    True -> {
      let script = uloc.get_script(Some(locale_id))
      case build_likely_subtags_state(bundle) {
        None -> region
        Some(state) ->
          loclikelysubtags.maximize(state, language, script, region, False).region
      }
    }
  }
}

pub fn get_week_data(bundle: Bundle, locale_id: String) -> WeekData {
  let supplemental_data = bundle.supplemental_data

  let region = get_region_for_supplemental_data(bundle, locale_id)

  let found = case region {
    "" -> Error(Nil)
    _ -> dict.get(supplemental_data.week_data, region)
  }

  let found = case found {
    Ok(_) -> found
    _ -> dict.get(supplemental_data.week_data, "001")
  }
  case found {
    Error(_) -> WeekData(ucal_sunday, 1)
    Ok(value) -> {
      WeekData(first_day_of_week: value.0, minimal_days_in_first_week: value.1)
    }
  }
}

fn week_number(
  desired_day: Int,
  day_of_period: Int,
  day_of_week: Int,
  first_day_of_week: Int,
  minimal_days_in_first_week: Int,
) -> Int {
  let period_start_day_of_week =
    { day_of_week - first_day_of_week - day_of_period + 1 } % 7
  let period_start_day_of_week = case period_start_day_of_week < 0 {
    True -> period_start_day_of_week + 7
    False -> period_start_day_of_week
  }
  let week_no = { desired_day + period_start_day_of_week - 1 } / 7
  case 7 - period_start_day_of_week >= minimal_days_in_first_week {
    True -> week_no + 1
    False -> week_no
  }
}

pub fn compute_common_fields(
  bundle: Bundle,
  locale_id: String,
  ext_year: Int,
  month: Int,
  dom: Int,
  dow: Int,
  doy: Int,
  millis_in_day: Int,
  year_length: fn(Int) -> Int,
  week_data_override: Option(WeekData),
) -> CommonFields {
  let millisecond = { { millis_in_day % 1000 } + 1000 } % 1000
  let sec = math.floor_div(millis_in_day, 1000)
  let second = { { sec % 60 } + 60 } % 60
  let min = math.floor_div(millis_in_day, 60_000)
  let minute = { { min % 60 } + 60 } % 60
  let hour_of_day = math.floor_div(millis_in_day, 3_600_000)
  let hour = hour_of_day % 12
  let am_pm = case hour_of_day < 12 {
    True -> 0
    False -> 1
  }

  let day_of_week_in_month = { dom - 1 } / 7 + 1
  let quarter = month / 3

  let week_data = case week_data_override {
    Some(w) -> w
    None -> get_week_data(bundle, locale_id)
  }
  let first_day_of_week = week_data.first_day_of_week
  let minimal_days_in_first_week = week_data.minimal_days_in_first_week

  let dow_local = dow - first_day_of_week + 1
  let dow_local = case dow_local < 1 {
    True -> dow_local + 7
    False -> dow_local
  }

  let rel_dow_jan1 =
    { { { dow - doy + 7001 - first_day_of_week } % 7 } + 7 } % 7
  let woy = { doy - 1 + rel_dow_jan1 } / 7
  let woy = case 7 - rel_dow_jan1 >= minimal_days_in_first_week {
    True -> woy + 1
    False -> woy
  }

  let this_year_length = year_length(ext_year)

  let #(woy, year_of_week_of_year) = case woy == 0 {
    True -> {
      let prev_year_length = year_length(ext_year - 1)
      let prev_doy = doy + prev_year_length
      let woy =
        week_number(
          prev_doy,
          prev_doy,
          dow,
          first_day_of_week,
          minimal_days_in_first_week,
        )
      #(woy, ext_year - 1)
    }
    False -> {
      let rel_dow = {
        { dow + 7 - first_day_of_week } % 7
      }
      case doy >= this_year_length - 5 {
        True -> {
          let last_rel_dow = { rel_dow + this_year_length - doy } % 7
          let last_rel_dow = case last_rel_dow < 0 {
            True -> last_rel_dow + 7
            False -> last_rel_dow
          }
          case
            6 - last_rel_dow >= minimal_days_in_first_week
            && doy + 7 - rel_dow > this_year_length
          {
            True -> #(1, ext_year + 1)
            False -> #(woy, ext_year)
          }
        }
        False -> #(woy, ext_year)
      }
    }
  }

  let week_of_month =
    week_number(dom, dom, dow, first_day_of_week, minimal_days_in_first_week)

  CommonFields(
    month:,
    day_of_month: dom,
    day_of_week: dow,
    day_of_week_local: dow_local,
    day_of_year: doy,
    day_of_week_in_month:,
    week_of_year: woy,
    week_of_month:,
    year_of_week_of_year:,
    quarter:,
    hour_of_day:,
    hour:,
    minute:,
    second:,
    millisecond:,
    am_pm:,
    is_leap_month: False,
  )
}

pub fn gregorian_year_length(year: Int) -> Int {
  case gregoimp.is_leap_year(year) {
    True -> 366
    False -> 365
  }
}

pub fn compute_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
  week_data_override: Option(WeekData),
) -> CalendarFields {
  let local_millis = epoch_millis + zone_offset_millis
  let fields = gregoimp.time_to_fields(local_millis)
  let ext_year = fields.year

  let era = case ext_year <= 0 {
    True -> 0
    False -> 1
  }
  let year = case ext_year <= 0 {
    True -> 1 - ext_year
    False -> ext_year
  }

  let common =
    compute_common_fields(
      bundle,
      locale_id,
      ext_year,
      fields.month,
      fields.dom,
      fields.dow,
      fields.doy,
      fields.millis_in_day,
      gregorian_year_length,
      week_data_override,
    )

  CalendarFields(era:, year:, extended_year: ext_year, common:)
}
