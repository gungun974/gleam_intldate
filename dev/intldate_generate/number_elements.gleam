import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/icudata/resource.{NumberElementsByLocale}
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/shared
import simplifile

fn nullable_string() -> decode.Decoder(Option(String)) {
  decode.one_of(decode.map(decode.string, Some), [decode.success(None)])
}

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_number_elements(contents) {
        Ok(elements) ->
          case dict.is_empty(elements) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, elements), failed)
          }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Number element parsing", failed)
  NumberElementsByLocale(locales:)
}

fn parse_locale_number_elements(contents: String) {
  icurb.parse(contents, {
    use raw <- decode.optional_field(
      "NumberElements",
      dict.new(),
      decode.dict(decode.string, nullable_string()),
    )
    decode.success(
      dict.fold(raw, dict.new(), fn(acc, k, v) {
        case v {
          Some(s) -> dict.insert(acc, k, s)
          None -> acc
        }
      }),
    )
  })
}
