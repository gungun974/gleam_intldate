import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resource
import intldate_generate/icurb

fn calendar_alias_target(target: String) -> Option(String) {
  case string.split(target, "/") {
    ["", "LOCALE", "calendar", calendar, ..] -> Some(calendar)
    _ -> None
  }
}

pub fn calendar_field(
  path: List(String),
  inner: decode.Decoder(value),
) -> decode.Decoder(Option(resource.CalendarField(value))) {
  decode.one_of(
    decode.subfield(path, icurb.resolvable(inner), fn(value) {
      case value {
        icurb.Value(value) ->
          decode.success(Some(resource.CalendarValue(value)))
        icurb.AliasTo(target) ->
          case calendar_alias_target(target) {
            Some(calendar) ->
              decode.success(Some(resource.CalendarAliasTo(calendar)))
            None -> decode.success(None)
          }
      }
    }),
    [decode.success(None)],
  )
}

pub fn resource_string() -> decode.Decoder(String) {
  decode.one_of(decode.string, [
    {
      use values <- decode.then(decode.list(decode.string))
      case values {
        [value, ..] -> decode.success(value)
        [] -> decode.failure("", "empty resource string array")
      }
    },
  ])
}
