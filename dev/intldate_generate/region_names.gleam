import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/string
import intldate/internal/icu/icudata/resource.{RegionNamesByLocale}
import intldate_generate/icurb
import intldate_generate/log
import simplifile

fn all_region_locale_names(region_dir: String) -> List(String) {
  let assert Ok(entries) = simplifile.read_directory(region_dir)
  list.filter_map(entries, fn(entry) {
    case string.ends_with(entry, ".txt") {
      True -> Ok(string.drop_end(entry, 4))
      False -> Error(Nil)
    }
  })
}

fn parse_locale_countries(contents: String) {
  icurb.parse(contents, {
    use countries <- decode.optional_field(
      "Countries",
      dict.new(),
      decode.dict(decode.string, decode.string),
    )
    decode.success(countries)
  })
}

pub fn generate(icu_path: String) {
  let region_dir = icu_path <> "/icu4c/source/data/region"
  let names = all_region_locale_names(region_dir)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(region_dir <> "/" <> name <> ".txt")
      case parse_locale_countries(contents) {
        Ok(countries) ->
          case dict.is_empty(countries) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, countries), failed)
          }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Region name parsing", failed)
  RegionNamesByLocale(locales:)
}
