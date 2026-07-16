import gleam/dict
import gleam/dynamic/decode
import gleam/list
import intldate/internal/icu/icudata/resource.{LocaleParents}
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/save
import intldate_generate/shared
import simplifile

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(overrides, aliases, failed) =
    list.fold(names, #(dict.new(), dict.new(), []), fn(state, name) {
      let #(overrides, aliases, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_parent(contents) {
        Ok(#(parent, alias)) -> #(
          case parent {
            "" -> overrides
            _ -> dict.insert(overrides, name, parent)
          },
          case alias {
            "" -> aliases
            _ -> dict.insert(aliases, name, alias)
          },
          failed,
        )
        Error(_) -> #(overrides, aliases, [name, ..failed])
      }
    })
  log.parse_failures("Locale parent parsing", failed)
  let data = LocaleParents(overrides:, aliases:, installed_locales: names)
  save.save_locale_parents(data)
  data
}

fn parse_locale_parent(contents: String) {
  icurb.parse(contents, {
    use parent <- decode.optional_field("%%Parent", "", decode.string)
    use alias <- decode.optional_field("%%ALIAS", "", decode.string)
    decode.success(#(parent, alias))
  })
}
