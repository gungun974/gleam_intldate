import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/loader
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource

pub const root_locale_name = "root"

pub type LocaleChainEntry {
  LocaleChainEntry(name: String)
}

pub type Bundle {
  Bundle(
    pattern_generators: resource.PatternGenerators,
    zone_info_64: resource.ZoneInfo64,
    supplemental_data: resource.SupplementalData,
    plurals: resource.Plurals,
    numbering_systems: resource.NumberingSystems,
    timezone_types: resource.TimezoneTypes,
    day_period_rules: resource.DayPeriodRulesData,
    likely_subtags: resource.LikelySubtagsData,
    loc_ext_key_map: resource.LocExtKeyMap,
    locale_parents: resource.LocaleParents,
    available_locales: dict.Dict(String, Nil),
    number_elements_by_locale: resource.NumberElementsByLocale,
    number_system_data_by_locale: resource.NumberSystemDataByLocale,
    meta_zones: resource.MetaZonesData,
    zone_strings_by_locale: resource.ZoneStringsByLocale,
    region_names_by_locale: resource.RegionNamesByLocale,
    calendar_symbols_by_locale: resource.CalendarSymbolsByLocale,
    date_interval_data_by_locale: resource.DateIntervalDataByLocale,
    relative_fields_by_locale: resource.RelativeFieldsByLocale,
  )
}

const cache_key = "bundle"

const locale_cache_prefix = "locale:"

type LocaleMaps {
  LocaleMaps(
    number_elements: dict.Dict(String, dict.Dict(String, String)),
    number_system_data: dict.Dict(
      String,
      dict.Dict(String, resource.NumberSystemSymbols),
    ),
    zone_strings: dict.Dict(String, resource.ZoneStringsLocale),
    region_names: dict.Dict(String, dict.Dict(String, String)),
    calendar_symbols: dict.Dict(
      String,
      dict.Dict(String, resource.CalendarSymbols),
    ),
    date_interval_data: dict.Dict(
      String,
      dict.Dict(String, resource.DateIntervalCalendarData),
    ),
    relative_fields: dict.Dict(
      String,
      dict.Dict(String, resource.RelativeField),
    ),
  )
}

// The global generated data is immutable at runtime. Locale data is cached
// separately so a process using fr_FR only retains fr_FR, fr and root.
pub fn create_bundle() -> Result(Bundle, loader.LoadError) {
  case cache.get_persistent_term(cache_key) {
    Ok(bundle) -> Ok(bundle)
    Error(_) -> {
      use bundle <- result.try(create_uncached_bundle())
      Ok(cache.put_persistent_term(cache_key, bundle))
    }
  }
}

fn create_uncached_bundle() -> Result(Bundle, loader.LoadError) {
  use pattern_generators <- result.try(loader.load_pattern_generators())
  create_global_bundle(pattern_generators)
}

pub fn create_generation_bundle(
  zone_info_64 zone_info_64: resource.ZoneInfo64,
  supplemental_data supplemental_data: resource.SupplementalData,
  plurals plurals: resource.Plurals,
  numbering_systems numbering_systems: resource.NumberingSystems,
  timezone_types timezone_types: resource.TimezoneTypes,
  day_period_rules day_period_rules: resource.DayPeriodRulesData,
  likely_subtags likely_subtags: resource.LikelySubtagsData,
  loc_ext_key_map loc_ext_key_map: resource.LocExtKeyMap,
  locale_parents locale_parents: resource.LocaleParents,
  number_elements_by_locale number_elements_by_locale: resource.NumberElementsByLocale,
  number_system_data_by_locale number_system_data_by_locale: resource.NumberSystemDataByLocale,
  meta_zones meta_zones: resource.MetaZonesData,
  zone_strings_by_locale zone_strings_by_locale: resource.ZoneStringsByLocale,
  region_names_by_locale region_names_by_locale: resource.RegionNamesByLocale,
  calendar_symbols_by_locale calendar_symbols_by_locale: resource.CalendarSymbolsByLocale,
  date_interval_data_by_locale date_interval_data_by_locale: resource.DateIntervalDataByLocale,
  relative_fields_by_locale relative_fields_by_locale: resource.RelativeFieldsByLocale,
) -> Bundle {
  let available_locales =
    list.fold(locale_parents.installed_locales, dict.new(), fn(locales, name) {
      dict.insert(locales, name, Nil)
    })
  Bundle(
    pattern_generators: resource.PatternGenerators(
      locale_to_generator: dict.new(),
      generators: dict.new(),
    ),
    zone_info_64:,
    supplemental_data:,
    plurals:,
    numbering_systems:,
    timezone_types:,
    day_period_rules:,
    likely_subtags:,
    loc_ext_key_map:,
    locale_parents:,
    available_locales:,
    number_elements_by_locale:,
    number_system_data_by_locale:,
    meta_zones:,
    zone_strings_by_locale:,
    region_names_by_locale:,
    calendar_symbols_by_locale:,
    date_interval_data_by_locale:,
    relative_fields_by_locale:,
  )
}

fn create_global_bundle(
  pattern_generators: resource.PatternGenerators,
) -> Result(Bundle, loader.LoadError) {
  use locale_parents <- result.try(loader.load_locale_parents())
  use zone_info_64 <- result.try(loader.load_zone_info_64())
  use supplemental_data <- result.try(loader.load_supplemental_data())
  use plurals <- result.try(loader.load_plurals())
  use numbering_systems <- result.try(loader.load_numbering_systems())
  use timezone_types <- result.try(loader.load_timezone_types())
  use day_period_rules <- result.try(loader.load_day_period_rules_data())
  use likely_subtags <- result.try(loader.load_likely_subtags_data())
  use loc_ext_key_map <- result.try(loader.load_loc_ext_key_map())
  use meta_zones <- result.try(loader.load_meta_zones_data())
  let available_locales =
    list.fold(locale_parents.installed_locales, dict.new(), fn(locales, name) {
      dict.insert(locales, name, Nil)
    })
  Ok(Bundle(
    pattern_generators:,
    zone_info_64:,
    supplemental_data:,
    plurals:,
    numbering_systems:,
    timezone_types:,
    day_period_rules:,
    likely_subtags:,
    loc_ext_key_map:,
    locale_parents:,
    available_locales:,
    number_elements_by_locale: resource.NumberElementsByLocale(dict.new()),
    number_system_data_by_locale: resource.NumberSystemDataByLocale(dict.new()),
    meta_zones:,
    zone_strings_by_locale: resource.ZoneStringsByLocale(dict.new()),
    region_names_by_locale: resource.RegionNamesByLocale(dict.new()),
    calendar_symbols_by_locale: resource.CalendarSymbolsByLocale(dict.new()),
    date_interval_data_by_locale: resource.DateIntervalDataByLocale(dict.new()),
    relative_fields_by_locale: resource.RelativeFieldsByLocale(dict.new()),
  ))
}

fn insert_optional(
  values: dict.Dict(String, a),
  name: String,
  value: Option(a),
) -> dict.Dict(String, a) {
  case value {
    Some(value) -> dict.insert(values, name, value)
    None -> values
  }
}

fn add_locale(
  maps: LocaleMaps,
  name: String,
) -> Result(LocaleMaps, loader.LoadError) {
  use data <- result.try(loader.load_locale_data(name))
  Ok(LocaleMaps(
    number_elements: insert_optional(
      maps.number_elements,
      name,
      data.number_elements,
    ),
    number_system_data: insert_optional(
      maps.number_system_data,
      name,
      data.number_system_data,
    ),
    zone_strings: insert_optional(maps.zone_strings, name, data.zone_strings),
    region_names: insert_optional(maps.region_names, name, data.region_names),
    calendar_symbols: insert_optional(
      maps.calendar_symbols,
      name,
      data.calendar_symbols,
    ),
    date_interval_data: insert_optional(
      maps.date_interval_data,
      name,
      data.date_interval_data,
    ),
    relative_fields: insert_optional(
      maps.relative_fields,
      name,
      data.relative_fields,
    ),
  ))
}

fn locale_base(name: String) -> String {
  case string.split_once(name, "@") {
    Ok(#(base, _)) -> base
    Error(_) -> name
  }
}

/// Attach only the exact locale and its ICU fallback chain to a global bundle.
/// Each exact locale shard has its own append-only ets entry.
pub fn for_locale(
  bundle: Bundle,
  name: String,
) -> Result(Bundle, loader.LoadError) {
  let base_name = locale_base(name)
  let key = locale_cache_prefix <> base_name
  use maps <- result.try(case cache.get_ets(key) {
    Ok(maps) -> Ok(maps)
    Error(_) -> {
      use maps <- result.try(load_locale_maps(bundle, base_name))
      Ok(cache.put_ets(key, maps))
    }
  })

  Ok(
    Bundle(
      ..bundle,
      number_elements_by_locale: resource.NumberElementsByLocale(
        maps.number_elements,
      ),
      number_system_data_by_locale: resource.NumberSystemDataByLocale(
        maps.number_system_data,
      ),
      zone_strings_by_locale: resource.ZoneStringsByLocale(maps.zone_strings),
      region_names_by_locale: resource.RegionNamesByLocale(maps.region_names),
      calendar_symbols_by_locale: resource.CalendarSymbolsByLocale(
        maps.calendar_symbols,
      ),
      date_interval_data_by_locale: resource.DateIntervalDataByLocale(
        maps.date_interval_data,
      ),
      relative_fields_by_locale: resource.RelativeFieldsByLocale(
        maps.relative_fields,
      ),
    ),
  )
}

fn load_locale_maps(
  bundle: Bundle,
  base_name: String,
) -> Result(LocaleMaps, loader.LoadError) {
  localechain.locale_chain(bundle.locale_parents, base_name)
  |> list.filter(fn(name) { dict.has_key(bundle.available_locales, name) })
  |> list.try_fold(
    LocaleMaps(
      number_elements: dict.new(),
      number_system_data: dict.new(),
      zone_strings: dict.new(),
      region_names: dict.new(),
      calendar_symbols: dict.new(),
      date_interval_data: dict.new(),
      relative_fields: dict.new(),
    ),
    add_locale,
  )
}

pub fn chop_locale(name: String) -> Option(String) {
  case string.contains(name, "_") {
    False ->
      case name == root_locale_name {
        True -> None
        False -> Some(root_locale_name)
      }
    True -> {
      let parts = string.split(name, "_")
      case list.reverse(parts) {
        [_last, ..rest] -> Some(string.join(list.reverse(rest), "_"))
        [] -> None
      }
    }
  }
}

pub fn open_locale_chain(
  bundle: Bundle,
  name: String,
) -> List(LocaleChainEntry) {
  localechain.locale_chain(bundle.locale_parents, name)
  |> list.map(LocaleChainEntry)
}
