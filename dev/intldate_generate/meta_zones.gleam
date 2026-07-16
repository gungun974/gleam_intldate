import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/resource.{
  type MetazoneMapping, MetaZonesData, MetazoneMapping,
}
import intldate_generate/icurb
import intldate_generate/save
import simplifile

const zone_metazone_default_from = 0

fn zone_metazone_default_to() -> Int {
  gregoimp.fields_to_day(9999, 11, 31)
  * gregoimp.millis_per_day
  + 23
  * 3_600_000
  + 59
  * 60_000
}

fn parse_zone_date(text: String) -> Int {
  let year = parse_zone_int_slice(text, 0, 4)
  let month = parse_zone_int_slice(text, 5, 7) - 1
  let day = parse_zone_int_slice(text, 8, 10)
  let #(hour, min) = case string.length(text) == 16 {
    True -> #(
      parse_zone_int_slice(text, 11, 13),
      parse_zone_int_slice(text, 14, 16),
    )
    False -> #(0, 0)
  }
  gregoimp.fields_to_day(year, month, day)
  * gregoimp.millis_per_day
  + hour
  * 3_600_000
  + min
  * 60_000
}

fn parse_zone_int_slice(text: String, start: Int, end: Int) -> Int {
  let slice = string.slice(text, start, end - start)
  case int.parse(slice) {
    Ok(v) -> v
    Error(_) -> 0
  }
}

fn build_metazone_mapping(entries: List(String)) -> MetazoneMapping {
  case entries {
    [name, from_str, to_str] ->
      MetazoneMapping(
        name:,
        from: parse_zone_date(from_str),
        to: parse_zone_date(to_str),
      )
    [name, ..] ->
      MetazoneMapping(
        name:,
        from: zone_metazone_default_from,
        to: zone_metazone_default_to(),
      )
    [] ->
      MetazoneMapping(
        name: "",
        from: zone_metazone_default_from,
        to: zone_metazone_default_to(),
      )
  }
}

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/metaZones.txt")

  let assert Ok(data) = parse_meta_zones_data(contents)
  save.save_meta_zones_data(data)
  data
}

fn parse_meta_zones_data(contents: String) {
  icurb.parse(contents, {
    use metazone_info_raw <- decode.field(
      "metazoneInfo",
      decode.dict(decode.string, decode.list(decode.list(decode.string))),
    )
    use map_timezones <- decode.field(
      "mapTimezones",
      decode.dict(decode.string, decode.dict(decode.string, decode.string)),
    )
    use primary_zones <- decode.field(
      "primaryZones",
      decode.dict(decode.string, decode.string),
    )

    decode.success(MetaZonesData(
      metazone_info: dict.map_values(metazone_info_raw, fn(_k, items) {
        list.map(items, build_metazone_mapping)
      }),
      map_timezones:,
      primary_zones:,
    ))
  })
}
