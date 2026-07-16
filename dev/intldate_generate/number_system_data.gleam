import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resource.{
  type NumberSystemSymbols, NumberSystemDataByLocale, NumberSystemSymbols,
}
import intldate_generate/icurb
import intldate_generate/log
import intldate_generate/shared
import simplifile

fn optional_resolvable_subfield(
  path: List(String),
  inner: decode.Decoder(t),
) -> decode.Decoder(Option(icurb.Resolved(t))) {
  decode.one_of(
    decode.subfield(path, icurb.resolvable(inner), fn(value) {
      decode.success(Some(value))
    }),
    [decode.success(None)],
  )
}

type RawNsSymbols {
  RawNsSymbols(
    decimal_separator: Option(icurb.Resolved(String)),
    grouping_separator: Option(icurb.Resolved(String)),
    minus_sign: Option(icurb.Resolved(String)),
    decimal_format_pattern: Option(icurb.Resolved(String)),
  )
}

fn raw_ns_symbols_decoder() -> decode.Decoder(RawNsSymbols) {
  use decimal_separator <- decode.then(optional_resolvable_subfield(
    ["symbols", "decimal"],
    decode.string,
  ))
  use grouping_separator <- decode.then(optional_resolvable_subfield(
    ["symbols", "group"],
    decode.string,
  ))
  use minus_sign <- decode.then(optional_resolvable_subfield(
    ["symbols", "minusSign"],
    decode.string,
  ))
  use decimal_format_pattern <- decode.then(optional_resolvable_subfield(
    ["patterns", "decimalFormat"],
    decode.string,
  ))
  decode.success(RawNsSymbols(
    decimal_separator:,
    grouping_separator:,
    minus_sign:,
    decimal_format_pattern:,
  ))
}

fn is_empty_ns_symbols(symbols: NumberSystemSymbols) -> Bool {
  symbols.decimal_separator == None
  && symbols.grouping_separator == None
  && symbols.minus_sign == None
  && symbols.decimal_format_pattern == None
}

fn parse_locale_number_system_data_raw(contents: String) {
  icurb.parse(contents, {
    use raw <- decode.optional_field(
      "NumberElements",
      dict.new(),
      decode.dict(decode.string, raw_ns_symbols_decoder()),
    )
    decode.success(raw)
  })
}

fn extract_ns_alias_target(target: String) -> Option(String) {
  case string.split(target, "/") {
    ["", "LOCALE", "NumberElements", ns, ..] -> Some(ns)
    _ -> None
  }
}

fn resolve_ns_alias_chain(
  selector: fn(RawNsSymbols) -> Option(icurb.Resolved(String)),
  same_file: dict.Dict(String, RawNsSymbols),
  root_file: dict.Dict(String, RawNsSymbols),
  ns_name: String,
  depth: Int,
) -> Option(String) {
  case depth >= 6 {
    True -> None
    False -> {
      let found = case dict.get(same_file, ns_name) {
        Ok(raw) -> Some(raw)
        Error(_) -> option.from_result(dict.get(root_file, ns_name))
      }
      case found {
        None -> None
        Some(raw) ->
          case selector(raw) {
            None -> None
            Some(icurb.Value(v)) -> Some(v)
            Some(icurb.AliasTo(target)) ->
              case extract_ns_alias_target(target) {
                None -> None
                Some(next_ns) ->
                  resolve_ns_alias_chain(
                    selector,
                    same_file,
                    root_file,
                    next_ns,
                    depth + 1,
                  )
              }
          }
      }
    }
  }
}

fn resolve_ns_field(
  selector: fn(RawNsSymbols) -> Option(icurb.Resolved(String)),
  same_file: dict.Dict(String, RawNsSymbols),
  root_file: dict.Dict(String, RawNsSymbols),
  ns_name: String,
) -> Option(String) {
  case dict.get(same_file, ns_name) {
    Error(_) -> None
    Ok(raw) ->
      case selector(raw) {
        None -> None
        Some(icurb.Value(v)) -> Some(v)
        Some(icurb.AliasTo(target)) ->
          case extract_ns_alias_target(target) {
            None -> None
            Some(target_ns) ->
              resolve_ns_alias_chain(
                selector,
                same_file,
                root_file,
                target_ns,
                0,
              )
          }
      }
  }
}

fn build_ns_symbols(
  same_file: dict.Dict(String, RawNsSymbols),
  root_file: dict.Dict(String, RawNsSymbols),
  ns_name: String,
) -> NumberSystemSymbols {
  NumberSystemSymbols(
    decimal_separator: resolve_ns_field(
      fn(r) { r.decimal_separator },
      same_file,
      root_file,
      ns_name,
    ),
    grouping_separator: resolve_ns_field(
      fn(r) { r.grouping_separator },
      same_file,
      root_file,
      ns_name,
    ),
    minus_sign: resolve_ns_field(
      fn(r) { r.minus_sign },
      same_file,
      root_file,
      ns_name,
    ),
    decimal_format_pattern: resolve_ns_field(
      fn(r) { r.decimal_format_pattern },
      same_file,
      root_file,
      ns_name,
    ),
  )
}

fn resolve_ns_dict(
  same_file: dict.Dict(String, RawNsSymbols),
  root_file: dict.Dict(String, RawNsSymbols),
) -> dict.Dict(String, NumberSystemSymbols) {
  dict.fold(same_file, dict.new(), fn(acc, ns_name, _raw) {
    let symbols = build_ns_symbols(same_file, root_file, ns_name)
    case is_empty_ns_symbols(symbols) {
      True -> acc
      False -> dict.insert(acc, ns_name, symbols)
    }
  })
}

pub fn generate(icu_path: String) {
  let names = shared.locale_names(icu_path)
  let #(raw_locales, failed) =
    list.fold(names, #(dict.new(), []), fn(state, name) {
      let #(raw_locales, failed) = state
      let assert Ok(contents) =
        simplifile.read(shared.locales_dir(icu_path) <> "/" <> name <> ".txt")
      case parse_locale_number_system_data_raw(contents) {
        Ok(by_ns) -> #(dict.insert(raw_locales, name, by_ns), failed)
        Error(_) -> #(raw_locales, [name, ..failed])
      }
    })
  log.parse_failures("Number system data parsing", failed)

  let assert Ok(root_ns) = dict.get(raw_locales, "root")

  let locales =
    dict.fold(raw_locales, dict.new(), fn(acc, name, by_ns) {
      let resolved = resolve_ns_dict(by_ns, root_ns)
      case dict.is_empty(resolved) {
        True -> acc
        False -> dict.insert(acc, name, resolved)
      }
    })
  NumberSystemDataByLocale(locales:)
}
