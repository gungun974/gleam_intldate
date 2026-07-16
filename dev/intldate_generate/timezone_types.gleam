import gleam/dict
import gleam/dynamic/decode
import gleam/string
import intldate/internal/icu/icudata/resource.{TimezoneTypes}
import intldate_generate/icurb
import intldate_generate/save
import simplifile

pub fn generate(icu_path: String, zone_info: resource.ZoneInfo64) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/timezoneTypes.txt")

  let assert Ok(timezone_types) = parse_timezone_types(contents)
  let timezone_types =
    TimezoneTypes(
      ..timezone_types,
      single_zone_regions: build_single_zone_regions(
        timezone_types.type_map_timezone,
        zone_info.regions,
      ),
    )
  save.save_timezone_types(timezone_types)
  timezone_types
}

fn build_single_zone_regions(
  canonical_zones: dict.Dict(String, String),
  zone_regions: dict.Dict(String, String),
) -> dict.Dict(String, Nil) {
  let counts =
    dict.fold(canonical_zones, dict.new(), fn(counts, key, _bcp_id) {
      let tzid = string.replace(key, ":", "/")
      case dict.get(zone_regions, tzid) {
        Ok(region) if region != "001" -> {
          let count = case dict.get(counts, region) {
            Ok(count) -> count
            Error(_) -> 0
          }
          dict.insert(counts, region, count + 1)
        }
        _ -> counts
      }
    })
  dict.fold(counts, dict.new(), fn(regions, region, count) {
    case count == 1 {
      True -> dict.insert(regions, region, Nil)
      False -> regions
    }
  })
}

fn parse_timezone_types(contents: String) {
  icurb.parse(contents, {
    use type_alias_timezone <- decode.subfield(
      ["typeAlias", "timezone"],
      decode.dict(decode.string, decode.string),
    )

    use type_map_timezone <- decode.subfield(
      ["typeMap", "timezone"],
      decode.dict(decode.string, decode.string),
    )

    use bcp_type_alias_tz <- decode.subfield(
      ["bcpTypeAlias", "tz"],
      decode.dict(decode.string, decode.string),
    )

    decode.success(TimezoneTypes(
      type_alias_timezone:,
      type_map_timezone:,
      bcp_type_alias_tz:,
      single_zone_regions: dict.new(),
    ))
  })
}
