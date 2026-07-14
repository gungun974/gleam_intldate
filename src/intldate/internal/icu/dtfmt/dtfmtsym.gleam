import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resbund.{type Bundle, type LocaleChainEntry}
import intldate/internal/icu/icudata/resource

pub type DateFormatSymbols {
  DateFormatSymbols(
    bundle: Option(Bundle),
    chain: Option(List(LocaleChainEntry)),
    cal_type: String,
  )
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

fn get_array_string_at(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  path: String,
  index: Int,
) -> Option(String) {
  case resbund.get_by_path(bundle, chain, path, 0) {
    None -> None
    Some(found) -> {
      let arr = resource.get_array(found.res_data, found.res)
      case arr.get_res {
        None -> None
        Some(get_res) ->
          case index < 0 || index >= arr.length {
            True -> None
            False -> resource_string_text(found.res_data, get_res(index))
          }
      }
    }
  }
}

fn get_table_string(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  path: String,
  key: String,
) -> Option(String) {
  case resbund.get_by_path(bundle, chain, path <> "/" <> key, 0) {
    None -> None
    Some(found) -> resource_string_text(found.res_data, found.res)
  }
}

fn text_cal_type(cal_type: String) -> String {
  case cal_type == "iso8601" {
    True -> "gregorian"
    False -> cal_type
  }
}

fn chain_key(chain: List(LocaleChainEntry)) -> String {
  case chain {
    [head, ..] -> head.name
    [] -> ""
  }
}

fn cached_symbol(key: String, build: fn() -> Option(String)) -> Option(String) {
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) -> cache.put(key, build())
  }
}

pub fn get_month_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  month: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_month_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> context
      <> "\n"
      <> width
      <> "\n"
      <> int.to_string(month),
    fn() {
      uncached_get_month_name(bundle, chain, cal_type, context, width, month)
    },
  )
}

pub fn get_day_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  dow: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_day_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> context
      <> "\n"
      <> width
      <> "\n"
      <> int.to_string(dow),
    fn() { uncached_get_day_name(bundle, chain, cal_type, context, width, dow) },
  )
}

pub fn get_quarter_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  quarter: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_quarter_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> context
      <> "\n"
      <> width
      <> "\n"
      <> int.to_string(quarter),
    fn() {
      uncached_get_quarter_name(
        bundle,
        chain,
        cal_type,
        context,
        width,
        quarter,
      )
    },
  )
}

pub fn get_era_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  width: String,
  era: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_era_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> width
      <> "\n"
      <> int.to_string(era),
    fn() { uncached_get_era_name(bundle, chain, cal_type, width, era) },
  )
}

pub fn get_am_pm(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type_in: String,
  width: String,
  am_pm: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_am_pm"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type_in
      <> "\n"
      <> width
      <> "\n"
      <> int.to_string(am_pm),
    fn() { uncached_get_am_pm(bundle, chain, cal_type_in, width, am_pm) },
  )
}

pub fn get_day_period_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  period_name: String,
) -> Option(String) {
  cached_symbol(
    "sym/get_day_period_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> context
      <> "\n"
      <> width
      <> "\n"
      <> period_name,
    fn() {
      uncached_get_day_period_name(
        bundle,
        chain,
        cal_type,
        context,
        width,
        period_name,
      )
    },
  )
}

pub fn get_cyclic_year_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  year_of_cycle: Int,
) -> Option(String) {
  cached_symbol(
    "sym/get_cyclic_year_name"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> int.to_string(year_of_cycle),
    fn() {
      uncached_get_cyclic_year_name(bundle, chain, cal_type, year_of_cycle)
    },
  )
}

pub fn get_leap_month_pattern(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  cached_symbol(
    "sym/get_leap_month_pattern"
      <> "\n"
      <> bundle.data_path
      <> "\n"
      <> chain_key(chain)
      <> "\n"
      <> cal_type
      <> "\n"
      <> context
      <> "\n"
      <> width,
    fn() {
      uncached_get_leap_month_pattern(bundle, chain, cal_type, context, width)
    },
  )
}

fn uncached_get_month_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  month: Int,
) -> Option(String) {
  case width == "wide" || width == "abbreviated" {
    True -> {
      let path =
        "calendar/"
        <> text_cal_type(cal_type)
        <> "/monthNames/"
        <> context
        <> "/"
        <> width
      case get_array_string_at(bundle, chain, path, month) {
        Some(value) -> Some(value)
        None ->
          case context == "stand-alone" {
            True ->
              get_array_string_at(
                bundle,
                chain,
                "calendar/"
                  <> text_cal_type(cal_type)
                  <> "/monthNames/format/"
                  <> width,
                month,
              )
            False -> None
          }
      }
    }
    False -> {
      let base = "calendar/" <> text_cal_type(cal_type) <> "/monthNames/"
      let from_narrow = case context == "format" {
        True ->
          case
            get_array_string_at(bundle, chain, base <> "format/narrow", month)
          {
            Some(value) -> Some(value)
            None ->
              get_array_string_at(
                bundle,
                chain,
                base <> "stand-alone/narrow",
                month,
              )
          }
        False ->
          case
            get_array_string_at(
              bundle,
              chain,
              base <> "stand-alone/narrow",
              month,
            )
          {
            Some(value) -> Some(value)
            None ->
              get_array_string_at(bundle, chain, base <> "format/narrow", month)
          }
      }
      case from_narrow {
        Some(value) -> Some(value)
        None ->
          get_array_string_at(
            bundle,
            chain,
            base <> "format/abbreviated",
            month,
          )
      }
    }
  }
}

fn uncached_get_day_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  dow: Int,
) -> Option(String) {
  let index = dow - 1
  case width == "wide" || width == "abbreviated" {
    True -> {
      let path =
        "calendar/"
        <> text_cal_type(cal_type)
        <> "/dayNames/"
        <> context
        <> "/"
        <> width
      case get_array_string_at(bundle, chain, path, index) {
        Some(value) -> Some(value)
        None ->
          case context == "stand-alone" {
            True ->
              get_array_string_at(
                bundle,
                chain,
                "calendar/"
                  <> text_cal_type(cal_type)
                  <> "/dayNames/format/"
                  <> width,
                index,
              )
            False -> None
          }
      }
    }
    False ->
      case width == "short" {
        True -> {
          let own =
            get_array_string_at(
              bundle,
              chain,
              "calendar/"
                <> text_cal_type(cal_type)
                <> "/dayNames/"
                <> context
                <> "/short",
              index,
            )
          case own {
            Some(value) -> Some(value)
            None ->
              case context == "stand-alone" {
                True ->
                  case
                    get_array_string_at(
                      bundle,
                      chain,
                      "calendar/"
                        <> text_cal_type(cal_type)
                        <> "/dayNames/format/short",
                      index,
                    )
                  {
                    Some(value) -> Some(value)
                    None ->
                      get_array_string_at(
                        bundle,
                        chain,
                        "calendar/"
                          <> text_cal_type(cal_type)
                          <> "/dayNames/format/abbreviated",
                        index,
                      )
                  }
                False -> None
              }
          }
        }
        False -> {
          let base = "calendar/" <> text_cal_type(cal_type) <> "/dayNames/"
          let from_narrow = case context == "format" {
            True ->
              case
                get_array_string_at(
                  bundle,
                  chain,
                  base <> "format/narrow",
                  index,
                )
              {
                Some(value) -> Some(value)
                None ->
                  get_array_string_at(
                    bundle,
                    chain,
                    base <> "stand-alone/narrow",
                    index,
                  )
              }
            False ->
              case
                get_array_string_at(
                  bundle,
                  chain,
                  base <> "stand-alone/narrow",
                  index,
                )
              {
                Some(value) -> Some(value)
                None ->
                  get_array_string_at(
                    bundle,
                    chain,
                    base <> "format/narrow",
                    index,
                  )
              }
          }
          case from_narrow {
            Some(value) -> Some(value)
            None ->
              get_array_string_at(
                bundle,
                chain,
                base <> "format/abbreviated",
                index,
              )
          }
        }
      }
  }
}

fn uncached_get_quarter_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  quarter: Int,
) -> Option(String) {
  case width == "narrow" {
    True ->
      case context == "stand-alone" {
        True ->
          get_array_string_at(
            bundle,
            chain,
            "calendar/"
              <> text_cal_type(cal_type)
              <> "/quarters/stand-alone/narrow",
            quarter,
          )
        False ->
          case
            get_array_string_at(
              bundle,
              chain,
              "calendar/"
                <> text_cal_type(cal_type)
                <> "/quarters/format/narrow",
              quarter,
            )
          {
            Some(value) -> Some(value)
            None ->
              get_array_string_at(
                bundle,
                chain,
                "calendar/"
                  <> text_cal_type(cal_type)
                  <> "/quarters/stand-alone/narrow",
                quarter,
              )
          }
      }
    False -> {
      let own =
        get_array_string_at(
          bundle,
          chain,
          "calendar/"
            <> text_cal_type(cal_type)
            <> "/quarters/"
            <> context
            <> "/"
            <> width,
          quarter,
        )
      case own {
        Some(value) -> Some(value)
        None ->
          case width == "abbreviated" {
            True ->
              case context == "stand-alone" {
                True ->
                  case
                    get_array_string_at(
                      bundle,
                      chain,
                      "calendar/"
                        <> text_cal_type(cal_type)
                        <> "/quarters/format/abbreviated",
                      quarter,
                    )
                  {
                    Some(value) -> Some(value)
                    None ->
                      get_array_string_at(
                        bundle,
                        chain,
                        "calendar/"
                          <> text_cal_type(cal_type)
                          <> "/quarters/format/wide",
                        quarter,
                      )
                  }
                False ->
                  get_array_string_at(
                    bundle,
                    chain,
                    "calendar/"
                      <> text_cal_type(cal_type)
                      <> "/quarters/format/wide",
                    quarter,
                  )
              }
            False ->
              case context == "stand-alone" {
                True ->
                  get_array_string_at(
                    bundle,
                    chain,
                    "calendar/"
                      <> text_cal_type(cal_type)
                      <> "/quarters/format/wide",
                    quarter,
                  )
                False -> None
              }
          }
      }
    }
  }
}

fn uncached_get_era_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  width: String,
  era: Int,
) -> Option(String) {
  let path = "calendar/" <> text_cal_type(cal_type) <> "/eras/" <> width
  case get_table_string(bundle, chain, path, int.to_string(era)) {
    Some(own) -> Some(own)
    None ->
      case width == "abbreviated" {
        True -> None
        False ->
          get_table_string(
            bundle,
            chain,
            "calendar/" <> text_cal_type(cal_type) <> "/eras/abbreviated",
            int.to_string(era),
          )
      }
  }
}

fn get_am_pm_at(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  key: String,
  am_pm: Int,
) -> Option(String) {
  let own =
    get_array_string_at(
      bundle,
      chain,
      "calendar/" <> cal_type <> "/" <> key,
      am_pm,
    )
  case own {
    Some(_) -> own
    None ->
      case cal_type == "gregorian" {
        True -> None
        False ->
          get_array_string_at(
            bundle,
            chain,
            "calendar/gregorian/" <> key,
            am_pm,
          )
      }
  }
}

fn uncached_get_am_pm(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type_in: String,
  width: String,
  am_pm: Int,
) -> Option(String) {
  let cal_type = text_cal_type(cal_type_in)
  let from_width = case width == "narrow" {
    True -> get_am_pm_at(bundle, chain, cal_type, "AmPmMarkersNarrow", am_pm)
    False ->
      case width == "wide" {
        True -> get_am_pm_at(bundle, chain, cal_type, "AmPmMarkers", am_pm)
        False -> None
      }
  }
  case from_width {
    Some(v) -> Some(v)
    None -> get_am_pm_at(bundle, chain, cal_type, "AmPmMarkersAbbr", am_pm)
  }
}

fn uncached_get_day_period_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  period_name: String,
) -> Option(String) {
  let path =
    "calendar/"
    <> text_cal_type(cal_type)
    <> "/dayPeriod/"
    <> context
    <> "/"
    <> width
  case get_table_string(bundle, chain, path, period_name) {
    Some(found) -> Some(found)
    None ->
      case width == "wide" || width == "narrow" {
        True ->
          get_table_string(
            bundle,
            chain,
            "calendar/"
              <> text_cal_type(cal_type)
              <> "/dayPeriod/"
              <> context
              <> "/abbreviated",
            period_name,
          )
        False -> None
      }
  }
}

fn uncached_get_cyclic_year_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  year_of_cycle: Int,
) -> Option(String) {
  case
    get_array_string_at(
      bundle,
      chain,
      "calendar/" <> cal_type <> "/cyclicNameSets/years/format/abbreviated",
      year_of_cycle - 1,
    )
  {
    None -> None
    Some(value) -> Some(value)
  }
}

fn raw_leap_month_pattern(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  get_table_string(
    bundle,
    chain,
    "calendar/" <> cal_type <> "/monthPatterns/" <> context <> "/" <> width,
    "leap",
  )
}

fn uncached_get_leap_month_pattern(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  case width == "numeric" {
    True -> raw_leap_month_pattern(bundle, chain, cal_type, "numeric", "all")
    False -> {
      let format_wide =
        raw_leap_month_pattern(bundle, chain, cal_type, "format", "wide")
      let standalone_narrow =
        raw_leap_month_pattern(bundle, chain, cal_type, "stand-alone", "narrow")
      let format_abbrev_own =
        raw_leap_month_pattern(bundle, chain, cal_type, "format", "abbreviated")
      let format_abbrev = case format_abbrev_own {
        Some(_) -> format_abbrev_own
        None -> format_wide
      }
      case context == "format" {
        True ->
          case width {
            "wide" -> format_wide
            "abbreviated" -> format_abbrev
            "narrow" -> {
              let own =
                raw_leap_month_pattern(
                  bundle,
                  chain,
                  cal_type,
                  "format",
                  "narrow",
                )
              case own {
                Some(_) -> own
                None -> standalone_narrow
              }
            }
            _ -> None
          }
        False ->
          case width {
            "wide" -> {
              let own =
                raw_leap_month_pattern(
                  bundle,
                  chain,
                  cal_type,
                  "stand-alone",
                  "wide",
                )
              case own {
                Some(_) -> own
                None -> format_wide
              }
            }
            "abbreviated" -> {
              let own =
                raw_leap_month_pattern(
                  bundle,
                  chain,
                  cal_type,
                  "stand-alone",
                  "abbreviated",
                )
              case own {
                Some(_) -> own
                None -> format_abbrev
              }
            }
            "narrow" -> standalone_narrow
            _ -> None
          }
      }
    }
  }
}

pub fn apply_leap_month_pattern(
  pattern: Option(String),
  month_text: String,
) -> String {
  case pattern {
    None -> month_text
    Some(p) -> string_replace_once(p, "{0}", month_text)
  }
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
