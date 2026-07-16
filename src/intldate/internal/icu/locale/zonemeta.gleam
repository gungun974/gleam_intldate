import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/resource

pub const zid_key_max = 128

pub const unknown_zone_id = "Etc/Unknown"

type CanonicalIdCache =
  Dict(String, String)

pub fn new_canonical_id_cache() -> CanonicalIdCache {
  dict.new()
}

pub type CanonicalCountryResult {
  CanonicalCountryResult(country: Option(String), is_primary: Bool)
}

pub type CanonicalTimeZoneIdResult {
  CanonicalTimeZoneIdResult(canonical_id: Option(String), is_system_id: Bool)
}

pub fn find_time_zone_id(bundle: Bundle, tzid: String) -> Option(String) {
  let zone_info = bundle.zone_info_64
  case dict.has_key(zone_info.zones, tzid) {
    False -> None
    True -> Some(tzid)
  }
}

pub fn find_id(bundle: Bundle, id: String) -> Option(String) {
  find_time_zone_id(bundle, id)
}

pub fn derefer_olson_link(bundle: Bundle, tzid: String) -> Option(String) {
  let zone_info = bundle.zone_info_64

  case dict.get(zone_info.zones, tzid) {
    Error(_) -> None
    Ok(resource.ZoneAlias(alias:)) -> Some(alias)
    Ok(resource.Zone(..)) -> Some(tzid)
  }
}

pub fn get_region(bundle: Bundle, tzid: String) -> Option(String) {
  let zone_info = bundle.zone_info_64

  case dict.get(zone_info.regions, tzid) {
    Error(_) -> None
    Ok(region) -> Some(region)
  }
}

pub fn tzid_to_key(id: String) -> String {
  string.replace(id, "/", ":")
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
  let timezone_types = bundle.timezone_types
  let id = tzid_to_key(tzid)

  let #(canonical_id, is_input_canonical) = case
    dict.has_key(timezone_types.type_map_timezone, id)
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
      let canonical_id =
        option.from_result(dict.get(timezone_types.type_alias_timezone, id))
      case canonical_id {
        Some(_) ->
          finalize_canonical_id(bundle, cache, tzid, canonical_id, False)
        None ->
          case derefer_olson_link(bundle, tzid) {
            None -> #(None, cache)
            Some(derefer) -> {
              let id2 = tzid_to_key(derefer)
              let canonical_id =
                option.from_result(dict.get(
                  timezone_types.type_alias_timezone,
                  id2,
                ))
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
      let timezone_types = bundle.timezone_types
      #(
        option.from_result(dict.get(
          timezone_types.type_map_timezone,
          tzid_to_key(cid),
        )),
        cache,
      )
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

pub fn ucal_get_canonical_time_zone_id(
  bundle: Bundle,
  cache: CanonicalIdCache,
  tzid: String,
) -> #(CanonicalTimeZoneIdResult, CanonicalIdCache) {
  get_canonical_time_zone_id(bundle, cache, tzid)
}
