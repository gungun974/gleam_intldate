import gleam/dict.{type Dict}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle, type LocaleChainEntry}
import intldate/internal/icu/icudata/resource

pub type DateFormatSymbols {
  DateFormatSymbols(
    bundle: Option(Bundle),
    chain: Option(List(LocaleChainEntry)),
    cal_type: String,
  )
}

fn text_cal_type(cal_type: String) -> String {
  case cal_type == "iso8601" {
    True -> "gregorian"
    False -> cal_type
  }
}

fn list_at(items: List(String), index: Int) -> Option(String) {
  case index < 0 {
    True -> None
    False -> list_at_loop(items, index)
  }
}

fn list_at_loop(items: List(String), index: Int) -> Option(String) {
  case items, index {
    [], _ -> None
    [x, ..], 0 -> Some(x)
    [_, ..rest], n -> list_at_loop(rest, n - 1)
  }
}

/// Walks the locale chain looking for `field` on `cal_type`. A field that
/// resolves at some level to a real value is handed to `leaf_extract`; if
/// that extraction misses (the value exists but doesn't cover the specific
/// leaf being asked for), the walk continues down the *same* chain for the
/// *same* calendar, since CLDR data inherits leaf-by-leaf. A field that
/// resolves to an alias (almost always `<cal>.field -> gregorian.field`)
/// restarts the walk from the top of the chain for the alias's target
/// calendar, matching how ICU's resource alias resolution works — the
/// alias-defining locale level is very often just `root`, so redirecting
/// with the *original* chain (not the remaining tail) is what makes
/// non-Gregorian calendars pick up the requesting locale's own translated
/// Gregorian names instead of root's placeholders.
fn find_leaf(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  full_chain: List(LocaleChainEntry),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) -> Option(resource.CalendarField(s)),
  leaf_extract: fn(s) -> Option(t),
  depth: Int,
) -> Option(t) {
  case depth >= 6 {
    True -> None
    False ->
      case chain {
        [] -> None
        [level, ..rest] ->
          case dict.get(locales, level.name) {
            Error(_) ->
              find_leaf(
                locales,
                full_chain,
                rest,
                cal_type,
                field,
                leaf_extract,
                depth,
              )
            Ok(by_cal) ->
              case dict.get(by_cal, cal_type) {
                Error(_) ->
                  find_leaf(
                    locales,
                    full_chain,
                    rest,
                    cal_type,
                    field,
                    leaf_extract,
                    depth,
                  )
                Ok(cs) ->
                  case field(cs) {
                    None ->
                      find_leaf(
                        locales,
                        full_chain,
                        rest,
                        cal_type,
                        field,
                        leaf_extract,
                        depth,
                      )
                    Some(resource.CalendarAliasTo(target_cal)) ->
                      find_leaf(
                        locales,
                        full_chain,
                        full_chain,
                        target_cal,
                        field,
                        leaf_extract,
                        depth + 1,
                      )
                    Some(resource.CalendarValue(s)) ->
                      case leaf_extract(s) {
                        Some(v) -> Some(v)
                        None ->
                          find_leaf(
                            locales,
                            full_chain,
                            rest,
                            cal_type,
                            field,
                            leaf_extract,
                            depth,
                          )
                      }
                  }
              }
          }
      }
  }
}

fn pick_width_names(
  w: resource.WidthNames,
  width: String,
) -> Option(resource.CalendarLeaf(List(String))) {
  case width {
    "wide" -> w.wide
    "abbreviated" -> w.abbreviated
    "narrow" -> w.narrow
    "short" -> w.short
    _ -> None
  }
}

fn pick_context_names(
  names: resource.ContextNames,
  context: String,
) -> resource.WidthNames {
  case context {
    "stand-alone" -> names.stand_alone
    _ -> names.format
  }
}

fn lookup_array_at(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextNames)),
  context: String,
  width: String,
  index: Int,
) -> Option(String) {
  lookup_array_at_loop(
    locales,
    chain,
    cal_type,
    field,
    context,
    width,
    index,
    0,
  )
}

fn lookup_array_at_loop(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextNames)),
  context: String,
  width: String,
  index: Int,
  depth: Int,
) -> Option(String) {
  case depth >= 6 {
    True -> None
    False ->
      case
        find_leaf(
          locales,
          chain,
          chain,
          cal_type,
          field,
          fn(names) {
            pick_width_names(pick_context_names(names, context), width)
          },
          depth,
        )
      {
        None -> None
        Some(resource.CalendarLeafValue(arr)) -> list_at(arr, index)
        Some(resource.CalendarLeafAliasTo(target)) ->
          case parse_names_leaf_alias(target) {
            None -> None
            Some(#(target_cal, target_context, target_width)) ->
              lookup_array_at_loop(
                locales,
                chain,
                target_cal,
                field,
                target_context,
                target_width,
                index,
                depth + 1,
              )
          }
      }
  }
}

fn parse_names_leaf_alias(target: String) -> Option(#(String, String, String)) {
  case string.split(target, "/") {
    ["", "LOCALE", "calendar", cal, _, context, width] ->
      Some(#(cal, context, width))
    _ -> None
  }
}

fn lookup_direct_array_at(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(List(String))),
  index: Int,
) -> Option(String) {
  case find_leaf(locales, chain, chain, cal_type, field, Some, 0) {
    None -> None
    Some(arr) -> list_at(arr, index)
  }
}

fn pick_width_table(
  w: resource.WidthTable,
  width: String,
) -> Option(resource.CalendarLeaf(Dict(String, String))) {
  case width {
    "wide" -> w.wide
    "abbreviated" -> w.abbreviated
    "narrow" -> w.narrow
    _ -> None
  }
}

fn pick_context_table(
  t: resource.ContextTable,
  context: String,
) -> resource.WidthTable {
  case context {
    "stand-alone" -> t.stand_alone
    _ -> t.format
  }
}

fn lookup_table_value(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.WidthTable)),
  width: String,
  key: String,
) -> Option(String) {
  lookup_table_value_loop(locales, chain, chain, cal_type, field, width, key, 0)
}

fn lookup_table_value_loop(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  full_chain: List(LocaleChainEntry),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.WidthTable)),
  width: String,
  key: String,
  depth: Int,
) -> Option(String) {
  case depth >= 6 {
    True -> None
    False ->
      case chain {
        [] -> None
        [level, ..rest] ->
          case dict.get(locales, level.name) {
            Error(_) ->
              lookup_table_value_loop(
                locales,
                full_chain,
                rest,
                cal_type,
                field,
                width,
                key,
                depth,
              )
            Ok(by_cal) ->
              case dict.get(by_cal, cal_type) {
                Error(_) ->
                  lookup_table_value_loop(
                    locales,
                    full_chain,
                    rest,
                    cal_type,
                    field,
                    width,
                    key,
                    depth,
                  )
                Ok(symbols) ->
                  case field(symbols) {
                    None ->
                      lookup_table_value_loop(
                        locales,
                        full_chain,
                        rest,
                        cal_type,
                        field,
                        width,
                        key,
                        depth,
                      )
                    Some(resource.CalendarAliasTo(target_cal)) ->
                      lookup_table_value_loop(
                        locales,
                        full_chain,
                        full_chain,
                        target_cal,
                        field,
                        width,
                        key,
                        depth + 1,
                      )
                    Some(resource.CalendarValue(table)) ->
                      case pick_width_table(table, width) {
                        None ->
                          lookup_table_value_loop(
                            locales,
                            full_chain,
                            rest,
                            cal_type,
                            field,
                            width,
                            key,
                            depth,
                          )
                        Some(resource.CalendarLeafValue(values)) ->
                          case dict.get(values, key) {
                            Ok(value) -> Some(value)
                            Error(_) ->
                              lookup_table_value_loop(
                                locales,
                                full_chain,
                                rest,
                                cal_type,
                                field,
                                width,
                                key,
                                depth,
                              )
                          }
                        Some(resource.CalendarLeafAliasTo(target)) ->
                          case parse_table_leaf_alias(target) {
                            None -> None
                            Some(#(target_cal, target_width)) ->
                              lookup_table_value_loop(
                                locales,
                                full_chain,
                                full_chain,
                                target_cal,
                                field,
                                target_width,
                                key,
                                depth + 1,
                              )
                          }
                      }
                  }
              }
          }
      }
  }
}

fn parse_table_leaf_alias(target: String) -> Option(#(String, String)) {
  case string.split(target, "/") {
    ["", "LOCALE", "calendar", cal, _, width] -> Some(#(cal, width))
    _ -> None
  }
}

fn lookup_day_period_value(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextTable)),
  context: String,
  width: String,
  key: String,
) -> Option(String) {
  lookup_day_period_value_loop(
    locales,
    chain,
    cal_type,
    field,
    context,
    width,
    key,
    0,
  )
}

fn lookup_day_period_value_loop(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextTable)),
  context: String,
  width: String,
  key: String,
  depth: Int,
) -> Option(String) {
  case depth >= 6 {
    True -> None
    False ->
      case
        find_leaf(
          locales,
          chain,
          chain,
          cal_type,
          field,
          fn(t) { pick_width_table(pick_context_table(t, context), width) },
          depth,
        )
      {
        None -> None
        Some(resource.CalendarLeafValue(table)) ->
          option.from_result(dict.get(table, key))
        Some(resource.CalendarLeafAliasTo(target)) ->
          case parse_names_leaf_alias(target) {
            None -> None
            Some(#(target_cal, target_context, target_width)) ->
              lookup_day_period_value_loop(
                locales,
                chain,
                target_cal,
                field,
                target_context,
                target_width,
                key,
                depth + 1,
              )
          }
      }
  }
}

fn pick_month_pattern_width(
  w: resource.MonthPatternWidths,
  width: String,
) -> Option(resource.CalendarLeaf(String)) {
  case width {
    "wide" -> w.wide
    "abbreviated" -> w.abbreviated
    "narrow" -> w.narrow
    _ -> None
  }
}

fn extract_month_pattern_leaf(
  mp: resource.MonthPatternsData,
  context: String,
  width: String,
) -> Option(resource.CalendarLeaf(String)) {
  case context {
    "numeric" -> mp.numeric
    "stand-alone" -> pick_month_pattern_width(mp.stand_alone, width)
    _ -> pick_month_pattern_width(mp.format, width)
  }
}

fn lookup_month_pattern(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  lookup_month_pattern_loop(locales, chain, cal_type, context, width, 0)
}

fn lookup_month_pattern_loop(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  depth: Int,
) -> Option(String) {
  case depth >= 6 {
    True -> None
    False ->
      case
        find_leaf(
          locales,
          chain,
          chain,
          cal_type,
          fn(cs) { cs.month_patterns },
          fn(mp) { extract_month_pattern_leaf(mp, context, width) },
          depth,
        )
      {
        None -> None
        Some(resource.CalendarLeafValue(value)) -> Some(value)
        Some(resource.CalendarLeafAliasTo(target)) ->
          case parse_month_pattern_leaf_alias(target) {
            None -> None
            Some(#(target_cal, target_context, target_width)) ->
              lookup_month_pattern_loop(
                locales,
                chain,
                target_cal,
                target_context,
                target_width,
                depth + 1,
              )
          }
      }
  }
}

fn parse_month_pattern_leaf_alias(
  target: String,
) -> Option(#(String, String, String)) {
  case string.split(target, "/") {
    ["", "LOCALE", "calendar", cal, _, context, width] ->
      Some(#(cal, context, width))
    ["", "LOCALE", "calendar", cal, _, "numeric", "all", "leap"] ->
      Some(#(cal, "numeric", "all"))
    _ -> None
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
  uncached_get_month_name(bundle, chain, cal_type, context, width, month)
}

pub fn get_day_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  dow: Int,
) -> Option(String) {
  uncached_get_day_name(bundle, chain, cal_type, context, width, dow)
}

pub fn get_quarter_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  quarter: Int,
) -> Option(String) {
  uncached_get_quarter_name(bundle, chain, cal_type, context, width, quarter)
}

pub fn get_era_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  width: String,
  era: Int,
) -> Option(String) {
  uncached_get_era_name(bundle, chain, cal_type, width, era)
}

pub fn get_am_pm(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type_in: String,
  width: String,
  am_pm: Int,
) -> Option(String) {
  uncached_get_am_pm(bundle, chain, cal_type_in, width, am_pm)
}

pub fn get_day_period_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  period_name: String,
) -> Option(String) {
  uncached_get_day_period_name(
    bundle,
    chain,
    cal_type,
    context,
    width,
    period_name,
  )
}

pub fn get_cyclic_year_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  year_of_cycle: Int,
) -> Option(String) {
  uncached_get_cyclic_year_name(bundle, chain, cal_type, year_of_cycle)
}

pub fn get_leap_month_pattern(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  uncached_get_leap_month_pattern(bundle, chain, cal_type, context, width)
}

fn uncached_get_month_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
  month: Int,
) -> Option(String) {
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal = text_cal_type(cal_type)
  let field = fn(cs: resource.CalendarSymbols) { cs.month_names }
  case width == "wide" || width == "abbreviated" {
    True -> {
      let own = case
        { cal == "chinese" || cal == "dangi" } && width == "abbreviated"
      {
        True ->
          case local_chinese_month(locales, chain, cal, field, context, month) {
            Some(value) -> Some(value)
            None ->
              lookup_array_at(locales, chain, cal, field, context, width, month)
          }
        False ->
          lookup_array_at(locales, chain, cal, field, context, width, month)
      }
      case own {
        Some(value) -> Some(value)
        None ->
          case context == "stand-alone" {
            True ->
              lookup_array_at(
                locales,
                chain,
                cal,
                field,
                "format",
                width,
                month,
              )
            False -> None
          }
      }
    }
    False -> {
      let from_narrow = case context == "format" {
        True ->
          case
            lookup_array_at(
              locales,
              chain,
              cal,
              field,
              "format",
              "narrow",
              month,
            )
          {
            Some(value) -> Some(value)
            None ->
              lookup_array_at(
                locales,
                chain,
                cal,
                field,
                "stand-alone",
                "narrow",
                month,
              )
          }
        False ->
          case
            lookup_array_at(
              locales,
              chain,
              cal,
              field,
              "stand-alone",
              "narrow",
              month,
            )
          {
            Some(value) -> Some(value)
            None ->
              lookup_array_at(
                locales,
                chain,
                cal,
                field,
                "format",
                "narrow",
                month,
              )
          }
      }
      case from_narrow {
        Some(value) -> Some(value)
        None ->
          lookup_array_at(
            locales,
            chain,
            cal,
            field,
            "format",
            "abbreviated",
            month,
          )
      }
    }
  }
}

fn local_chinese_month(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextNames)),
  context: String,
  month: Int,
) -> Option(String) {
  case chain {
    [] -> None
    [level, ..rest] ->
      case level_real_context_names(locales, level.name, cal, field) {
        Some(names) -> {
          let widths = pick_context_names(names, context)
          case real_leaf_at(pick_width_names(widths, "abbreviated"), month) {
            Some(value) -> Some(value)
            None -> real_leaf_at(pick_width_names(widths, "wide"), month)
          }
        }
        None -> local_chinese_month(locales, rest, cal, field, context, month)
      }
  }
}

fn level_real_context_names(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  name: String,
  cal: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextNames)),
) -> Option(resource.ContextNames) {
  case dict.get(locales, name) {
    Error(_) -> None
    Ok(by_cal) ->
      case dict.get(by_cal, cal) {
        Error(_) -> None
        Ok(symbols) ->
          case field(symbols) {
            Some(resource.CalendarValue(names)) -> Some(names)
            _ -> None
          }
      }
  }
}

fn real_leaf_at(
  leaf: Option(resource.CalendarLeaf(List(String))),
  index: Int,
) -> Option(String) {
  case leaf {
    Some(resource.CalendarLeafValue(arr)) -> list_at(arr, index)
    _ -> None
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
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal = text_cal_type(cal_type)
  let field = fn(cs: resource.CalendarSymbols) { cs.day_names }
  let index = dow - 1
  case width == "wide" || width == "abbreviated" {
    True ->
      case
        local_calendar_array(locales, chain, cal, field, context, width, index)
      {
        Some(value) -> Some(value)
        None -> {
          let own =
            lookup_array_at(locales, chain, cal, field, context, width, index)
          case own {
            Some(value) -> Some(value)
            None ->
              case context == "stand-alone" {
                True ->
                  lookup_array_at(
                    locales,
                    chain,
                    cal,
                    field,
                    "format",
                    width,
                    index,
                  )
                False -> None
              }
          }
        }
      }
    False ->
      case width == "short" {
        True -> {
          let own =
            lookup_array_at(locales, chain, cal, field, context, "short", index)
          case own {
            Some(value) -> Some(value)
            None ->
              case context == "stand-alone" {
                True ->
                  case
                    lookup_array_at(
                      locales,
                      chain,
                      cal,
                      field,
                      "format",
                      "short",
                      index,
                    )
                  {
                    Some(value) -> Some(value)
                    None ->
                      lookup_array_at(
                        locales,
                        chain,
                        cal,
                        field,
                        "format",
                        "abbreviated",
                        index,
                      )
                  }
                False -> None
              }
          }
        }
        False -> {
          let from_narrow = case context == "format" {
            True ->
              case
                lookup_array_at(
                  locales,
                  chain,
                  cal,
                  field,
                  "format",
                  "narrow",
                  index,
                )
              {
                Some(value) -> Some(value)
                None ->
                  lookup_array_at(
                    locales,
                    chain,
                    cal,
                    field,
                    "stand-alone",
                    "narrow",
                    index,
                  )
              }
            False ->
              case
                lookup_array_at(
                  locales,
                  chain,
                  cal,
                  field,
                  "stand-alone",
                  "narrow",
                  index,
                )
              {
                Some(value) -> Some(value)
                None ->
                  lookup_array_at(
                    locales,
                    chain,
                    cal,
                    field,
                    "format",
                    "narrow",
                    index,
                  )
              }
          }
          case from_narrow {
            Some(value) -> Some(value)
            None ->
              lookup_array_at(
                locales,
                chain,
                cal,
                field,
                "format",
                "abbreviated",
                index,
              )
          }
        }
      }
  }
}

fn local_calendar_array(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal: String,
  field: fn(resource.CalendarSymbols) ->
    Option(resource.CalendarField(resource.ContextNames)),
  context: String,
  width: String,
  index: Int,
) -> Option(String) {
  case find_leaf(locales, chain, chain, cal, field, Some, 0) {
    None -> None
    Some(names) ->
      case
        real_leaf_at(
          pick_width_names(pick_context_names(names, context), width),
          index,
        )
      {
        Some(value) -> Some(value)
        None ->
          case context == "stand-alone" {
            True ->
              real_leaf_at(
                pick_width_names(pick_context_names(names, "format"), width),
                index,
              )
            False -> None
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
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal = text_cal_type(cal_type)
  let field = fn(cs: resource.CalendarSymbols) { cs.quarters }
  case width == "narrow" {
    True ->
      case context == "stand-alone" {
        True ->
          lookup_array_at(
            locales,
            chain,
            cal,
            field,
            "stand-alone",
            "narrow",
            quarter,
          )
        False ->
          case
            lookup_array_at(
              locales,
              chain,
              cal,
              field,
              "format",
              "narrow",
              quarter,
            )
          {
            Some(value) -> Some(value)
            None ->
              lookup_array_at(
                locales,
                chain,
                cal,
                field,
                "stand-alone",
                "narrow",
                quarter,
              )
          }
      }
    False -> {
      let own =
        lookup_array_at(locales, chain, cal, field, context, width, quarter)
      case own {
        Some(value) -> Some(value)
        None ->
          case width == "abbreviated" {
            True ->
              case context == "stand-alone" {
                True ->
                  case
                    lookup_array_at(
                      locales,
                      chain,
                      cal,
                      field,
                      "format",
                      "abbreviated",
                      quarter,
                    )
                  {
                    Some(value) -> Some(value)
                    None ->
                      lookup_array_at(
                        locales,
                        chain,
                        cal,
                        field,
                        "format",
                        "wide",
                        quarter,
                      )
                  }
                False ->
                  lookup_array_at(
                    locales,
                    chain,
                    cal,
                    field,
                    "format",
                    "wide",
                    quarter,
                  )
              }
            False ->
              case context == "stand-alone" {
                True ->
                  lookup_array_at(
                    locales,
                    chain,
                    cal,
                    field,
                    "format",
                    "wide",
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
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal = text_cal_type(cal_type)
  let field = fn(cs: resource.CalendarSymbols) { cs.eras }
  case
    lookup_table_value(locales, chain, cal, field, width, int.to_string(era))
  {
    Some(own) -> Some(own)
    None ->
      case width == "abbreviated" {
        True -> None
        False ->
          lookup_table_value(
            locales,
            chain,
            cal,
            field,
            "abbreviated",
            int.to_string(era),
          )
      }
  }
}

fn get_am_pm_at(
  locales: Dict(String, Dict(String, resource.CalendarSymbols)),
  chain: List(LocaleChainEntry),
  cal_type: String,
  key: String,
  am_pm: Int,
) -> Option(String) {
  let field = case key {
    "AmPmMarkersNarrow" -> fn(cs: resource.CalendarSymbols) {
      cs.am_pm_markers_narrow
    }
    "AmPmMarkers" -> fn(cs: resource.CalendarSymbols) { cs.am_pm_markers }
    _ -> fn(cs: resource.CalendarSymbols) { cs.am_pm_markers_abbr }
  }
  let own = lookup_direct_array_at(locales, chain, cal_type, field, am_pm)
  case own {
    Some(_) -> own
    None ->
      case cal_type == "gregorian" {
        True -> None
        False ->
          lookup_direct_array_at(locales, chain, "gregorian", field, am_pm)
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
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal_type = text_cal_type(cal_type_in)
  let from_width = case width == "narrow" {
    True -> get_am_pm_at(locales, chain, cal_type, "AmPmMarkersNarrow", am_pm)
    False ->
      case width == "wide" {
        True -> get_am_pm_at(locales, chain, cal_type, "AmPmMarkers", am_pm)
        False -> None
      }
  }
  case from_width {
    Some(v) -> Some(v)
    None -> get_am_pm_at(locales, chain, cal_type, "AmPmMarkersAbbr", am_pm)
  }
}

fn uncached_get_day_period_name(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type_in: String,
  context: String,
  width: String,
  period_name: String,
) -> Option(String) {
  let locales = bundle.calendar_symbols_by_locale.locales
  let cal = text_cal_type(cal_type_in)
  let field = fn(cs: resource.CalendarSymbols) { cs.day_period }
  let lookup_calendar = fn(width) {
    lookup_day_period_value(
      locales,
      chain,
      cal,
      field,
      context,
      width,
      period_name,
    )
  }
  let lookup_with_gregorian_fallback = fn(width) {
    case lookup_calendar(width) {
      Some(found) -> Some(found)
      None ->
        case cal == "gregorian" {
          True -> None
          False ->
            lookup_day_period_value(
              locales,
              chain,
              "gregorian",
              field,
              context,
              width,
              period_name,
            )
        }
    }
  }
  case lookup_with_gregorian_fallback(width) {
    Some(found) -> Some(found)
    None ->
      case width == "wide" || width == "narrow" {
        True -> lookup_with_gregorian_fallback("abbreviated")
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
  let locales = bundle.calendar_symbols_by_locale.locales
  lookup_direct_array_at(
    locales,
    chain,
    cal_type,
    fn(cs) { cs.cyclic_years_abbreviated },
    year_of_cycle - 1,
  )
}

fn uncached_get_leap_month_pattern(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  cal_type: String,
  context: String,
  width: String,
) -> Option(String) {
  let locales = bundle.calendar_symbols_by_locale.locales
  case width == "numeric" {
    True -> lookup_month_pattern(locales, chain, cal_type, "numeric", "all")
    False -> {
      let format_wide =
        lookup_month_pattern(locales, chain, cal_type, "format", "wide")
      let standalone_narrow =
        lookup_month_pattern(locales, chain, cal_type, "stand-alone", "narrow")
      let format_abbrev_own =
        lookup_month_pattern(locales, chain, cal_type, "format", "abbreviated")
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
                lookup_month_pattern(
                  locales,
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
                lookup_month_pattern(
                  locales,
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
                lookup_month_pattern(
                  locales,
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
