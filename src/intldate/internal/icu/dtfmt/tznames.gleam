import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/calendar/timezone
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/icudata/uresimp
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/uloc
import intldate/internal/icu/locale/zonemeta

pub type ZoneChainEntry {
  ZoneChainEntry(name: String, res_data: resource.ResourceData)
}

pub type MetazoneMapping {
  MetazoneMapping(name: String, from: Int, to: Int)
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

fn zonemeta_bundle(bundle: Bundle) -> zonemeta.Bundle {
  zonemeta.Bundle(data_path: bundle.data_path, open_direct: fn(name) {
    resbund.open_direct_or_panic(bundle, name)
  })
}

fn adapt_likely_subtags_bundle(bundle: Bundle) -> loclikelysubtags.Bundle {
  loclikelysubtags.Bundle(
    open_direct: fn(name) { resbund.open_direct_or_panic(bundle, name) },
    get_by_path: fn(chain, path) {
      let resbund_chain =
        list.map(chain, fn(entry) {
          resbund.LocaleChainEntry(entry.name, Some(entry.res_data))
        })
      case resbund.get_by_path(bundle, resbund_chain, path, 0) {
        None -> None
        Some(resolved) ->
          Some(loclikelysubtags.MatchLookup(resolved.res_data, resolved.res))
      }
    },
  )
}

fn build_likely_subtags_state(
  bundle: Bundle,
) -> Option(loclikelysubtags.LikelySubtagsState) {
  case
    loclikelysubtags.create_likely_subtags(adapt_likely_subtags_bundle(bundle))
  {
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

fn open_prefixed_chain(
  bundle: Bundle,
  prefix: String,
  locale_id: String,
) -> List(ZoneChainEntry) {
  let chain =
    resbund.open_locale_chain(bundle, uloc.get_base_name(Some(locale_id)))
  open_prefixed_chain_loop(bundle, prefix, chain)
}

fn open_prefixed_chain_loop(
  bundle: Bundle,
  prefix: String,
  chain: List(resbund.LocaleChainEntry),
) -> List(ZoneChainEntry) {
  case chain {
    [] -> []
    [entry, ..rest] ->
      case resbund.open_direct(bundle, prefix <> "/" <> entry.name) {
        None -> open_prefixed_chain_loop(bundle, prefix, rest)
        Some(rd) -> [
          ZoneChainEntry(prefix <> "/" <> entry.name, rd),
          ..open_prefixed_chain_loop(bundle, prefix, rest)
        ]
      }
  }
}

pub fn get_zone_strings_chain(
  bundle: Bundle,
  locale_id: String,
) -> List(ZoneChainEntry) {
  open_prefixed_chain(bundle, "zone", locale_id)
}

pub fn get_region_chain(
  bundle: Bundle,
  locale_id: String,
) -> List(ZoneChainEntry) {
  open_prefixed_chain(bundle, "region", locale_id)
}

const no_inheritance_marker = "\u{2205}\u{2205}\u{2205}"

fn get_table_string(
  rd: resource.ResourceData,
  table: resource.ResourceTableView,
  key: String,
) -> Option(String) {
  get_table_string_loop(rd, table_keys_and_res(table), key)
}

fn get_table_string_loop(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  key: String,
) -> Option(String) {
  case entries {
    [] -> None
    [#(k, res), ..rest] ->
      case k == key {
        True -> Some(resource_string_text(rd, res))
        False -> get_table_string_loop(rd, rest, key)
      }
  }
}

fn get_zone_strings_entry_value(
  zone_chain: List(ZoneChainEntry),
  entry_key: String,
  name_key: String,
) -> Option(String) {
  case zone_chain {
    [] -> None
    [level, ..rest] -> {
      let zs_res = resource.get_resource(level.res_data, "zoneStrings")
      case zs_res == uresimp.res_bogus {
        True -> get_zone_strings_entry_value(rest, entry_key, name_key)
        False -> {
          let entry_res =
            resource.get_table_item_by_key(level.res_data, zs_res, entry_key)
          case entry_res == uresimp.res_bogus {
            True -> get_zone_strings_entry_value(rest, entry_key, name_key)
            False -> {
              let table = resource.get_table(level.res_data, entry_res)
              case get_table_string(level.res_data, table, name_key) {
                Some(value) if value == no_inheritance_marker -> None
                Some(value) -> Some(value)
                None -> get_zone_strings_entry_value(rest, entry_key, name_key)
              }
            }
          }
        }
      }
    }
  }
}

pub fn get_zone_name(
  zone_chain: List(ZoneChainEntry),
  tzid: String,
  name_key: String,
) -> Option(String) {
  get_zone_strings_entry_value(zone_chain, to_colon_key(tzid), name_key)
}

pub fn get_metazone_name(
  zone_chain: List(ZoneChainEntry),
  mzid: String,
  name_key: String,
) -> Option(String) {
  get_zone_strings_entry_value(zone_chain, "meta:" <> mzid, name_key)
}

pub fn get_zone_strings_global(
  zone_chain: List(ZoneChainEntry),
  key: String,
) -> Option(String) {
  case zone_chain {
    [] -> None
    [level, ..rest] -> {
      let zs_res = resource.get_resource(level.res_data, "zoneStrings")
      case zs_res == uresimp.res_bogus {
        True -> get_zone_strings_global(rest, key)
        False -> {
          let table = resource.get_table(level.res_data, zs_res)
          case get_table_string(level.res_data, table, key) {
            Some(value) if value == no_inheritance_marker -> None
            Some(value) -> Some(value)
            None -> get_zone_strings_global(rest, key)
          }
        }
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
  zone_chain: List(ZoneChainEntry),
  tzid: String,
) -> Option(String) {
  case get_zone_name(zone_chain, tzid, "ec") {
    Some(v) -> Some(v)
    None -> get_default_exemplar_location_name(tzid)
  }
}

const default_from = 0

fn default_to() -> Int {
  gregoimp.fields_to_day(9999, 11, 31)
  * gregoimp.millis_per_day
  + 23
  * 3_600_000
  + 59
  * 60_000
}

fn parse_zone_date(text: String) -> Int {
  let year = parse_int_slice(text, 0, 4)
  let month = parse_int_slice(text, 5, 7) - 1
  let day = parse_int_slice(text, 8, 10)
  let #(hour, min) = case string.length(text) == 16 {
    True -> #(parse_int_slice(text, 11, 13), parse_int_slice(text, 14, 16))
    False -> #(0, 0)
  }
  gregoimp.fields_to_day(year, month, day)
  * gregoimp.millis_per_day
  + hour
  * 3_600_000
  + min
  * 60_000
}

fn parse_int_slice(text: String, start: Int, end: Int) -> Int {
  let slice = string.slice(text, start, end - start)
  case int.parse(slice) {
    Ok(v) -> v
    Error(_) -> 0
  }
}

pub fn get_metazone_mappings(
  bundle: Bundle,
  tzid: String,
) -> List(MetazoneMapping) {
  let key = to_colon_key(tzid)
  case resbund.open_direct(bundle, "metaZones") {
    None -> []
    Some(rd) -> {
      let chain = [resbund.LocaleChainEntry("metaZones", Some(rd))]
      case resbund.get_by_path(bundle, chain, "metazoneInfo/" <> key, 0) {
        None -> []
        Some(found) -> {
          let arr = resource.get_array(found.res_data, found.res)
          case arr.get_res {
            None -> []
            Some(get_res) ->
              metazone_mapping_array_loop(
                found.res_data,
                get_res,
                0,
                arr.length,
              )
          }
        }
      }
    }
  }
}

fn metazone_mapping_array_loop(
  rd: resource.ResourceData,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(MetazoneMapping) {
  case i >= length {
    True -> []
    False -> {
      let item = resource.get_array(rd, get_res(i))
      case item.get_res {
        None -> metazone_mapping_array_loop(rd, get_res, i + 1, length)
        Some(item_get_res) -> {
          let name = resource_string_text(rd, item_get_res(0))
          let #(from, to) = case item.length == 3 {
            True -> #(
              parse_zone_date(resource_string_text(rd, item_get_res(1))),
              parse_zone_date(resource_string_text(rd, item_get_res(2))),
            )
            False -> #(default_from, default_to())
          }
          [
            MetazoneMapping(name:, from:, to:),
            ..metazone_mapping_array_loop(rd, get_res, i + 1, length)
          ]
        }
      }
    }
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
  case resbund.open_direct(bundle, "metaZones") {
    None -> None
    Some(rd) -> {
      let chain = [resbund.LocaleChainEntry("metaZones", Some(rd))]
      let found = case
        resbund.get_by_path(
          bundle,
          chain,
          "mapTimezones/" <> mzid <> "/" <> region,
          0,
        )
      {
        Some(f) -> Some(f)
        None ->
          resbund.get_by_path(
            bundle,
            chain,
            "mapTimezones/" <> mzid <> "/001",
            0,
          )
      }
      case found {
        None -> None
        Some(f) -> Some(resource_string_text(f.res_data, f.res))
      }
    }
  }
}

pub fn get_primary_zone_for_region(
  bundle: Bundle,
  region: String,
) -> Option(String) {
  case resbund.open_direct(bundle, "metaZones") {
    None -> None
    Some(rd) -> {
      let chain = [resbund.LocaleChainEntry("metaZones", Some(rd))]
      case resbund.get_by_path(bundle, chain, "primaryZones/" <> region, 0) {
        None -> None
        Some(found) -> Some(resource_string_text(found.res_data, found.res))
      }
    }
  }
}

fn load_canonical_zone_keys(bundle: Bundle) -> List(String) {
  case resbund.open_direct(bundle, "timezoneTypes") {
    None -> []
    Some(rd) -> {
      let root = resource.get_table(rd, rd.root_res)
      case find_res_by_key(root, "typeMap") {
        None -> []
        Some(type_map_res) -> {
          let type_map = resource.get_table(rd, type_map_res)
          case find_res_by_key(type_map, "timezone") {
            None -> []
            Some(tz_res) -> {
              let table = resource.get_table(rd, tz_res)
              collect_keys(table)
            }
          }
        }
      }
    }
  }
}

fn find_res_by_key(
  table: resource.ResourceTableView,
  key: String,
) -> Option(Int) {
  find_res_by_key_loop(table_keys_and_res(table), key)
}

fn find_res_by_key_loop(
  entries: List(#(String, Int)),
  key: String,
) -> Option(Int) {
  case entries {
    [] -> None
    [#(k, res), ..rest] ->
      case k == key {
        True -> Some(res)
        False -> find_res_by_key_loop(rest, key)
      }
  }
}

fn collect_keys(table: resource.ResourceTableView) -> List(String) {
  list.map(table_keys_and_res(table), fn(pair) { pair.0 })
}

fn dedupe(list_in: List(String)) -> List(String) {
  dedupe_loop(list_in, dict.new())
}

fn dedupe_loop(list_in: List(String), seen: Dict(String, Nil)) -> List(String) {
  case list_in {
    [] -> []
    [head, ..tail] ->
      case dict.has_key(seen, head) {
        True -> dedupe_loop(tail, seen)
        False -> [head, ..dedupe_loop(tail, dict.insert(seen, head, Nil))]
      }
  }
}

fn canonical_zone_keys(bundle: Bundle) -> List(String) {
  let key = "zonekeys\n" <> bundle.data_path
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) -> cache.put(key, dedupe(load_canonical_zone_keys(bundle)))
  }
}

fn is_single_zone_country(bundle: Bundle, region: String) -> Bool {
  let canonical_keys = canonical_zone_keys(bundle)
  count_zone_country_matches(bundle, canonical_keys, region, 0) == 1
}

fn count_zone_country_matches(
  bundle: Bundle,
  keys: List(String),
  region: String,
  acc: Int,
) -> Int {
  case acc > 1 {
    True -> acc
    False ->
      case keys {
        [] -> acc
        [key, ..rest] -> {
          let tzid = string.replace(key, ":", "/")
          let acc = case
            zonemeta.get_region(zonemeta_bundle(bundle), tzid) == Some(region)
          {
            True -> acc + 1
            False -> acc
          }
          count_zone_country_matches(bundle, rest, region, acc)
        }
      }
  }
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
  find_region_display_name(get_region_chain(bundle, locale_id), region)
}

fn find_region_display_name(
  chain: List(ZoneChainEntry),
  region: String,
) -> String {
  case chain {
    [] -> region
    [level, ..rest] -> {
      let countries_res = resource.get_resource(level.res_data, "Countries")
      case countries_res == uresimp.res_bogus {
        True -> find_region_display_name(rest, region)
        False -> {
          let table = resource.get_table(level.res_data, countries_res)
          case get_table_string(level.res_data, table, region) {
            Some(value) if value == no_inheritance_marker -> region
            Some(value) -> value
            None -> find_region_display_name(rest, region)
          }
        }
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
        False -> get_exemplar_city(zone_chain, canonical_tzid)
      }
      case location {
        None -> None
        Some(loc) -> {
          let region_format = case
            get_zone_strings_global(zone_chain, "regionFormat")
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
  case get_zone_name(zone_chain, canonical_tzid, key) {
    Some(v) -> Some(v)
    None ->
      case get_metazone_at(bundle, canonical_tzid, epoch_millis) {
        None -> None
        Some(mzid) -> get_metazone_name(zone_chain, mzid, key)
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
        _ -> get_exemplar_city(zone_chain, canonical_tzid)
      }
    None ->
      case get_exemplar_city(zone_chain, canonical_tzid) {
        Some(city) -> Some(city)
        None -> Some(canonical_tzid)
      }
  }
  let location = option.unwrap(location, "")
  let fallback_format = case
    get_zone_strings_global(zone_chain, "fallbackFormat")
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
  case get_zone_name(zone_chain, canonical_tzid, gen_key) {
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
                get_standard_name(zone_chain, canonical_tzid, mzid, std_key)
              {
                None -> None
                Some(std_name) ->
                  case get_metazone_name(zone_chain, mzid, gen_key) {
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
              case get_metazone_name(zone_chain, mzid, gen_key) {
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
  zone_chain: List(ZoneChainEntry),
  canonical_tzid: String,
  mzid: String,
  std_key: String,
) -> Option(String) {
  case get_zone_name(zone_chain, canonical_tzid, std_key) {
    Some(v) -> Some(v)
    None -> get_metazone_name(zone_chain, mzid, std_key)
  }
}
