import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/string
import intldate/internal/icu/icudata/resource.{
  type ZoneStringsLocale, ZoneStringsByLocale, ZoneStringsLocale,
}
import intldate_generate/icurb
import intldate_generate/log
import simplifile

type ZsValue {
  ZsTable(dict.Dict(String, String))
  ZsPlain(String)
}

fn zs_value_decoder() -> decode.Decoder(ZsValue) {
  decode.one_of(decode.map(decode.dict(decode.string, decode.string), ZsTable), [
    decode.map(decode.string, ZsPlain),
  ])
}

fn split_zone_strings_loop(
  entries: List(#(String, ZsValue)),
  zones: dict.Dict(String, dict.Dict(String, String)),
  metazones: dict.Dict(String, dict.Dict(String, String)),
  globals: dict.Dict(String, String),
) -> ZoneStringsLocale {
  case entries {
    [] -> ZoneStringsLocale(zones:, metazones:, globals:)
    [#(key, value), ..rest] ->
      case value {
        ZsPlain(s) ->
          split_zone_strings_loop(
            rest,
            zones,
            metazones,
            dict.insert(globals, key, s),
          )
        ZsTable(t) ->
          case string.starts_with(key, "meta:") {
            True ->
              split_zone_strings_loop(
                rest,
                zones,
                dict.insert(metazones, string.drop_start(key, 5), t),
                globals,
              )
            False ->
              split_zone_strings_loop(
                rest,
                dict.insert(zones, key, t),
                metazones,
                globals,
              )
          }
      }
  }
}

fn parse_locale_zone_strings(contents: String) {
  icurb.parse(contents, {
    use raw <- decode.optional_field(
      "zoneStrings",
      dict.new(),
      decode.dict(decode.string, zs_value_decoder()),
    )
    decode.success(split_zone_strings_loop(
      dict.to_list(raw),
      dict.new(),
      dict.new(),
      dict.new(),
    ))
  })
}

fn all_zone_locale_names(zone_dir: String) -> List(String) {
  let assert Ok(entries) = simplifile.read_directory(zone_dir)
  list.filter_map(entries, fn(entry) {
    case entry {
      "tzdbNames.txt" -> Error(Nil)
      _ ->
        case string.ends_with(entry, ".txt") {
          True -> Ok(string.drop_end(entry, 4))
          False -> Error(Nil)
        }
    }
  })
}

fn is_empty_zone_strings_locale(zs: ZoneStringsLocale) -> Bool {
  dict.is_empty(zs.zones)
  && dict.is_empty(zs.metazones)
  && dict.is_empty(zs.globals)
}

pub fn generate(icu_path: String) {
  let zone_dir = icu_path <> "/icu4c/source/data/zone"
  let names = all_zone_locale_names(zone_dir)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(zone_dir <> "/" <> name <> ".txt")
      case parse_locale_zone_strings(contents) {
        Ok(zs) ->
          case is_empty_zone_strings_locale(zs) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, zs), failed)
          }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Zone string parsing", failed)
  ZoneStringsByLocale(locales:)
}
