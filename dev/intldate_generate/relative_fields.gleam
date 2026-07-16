import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import intldate/internal/icu/icudata/resource.{
  RelativeFieldAliasTo, RelativeFieldValue, RelativeFieldsByLocale,
  RelativeUnitData,
}
import intldate_generate/decoder
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/shared
import simplifile

fn optional_string_dict_subfield(
  path: List(String),
) -> decode.Decoder(dict.Dict(String, String)) {
  decode.one_of(
    decode.subfield(
      path,
      decode.dict(decode.string, decode.string),
      decode.success,
    ),
    [decode.success(dict.new())],
  )
}

fn relative_unit_data_decoder() -> decode.Decoder(resource.RelativeUnitData) {
  use display_name <- decode.optional_field(
    "dn",
    None,
    decode.map(decoder.resource_string(), Some),
  )
  use relative <- decode.optional_field(
    "relative",
    dict.new(),
    decode.dict(decode.string, decode.string),
  )
  use past <- decode.then(
    optional_string_dict_subfield([
      "relativeTime",
      "past",
    ]),
  )
  use future <- decode.then(
    optional_string_dict_subfield([
      "relativeTime",
      "future",
    ]),
  )
  decode.success(RelativeUnitData(display_name:, relative:, past:, future:))
}

fn relative_field_decoder() -> decode.Decoder(resource.RelativeField) {
  use resolved <- decode.then(icurb.resolvable(relative_unit_data_decoder()))
  case resolved {
    icurb.Value(value) -> decode.success(RelativeFieldValue(value))
    icurb.AliasTo(target) -> decode.success(RelativeFieldAliasTo(target))
  }
}

fn parse_locale_relative_fields(contents: String) {
  icurb.parse(contents, {
    use fields <- decode.optional_field(
      "fields",
      dict.new(),
      decode.dict(decode.string, relative_field_decoder()),
    )
    decode.success(fields)
  })
}

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_relative_fields(contents) {
        Ok(fields) ->
          case dict.is_empty(fields) {
            True -> #(locales, failed)
            False -> #(dict.insert(locales, name, fields), failed)
          }
        Error(_) -> #(locales, [name, ..failed])
      }
    })
  log.parse_failures("Relative field parsing", failed)
  RelativeFieldsByLocale(locales:)
}
