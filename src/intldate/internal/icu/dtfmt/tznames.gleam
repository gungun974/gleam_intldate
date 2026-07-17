import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/calendar/timezone
import intldate/internal/icu/icudata/bundle.{type Bundle, scoped_zone_strings}
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource.{type MetazoneMapping}
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/zonemeta

pub type ZoneChainEntry {
  ZoneChainEntry(name: String)
}

pub type CanonicalCountryResult {
  CanonicalCountryResult(region: Option(String), is_primary: Bool)
}

pub type MatchInfo {
  MatchInfo(name_type: Int, id: String, match_length: Int, is_tzid: Bool)
}

pub type MatchInfoCollection {
  MatchInfoCollection(matches: Dict(Int, MatchInfo), size: Int)
}

pub type SearchIndexEntry {
  SearchIndexEntry(
    name: String,
    type_: Int,
    tzid: Option(String),
    mzid: Option(String),
  )
}

pub type TimeZoneNamesImpl {
  TimeZoneNamesImpl(
    bundle: Bundle,
    locale_id: String,
    zone_chain: List(ZoneChainEntry),
  )
}

pub type UErrorCodeStatus {
  UErrorCodeStatus(code: Option(String))
}

fn zonemeta_bundle(bundle: Bundle) -> Bundle {
  bundle
}

fn build_likely_subtags_state(
  bundle: Bundle,
) -> Option(loclikelysubtags.LikelySubtagsState) {
  case loclikelysubtags.create_likely_subtags(bundle) {
    Ok(state) -> Some(state)
    Error(_) -> None
  }
}

pub fn get_target_region(bundle: Bundle, locale_id: String) -> String {
  let region = uloc.get_region(Some(locale_id))
  case region {
    "" -> {
      let language = case uloc.get_language(Some(locale_id)) {
        "" -> "und"
        l -> l
      }
      let script = uloc.get_script(Some(locale_id))
      case build_likely_subtags_state(bundle) {
        None -> ""
        Some(state) ->
          loclikelysubtags.maximize(state, language, script, "", False).region
      }
    }
    _ -> region
  }
}

pub fn to_colon_key(id: String) -> String {
  string.replace(id, "/", ":")
}

fn build_zone_chain_entries(
  bundle: Bundle,
  locale_id: String,
) -> List(ZoneChainEntry) {
  localechain.locale_chain(
    bundle.locale_parents,
    uloc.get_base_name(Some(locale_id)),
  )
  |> list.map(ZoneChainEntry)
}

pub fn get_zone_strings_chain(
  bundle: Bundle,
  locale_id: String,
) -> List(ZoneChainEntry) {
  build_zone_chain_entries(bundle, locale_id)
}

pub fn get_region_chain(
  bundle: Bundle,
  locale_id: String,
) -> List(ZoneChainEntry) {
  build_zone_chain_entries(bundle, locale_id)
}

const no_inheritance_marker = "\u{2205}\u{2205}\u{2205}"

fn lookup_name_key(
  table: Dict(String, Dict(String, String)),
  entry_key: String,
  name_key: String,
) -> Result(Option(String), Nil) {
  case dict.get(table, entry_key) {
    Error(_) -> Error(Nil)
    Ok(sub) ->
      case dict.get(sub, name_key) {
        Error(_) -> Error(Nil)
        Ok(value) if value == no_inheritance_marker -> Ok(None)
        Ok(value) -> Ok(Some(value))
      }
  }
}

fn find_zone_strings_entry(
  locales: Dict(String, resource.ZoneStringsLocale),
  zone_chain: List(ZoneChainEntry),
  get_table: fn(resource.ZoneStringsLocale) ->
    Dict(String, Dict(String, String)),
  entry_key: String,
  name_key: String,
) -> Option(String) {
  case zone_chain {
    [] -> None
    [level, ..rest] ->
      case dict.get(locales, level.name) {
        Error(_) ->
          find_zone_strings_entry(locales, rest, get_table, entry_key, name_key)
        Ok(zs) ->
          case lookup_name_key(get_table(zs), entry_key, name_key) {
            Ok(result) -> result
            Error(_) ->
              find_zone_strings_entry(
                locales,
                rest,
                get_table,
                entry_key,
                name_key,
              )
          }
      }
  }
}

pub fn get_zone_name(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  tzid: String,
  name_key: String,
) -> Option(String) {
  let data = scoped_zone_strings(bundle)
  find_zone_strings_entry(
    data.locales,
    zone_chain,
    fn(zs) { zs.zones },
    to_colon_key(tzid),
    name_key,
  )
}

pub fn get_metazone_name(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  mzid: String,
  name_key: String,
) -> Option(String) {
  let data = scoped_zone_strings(bundle)
  find_zone_strings_entry(
    data.locales,
    zone_chain,
    fn(zs) { zs.metazones },
    mzid,
    name_key,
  )
}

pub fn get_zone_strings_global(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  key: String,
) -> Option(String) {
  let data = scoped_zone_strings(bundle)
  find_zone_strings_global(data.locales, zone_chain, key)
}

fn find_zone_strings_global(
  locales: Dict(String, resource.ZoneStringsLocale),
  zone_chain: List(ZoneChainEntry),
  key: String,
) -> Option(String) {
  case zone_chain {
    [] -> None
    [level, ..rest] ->
      case dict.get(locales, level.name) {
        Error(_) -> find_zone_strings_global(locales, rest, key)
        Ok(zs) ->
          case dict.get(zs.globals, key) {
            Error(_) -> find_zone_strings_global(locales, rest, key)
            Ok(value) if value == no_inheritance_marker -> None
            Ok(value) -> Some(value)
          }
      }
  }
}

pub fn get_default_exemplar_location_name(tzid: String) -> Option(String) {
  case
    tzid == ""
    || string.starts_with(tzid, "Etc/")
    || string.starts_with(tzid, "SystemV/")
    || string.contains(tzid, "Riyadh8")
  {
    True -> None
    False ->
      case last_index_of(tzid, "/") {
        sep if sep > 0 ->
          Some(string.replace(string.drop_start(tzid, sep + 1), "_", " "))
        _ -> None
      }
  }
}

fn last_index_of(s: String, sub: String) -> Int {
  last_index_of_loop(s, sub, 0, -1)
}

fn last_index_of_loop(s: String, sub: String, offset: Int, best: Int) -> Int {
  case string.length(s) < string.length(sub) {
    True -> best
    False -> {
      let matches = string.slice(s, 0, string.length(sub)) == sub
      let best = case matches {
        True -> offset
        False -> best
      }
      last_index_of_loop(string.drop_start(s, 1), sub, offset + 1, best)
    }
  }
}

pub fn get_exemplar_city(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  tzid: String,
) -> Option(String) {
  case get_zone_name(bundle, zone_chain, tzid, "ec") {
    Some(v) -> Some(v)
    None -> get_default_exemplar_location_name(tzid)
  }
}

pub fn get_metazone_mappings(
  bundle: Bundle,
  tzid: String,
) -> List(MetazoneMapping) {
  let data = bundle.meta_zones
  case dict.get(data.metazone_info, to_colon_key(tzid)) {
    Ok(mappings) -> mappings
    Error(_) -> []
  }
}

pub fn get_metazone_at(
  bundle: Bundle,
  tzid: String,
  epoch_millis: Int,
) -> Option(String) {
  find_metazone_at(get_metazone_mappings(bundle, tzid), epoch_millis)
}

fn find_metazone_at(
  mappings: List(MetazoneMapping),
  epoch_millis: Int,
) -> Option(String) {
  case mappings {
    [] -> None
    [m, ..rest] ->
      case epoch_millis >= m.from && epoch_millis < m.to {
        True -> Some(m.name)
        False -> find_metazone_at(rest, epoch_millis)
      }
  }
}

pub fn get_reference_zone_id(
  bundle: Bundle,
  mzid: String,
  region: String,
) -> Option(String) {
  let data = bundle.meta_zones
  case dict.get(data.map_timezones, mzid) {
    Error(_) -> None
    Ok(by_region) ->
      case dict.get(by_region, region) {
        Ok(v) -> Some(v)
        Error(_) ->
          case dict.get(by_region, "001") {
            Ok(v) -> Some(v)
            Error(_) -> None
          }
      }
  }
}

pub fn get_primary_zone_for_region(
  bundle: Bundle,
  region: String,
) -> Option(String) {
  let data = bundle.meta_zones
  case dict.get(data.primary_zones, region) {
    Ok(v) -> Some(v)
    Error(_) -> None
  }
}

fn is_single_zone_country(bundle: Bundle, region: String) -> Bool {
  dict.has_key(bundle.timezone_types.single_zone_regions, region)
}

pub fn get_canonical_country(
  bundle: Bundle,
  tzid: String,
) -> CanonicalCountryResult {
  case zonemeta.get_region(zonemeta_bundle(bundle), tzid) {
    None -> CanonicalCountryResult(None, False)
    Some(region) if region == "001" -> CanonicalCountryResult(None, False)
    Some(region) ->
      case is_single_zone_country(bundle, region) {
        True -> CanonicalCountryResult(Some(region), True)
        False -> {
          let primary_zone = get_primary_zone_for_region(bundle, region)
          let canonical =
            zonemeta.get_canonical_cldr_id(
              zonemeta_bundle(bundle),
              zonemeta.new_canonical_id_cache(),
              Some(tzid),
            ).0
          let is_primary = case primary_zone {
            None -> False
            Some(pz) -> Some(pz) == Some(tzid) || Some(pz) == canonical
          }
          CanonicalCountryResult(Some(region), is_primary)
        }
      }
  }
}

pub fn get_region_display_name(
  bundle: Bundle,
  locale_id: String,
  region: String,
) -> String {
  find_region_display_name(bundle, get_region_chain(bundle, locale_id), region)
}

fn find_region_display_name(
  bundle: Bundle,
  chain: List(ZoneChainEntry),
  region: String,
) -> String {
  let data = bundle.region_names_by_locale
  find_region_display_name_loop(data.locales, chain, region)
}

fn find_region_display_name_loop(
  locales: Dict(String, Dict(String, String)),
  chain: List(ZoneChainEntry),
  region: String,
) -> String {
  case chain {
    [] -> region
    [level, ..rest] ->
      case dict.get(locales, level.name) {
        Error(_) -> find_region_display_name_loop(locales, rest, region)
        Ok(countries) ->
          case dict.get(countries, region) {
            Error(_) -> find_region_display_name_loop(locales, rest, region)
            Ok(value) if value == no_inheritance_marker -> region
            Ok(value) -> value
          }
      }
  }
}

pub fn get_generic_location_name(
  bundle: Bundle,
  locale_id: String,
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
) -> Option(String) {
  let country_result = get_canonical_country(bundle, canonical_tzid)
  case country_result.region {
    None -> None
    Some(region) -> {
      let location = case country_result.is_primary {
        True -> Some(get_region_display_name(bundle, locale_id, region))
        False -> get_exemplar_city(bundle, zone_chain, canonical_tzid)
      }
      case location {
        None -> None
        Some(loc) -> {
          let region_format = case
            get_zone_strings_global(bundle, zone_chain, "regionFormat")
          {
            Some(f) -> f
            None -> "{0}"
          }
          Some(string.replace(region_format, "{0}", loc))
        }
      }
    }
  }
}

pub fn get_specific_name(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
  epoch_millis: Int,
  is_daylight: Bool,
  is_long: Bool,
) -> Option(String) {
  let key = case is_daylight {
    True ->
      case is_long {
        True -> "ld"
        False -> "sd"
      }
    False ->
      case is_long {
        True -> "ls"
        False -> "ss"
      }
  }
  case get_zone_name(bundle, zone_chain, canonical_tzid, key) {
    Some(v) -> Some(v)
    None ->
      case get_metazone_at(bundle, canonical_tzid, epoch_millis) {
        None -> None
        Some(mzid) -> get_metazone_name(bundle, zone_chain, mzid, key)
      }
  }
}

const dst_check_range_ms = 15_897_600_000

pub fn has_nearby_dst(
  bundle: Bundle,
  canonical_tzid: String,
  epoch_millis: Int,
) -> Bool {
  timezone.has_dst_transition_nearby(
    zonemeta_bundle(bundle),
    canonical_tzid,
    epoch_millis,
    dst_check_range_ms,
  )
}

pub fn get_partial_location_name(
  bundle: Bundle,
  locale_id: String,
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
  mzid: String,
  mz_display_name: String,
) -> String {
  let country_result = get_canonical_country(bundle, canonical_tzid)
  let location = case country_result.region {
    Some(region) ->
      case get_reference_zone_id(bundle, mzid, region) {
        Some(regional_golden) if regional_golden == canonical_tzid ->
          Some(get_region_display_name(bundle, locale_id, region))
        _ -> get_exemplar_city(bundle, zone_chain, canonical_tzid)
      }
    None ->
      case get_exemplar_city(bundle, zone_chain, canonical_tzid) {
        Some(city) -> Some(city)
        None -> Some(canonical_tzid)
      }
  }
  let location = option.unwrap(location, "")
  let fallback_format = case
    get_zone_strings_global(bundle, zone_chain, "fallbackFormat")
  {
    Some(f) -> f
    None -> "{1} ({0})"
  }
  fallback_format
  |> string.replace("{1}", mz_display_name)
  |> string.replace("{0}", location)
}

pub fn get_generic_name(
  bundle: Bundle,
  locale_id: String,
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
  epoch_millis: Int,
  raw_offset: Int,
  dst_offset: Int,
  is_long: Bool,
) -> Option(String) {
  let gen_key = case is_long {
    True -> "lg"
    False -> "sg"
  }
  case get_zone_name(bundle, zone_chain, canonical_tzid, gen_key) {
    Some(v) -> Some(v)
    None ->
      case get_metazone_at(bundle, canonical_tzid, epoch_millis) {
        None -> None
        Some(mzid) -> {
          let std_key = case is_long {
            True -> "ls"
            False -> "ss"
          }
          let use_standard =
            dst_offset == 0
            && !has_nearby_dst(bundle, canonical_tzid, epoch_millis)
          let name = case use_standard {
            False -> None
            True ->
              case
                get_standard_name(
                  bundle,
                  zone_chain,
                  canonical_tzid,
                  mzid,
                  std_key,
                )
              {
                None -> None
                Some(std_name) ->
                  case get_metazone_name(bundle, zone_chain, mzid, gen_key) {
                    None -> Some(std_name)
                    Some(mz_generic_name) ->
                      case
                        string.lowercase(std_name)
                        == string.lowercase(mz_generic_name)
                      {
                        True -> None
                        False -> Some(std_name)
                      }
                  }
              }
          }
          case name {
            Some(_) -> name
            None ->
              case get_metazone_name(bundle, zone_chain, mzid, gen_key) {
                None -> None
                Some(mz_name) -> {
                  let region = get_target_region(bundle, locale_id)
                  case get_reference_zone_id(bundle, mzid, region) {
                    Some(golden_id) if golden_id != canonical_tzid -> {
                      let golden_offset =
                        timezone.get_offset_local(
                          zonemeta_bundle(bundle),
                          golden_id,
                          epoch_millis + raw_offset + dst_offset,
                        )
                      case
                        golden_offset.raw_offset != raw_offset
                        || golden_offset.dst_offset != dst_offset
                      {
                        True ->
                          Some(get_partial_location_name(
                            bundle,
                            locale_id,
                            zone_chain,
                            canonical_tzid,
                            mzid,
                            mz_name,
                          ))
                        False -> Some(mz_name)
                      }
                    }
                    _ -> Some(mz_name)
                  }
                }
              }
          }
        }
      }
  }
}

fn get_standard_name(
  bundle: Bundle,
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
  mzid: String,
  std_key: String,
) -> Option(String) {
  case get_zone_name(bundle, zone_chain, canonical_tzid, std_key) {
    Some(v) -> Some(v)
    None -> get_metazone_name(bundle, zone_chain, mzid, std_key)
  }
}
