import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resource.{type ResourceData}
import intldate/internal/icu/icudata/uresimp

pub const zid_key_max = 128

const g_key_type_data = "keyTypeData"

const g_type_alias_tag = "typeAlias"

const g_type_map_tag = "typeMap"

const g_timezone_tag = "timezone"

pub const unknown_zone_id = "Etc/Unknown"

pub type Bundle {
  Bundle(data_path: String, open_direct: fn(String) -> ResourceData)
}

type CanonicalIdCache =
  Dict(String, String)

pub fn new_canonical_id_cache() -> CanonicalIdCache {
  dict.new()
}

pub type ZoneInfo {
  ZoneInfo(
    rd: ResourceData,
    names: resource.ResourceArrayView,
    zones: resource.ResourceArrayView,
    regions: resource.ResourceArrayView,
  )
}

pub type KeyTypeDataBundle {
  KeyTypeDataBundle(rd: ResourceData, by_key: Dict(String, Int))
}

pub type AliasTableRef {
  AliasTableRef(rd: ResourceData, table: resource.ResourceTableView)
}

pub type CanonicalCountryResult {
  CanonicalCountryResult(country: Option(String), is_primary: Bool)
}

pub type CanonicalTimeZoneIdResult {
  CanonicalTimeZoneIdResult(canonical_id: Option(String), is_system_id: Bool)
}

pub type ZoneResourceTable {
  ZoneResourceTable(
    rd: ResourceData,
    table: resource.ResourceTableView,
    rules_table: Option(resource.ResourceTableView),
  )
}

fn find_table_entry_by_key(
  table: resource.ResourceTableView,
  key: String,
) -> Option(Int) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      find_table_entry_by_key_loop(get_key, get_res, table.length, key, 0)
    _, _ -> None
  }
}

fn find_table_entry_by_key_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  length: Int,
  key: String,
  i: Int,
) -> Option(Int) {
  case i >= length {
    True -> None
    False ->
      case get_key(i) == key {
        True -> Some(get_res(i))
        False ->
          find_table_entry_by_key_loop(get_key, get_res, length, key, i + 1)
      }
  }
}

fn root_table_by_key(rd: ResourceData) -> Dict(String, Int) {
  let root = resource.get_table(rd, rd.root_res)
  case root.get_key, root.get_res {
    Some(get_key), Some(get_res) ->
      root_table_by_key_loop(get_key, get_res, root.length, 0, dict.new())
    _, _ -> dict.new()
  }
}

fn root_table_by_key_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  length: Int,
  i: Int,
  acc: Dict(String, Int),
) -> Dict(String, Int) {
  case i >= length {
    True -> acc
    False ->
      root_table_by_key_loop(
        get_key,
        get_res,
        length,
        i + 1,
        dict.insert(acc, get_key(i), get_res(i)),
      )
  }
}

pub fn load_zone_info(bundle: Bundle) -> ZoneInfo {
  let rd = bundle.open_direct("zoneinfo64")
  let by_key = root_table_by_key(rd)
  let get = fn(key) {
    case dict.get(by_key, key) {
      Ok(res) -> resource.get_array(rd, res)
      Error(_) -> resource.ResourceArrayView(0, None)
    }
  }
  ZoneInfo(rd, get("Names"), get("Zones"), get("Regions"))
}

fn load_key_type_data(bundle: Bundle) -> KeyTypeDataBundle {
  let rd = bundle.open_direct(g_key_type_data)
  KeyTypeDataBundle(rd, root_table_by_key(rd))
}

fn resource_string_text(rd: ResourceData, res: Int) -> String {
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

fn find_zone_index(
  rd: ResourceData,
  names: resource.ResourceArrayView,
  id: String,
) -> Int {
  case names.get_res {
    None -> -1
    Some(get_res) -> find_zone_index_loop(rd, get_res, id, 0, names.length)
  }
}

fn find_zone_index_loop(
  rd: ResourceData,
  get_res: fn(Int) -> Int,
  id: String,
  start: Int,
  limit: Int,
) -> Int {
  case start < limit {
    False -> -1
    True -> {
      let mid = { start + limit } / 2
      let s = resource_string_text(rd, get_res(mid))
      case string.compare(id, s) {
        order.Lt -> find_zone_index_loop(rd, get_res, id, start, mid)
        order.Gt -> find_zone_index_loop(rd, get_res, id, mid + 1, limit)
        order.Eq -> mid
      }
    }
  }
}

pub fn find_time_zone_id(bundle: Bundle, tzid: String) -> Option(String) {
  let key = "find_time_zone_id\n" <> bundle.data_path <> "\n" <> tzid
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      case uncached_find_time_zone_id(bundle, tzid) {
        Some(found) -> cache.put(key, Some(found))
        None -> None
      }
  }
}

fn uncached_find_time_zone_id(bundle: Bundle, tzid: String) -> Option(String) {
  let info = load_zone_info(bundle)
  let idx = find_zone_index(info.rd, info.names, tzid)
  case idx < 0 {
    True -> None
    False -> {
      let assert Some(get_res) = info.names.get_res
      Some(resource_string_text(info.rd, get_res(idx)))
    }
  }
}

pub fn find_id(bundle: Bundle, id: String) -> Option(String) {
  find_time_zone_id(bundle, id)
}

pub fn derefer_olson_link(bundle: Bundle, tzid: String) -> Option(String) {
  let key = "derefer_olson_link\n" <> bundle.data_path <> "\n" <> tzid
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      case uncached_derefer_olson_link(bundle, tzid) {
        Some(found) -> cache.put(key, Some(found))
        None -> None
      }
  }
}

fn uncached_derefer_olson_link(bundle: Bundle, tzid: String) -> Option(String) {
  let info = load_zone_info(bundle)
  let idx = find_zone_index(info.rd, info.names, tzid)
  case idx < 0 {
    True -> None
    False -> {
      let assert Some(get_names_res) = info.names.get_res
      let assert Some(get_zones_res) = info.zones.get_res
      let result = resource_string_text(info.rd, get_names_res(idx))
      let zres = get_zones_res(idx)
      case uresimp.res_get_type(zres) == uresimp.ResInt {
        True -> {
          let inner_idx =
            resource.resource_value_get_int(resource.create_resource_value(
              Some(info.rd),
              zres,
            ))
          Some(resource_string_text(info.rd, get_names_res(inner_idx)))
        }
        False -> Some(result)
      }
    }
  }
}

pub fn get_region(bundle: Bundle, tzid: String) -> Option(String) {
  let key = "get_region\n" <> bundle.data_path <> "\n" <> tzid
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      case uncached_get_region(bundle, tzid) {
        Some(found) -> cache.put(key, Some(found))
        None -> None
      }
  }
}

fn uncached_get_region(bundle: Bundle, tzid: String) -> Option(String) {
  let info = load_zone_info(bundle)
  let idx = find_zone_index(info.rd, info.names, tzid)
  case idx < 0 {
    True -> None
    False -> {
      let assert Some(get_regions_res) = info.regions.get_res
      Some(resource_string_text(info.rd, get_regions_res(idx)))
    }
  }
}

pub fn tzid_to_key(id: String) -> String {
  string.replace(id, "/", ":")
}

fn strip_icudata_prefix(alias: String) -> String {
  case string.starts_with(alias, "/ICUDATA/") {
    True -> string.drop_start(alias, 9)
    False -> alias
  }
}

fn resolve_alias_table(
  bundle: Bundle,
  rd: ResourceData,
  alias: String,
) -> Option(AliasTableRef) {
  let parts = string.split(strip_icudata_prefix(alias), "/")
  case parts {
    [] -> None
    [bundle_name, ..rest] -> {
      let current_rd = case bundle_name == g_key_type_data {
        True -> rd
        False -> bundle.open_direct(bundle_name)
      }
      resolve_alias_table_loop(current_rd, current_rd.root_res, rest)
    }
  }
}

fn resolve_alias_table_loop(
  rd: ResourceData,
  current_res: Int,
  parts: List(String),
) -> Option(AliasTableRef) {
  case parts {
    [] -> Some(AliasTableRef(rd, resource.get_table(rd, current_res)))
    [part, ..rest] -> {
      let table = resource.get_table(rd, current_res)
      case find_table_entry_by_key(table, part) {
        None -> None
        Some(next_res) -> resolve_alias_table_loop(rd, next_res, rest)
      }
    }
  }
}

fn get_type_table(
  bundle: Bundle,
  rd: ResourceData,
  by_key: Dict(String, Int),
  table_key: String,
  type_key: String,
) -> Option(AliasTableRef) {
  case dict.get(by_key, table_key) {
    Error(_) -> None
    Ok(table_res) -> {
      let table = resource.get_table(rd, table_res)
      case find_table_entry_by_key(table, type_key) {
        None -> None
        Some(type_res) ->
          case uresimp.res_get_type(type_res) == uresimp.ResAlias {
            True -> {
              let alias = case
                resource.resource_value_get_alias_string(
                  resource.create_resource_value(Some(rd), type_res),
                )
              {
                Some(s) -> s.text
                None -> ""
              }
              resolve_alias_table(bundle, rd, alias)
            }
            False -> Some(AliasTableRef(rd, resource.get_table(rd, type_res)))
          }
      }
    }
  }
}

fn type_map_has_key(table: Option(AliasTableRef), key: String) -> Bool {
  case table {
    None -> False
    Some(ref) ->
      case ref.table.get_key {
        None -> False
        Some(get_key) ->
          type_map_has_key_loop(get_key, ref.table.length, key, 0)
      }
  }
}

fn type_map_has_key_loop(
  get_key: fn(Int) -> String,
  length: Int,
  key: String,
  i: Int,
) -> Bool {
  case i >= length {
    True -> False
    False ->
      case get_key(i) == key {
        True -> True
        False -> type_map_has_key_loop(get_key, length, key, i + 1)
      }
  }
}

fn get_string_by_key(
  table: Option(AliasTableRef),
  key: String,
) -> Option(String) {
  case table {
    None -> None
    Some(ref) ->
      case ref.table.get_key, ref.table.get_res {
        Some(get_key), Some(get_res) ->
          get_string_by_key_loop(
            ref.rd,
            get_key,
            get_res,
            ref.table.length,
            key,
            0,
          )
        _, _ -> None
      }
  }
}

fn get_string_by_key_loop(
  rd: ResourceData,
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  length: Int,
  key: String,
  i: Int,
) -> Option(String) {
  case i >= length {
    True -> None
    False ->
      case get_key(i) == key {
        True -> Some(resource_string_text(rd, get_res(i)))
        False ->
          get_string_by_key_loop(rd, get_key, get_res, length, key, i + 1)
      }
  }
}

pub fn get_canonical_cldr_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: Option(String),
) -> #(Option(String), CanonicalIdCache) {
  case tzid {
    None -> #(None, cache)
    Some(id) ->
      case string.length(id) > zid_key_max {
        True -> #(None, cache)
        False ->
          case dict.get(cache, id) {
            Ok(cached) -> #(Some(cached), cache)
            Error(_) -> compute_canonical_cldr_id(bundle, cache, id)
          }
      }
  }
}

fn compute_canonical_cldr_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
) -> #(Option(String), CanonicalIdCache) {
  let key_type_data = load_key_type_data(bundle)
  let type_map =
    get_type_table(
      bundle,
      key_type_data.rd,
      key_type_data.by_key,
      g_type_map_tag,
      g_timezone_tag,
    )
  let id = tzid_to_key(tzid)

  let #(canonical_id, is_input_canonical) = case
    type_map_has_key(type_map, id)
  {
    True -> #(find_id(bundle, tzid), True)
    False -> #(None, False)
  }

  case canonical_id {
    Some(_) ->
      finalize_canonical_id(
        bundle,
        cache,
        tzid,
        canonical_id,
        is_input_canonical,
      )
    None -> {
      let type_alias =
        get_type_table(
          bundle,
          key_type_data.rd,
          key_type_data.by_key,
          g_type_alias_tag,
          g_timezone_tag,
        )
      let canonical_id = get_string_by_key(type_alias, id)
      case canonical_id {
        Some(_) ->
          finalize_canonical_id(bundle, cache, tzid, canonical_id, False)
        None ->
          case derefer_olson_link(bundle, tzid) {
            None -> #(None, cache)
            Some(derefer) -> {
              let id2 = tzid_to_key(derefer)
              let canonical_id = get_string_by_key(type_alias, id2)
              case canonical_id {
                Some(_) ->
                  finalize_canonical_id(
                    bundle,
                    cache,
                    tzid,
                    canonical_id,
                    False,
                  )
                None ->
                  finalize_canonical_id(
                    bundle,
                    cache,
                    tzid,
                    Some(derefer),
                    True,
                  )
              }
            }
          }
      }
    }
  }
}

fn finalize_canonical_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
  canonical_id: Option(String),
  is_input_canonical: Bool,
) -> #(Option(String), CanonicalIdCache) {
  case canonical_id {
    None -> #(None, cache)
    Some(cid) -> {
      let cache = case find_time_zone_id(bundle, tzid) {
        Some(key) ->
          case dict.has_key(cache, key) {
            True -> cache
            False -> dict.insert(cache, key, cid)
          }
        None -> cache
      }
      let cache = case is_input_canonical {
        True ->
          case dict.has_key(cache, cid) {
            True -> cache
            False -> dict.insert(cache, cid, cid)
          }
        False -> cache
      }
      #(Some(cid), cache)
    }
  }
}

pub fn get_short_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
) -> #(Option(String), CanonicalIdCache) {
  let #(canonical_id, cache) = get_canonical_cldr_id(bundle, cache, Some(tzid))
  case canonical_id {
    None -> #(None, cache)
    Some(cid) -> {
      let key_type_data = load_key_type_data(bundle)
      let type_map =
        get_type_table(
          bundle,
          key_type_data.rd,
          key_type_data.by_key,
          g_type_map_tag,
          g_timezone_tag,
        )
      #(get_string_by_key(type_map, tzid_to_key(cid)), cache)
    }
  }
}

pub fn get_canonical_time_zone_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
) -> #(CanonicalTimeZoneIdResult, CanonicalIdCache) {
  case tzid == unknown_zone_id {
    True -> #(CanonicalTimeZoneIdResult(Some(unknown_zone_id), False), cache)
    False -> {
      let #(canonical_id, cache) =
        get_canonical_cldr_id(bundle, cache, Some(tzid))
      case canonical_id {
        None -> #(CanonicalTimeZoneIdResult(None, False), cache)
        Some(_) -> #(CanonicalTimeZoneIdResult(canonical_id, True), cache)
      }
    }
  }
}

fn get_rules_table(rd: ResourceData) -> Option(resource.ResourceTableView) {
  let root = resource.get_table(rd, rd.root_res)
  case find_table_entry_by_key(root, "Rules") {
    None -> None
    Some(rules_res) -> Some(resource.get_table(rd, rules_res))
  }
}

pub fn get_zone_resource_table(
  bundle: Bundle,
  tzid: String,
) -> Option(ZoneResourceTable) {
  let info = load_zone_info(bundle)
  let idx = find_zone_index(info.rd, info.names, tzid)
  case idx < 0 {
    True -> None
    False -> {
      let assert Some(get_zones_res) = info.zones.get_res
      let zres = get_zones_res(idx)
      let zres = case uresimp.res_get_type(zres) == uresimp.ResInt {
        True -> {
          let inner_idx =
            resource.resource_value_get_int(resource.create_resource_value(
              Some(info.rd),
              zres,
            ))
          get_zones_res(inner_idx)
        }
        False -> zres
      }
      Some(ZoneResourceTable(
        info.rd,
        resource.get_table(info.rd, zres),
        get_rules_table(info.rd),
      ))
    }
  }
}

pub fn ucal_get_canonical_time_zone_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
) -> #(CanonicalTimeZoneIdResult, CanonicalIdCache) {
  get_canonical_time_zone_id(bundle, cache, tzid)
}
