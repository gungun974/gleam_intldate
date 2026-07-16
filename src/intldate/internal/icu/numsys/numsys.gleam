import gleam/dict
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/localechain
import intldate/internal/icu/icudata/resource.{
  type NumberingSystem, NumberingSystem,
}
import intldate/internal/icu/locale/uloc

const default_digits = "0123456789"

const g_default = "default"

const g_native = "native"

const g_traditional = "traditional"

const g_finance = "finance"

const g_latn = "latn"

pub fn create_numbering_system() -> NumberingSystem {
  NumberingSystem(
    radix: 10,
    algorithmic: False,
    desc: default_digits,
    name: g_latn,
  )
}

fn with_name(ns: NumberingSystem, name: String) -> NumberingSystem {
  NumberingSystem(..ns, name:)
}

pub fn numbering_system_create_instance3(
  radix_in: Int,
  is_algorithmic_in: Bool,
  desc_in: String,
) -> Result(NumberingSystem, String) {
  case radix_in < 2 {
    True -> Error("U_ILLEGAL_ARGUMENT_ERROR")
    False ->
      case !is_algorithmic_in && string.length(desc_in) != radix_in {
        True -> Error("U_ILLEGAL_ARGUMENT_ERROR")
        False ->
          Ok(with_name(
            NumberingSystem(
              radix: radix_in,
              algorithmic: is_algorithmic_in,
              desc: desc_in,
              name: g_latn,
            ),
            "",
          ))
      }
  }
}

pub fn numbering_system_create_instance_by_name(
  bundle: Bundle,
  name: String,
) -> Result(NumberingSystem, String) {
  let numbering_systems = bundle.numbering_systems

  case dict.get(numbering_systems.numbering_systems, name) {
    Ok(numbering_system) -> Ok(numbering_system)
    Error(_) -> Error("U_UNSUPPORTED_ERROR")
  }
}

fn find_number_elements_in_chain(
  locales: dict.Dict(String, dict.Dict(String, String)),
  chain: List(String),
  item_key: String,
) -> Option(String) {
  case chain {
    [] -> None
    [name, ..rest] ->
      case dict.get(locales, name) {
        Error(_) -> find_number_elements_in_chain(locales, rest, item_key)
        Ok(elements) ->
          case dict.get(elements, item_key) {
            Ok(value) if value != "" -> Some(value)
            _ -> find_number_elements_in_chain(locales, rest, item_key)
          }
      }
  }
}

fn get_string_by_key_with_fallback(
  bundle: Bundle,
  locale_id: String,
  item_key: String,
) -> Option(String) {
  let data = bundle.number_elements_by_locale
  let chain =
    localechain.locale_chain(
      bundle.locale_parents,
      uloc.get_base_name(Some(locale_id)),
    )
  find_number_elements_in_chain(data.locales, chain, item_key)
}

type ResolveState {
  ResolveState(buffer: String, resolved: Bool, using_fallback: Bool)
}

fn resolve_numbering_system_buffer(
  bundle: Bundle,
  locale_id: String,
  state: ResolveState,
) -> ResolveState {
  case state.resolved {
    True -> state
    False ->
      case get_string_by_key_with_fallback(bundle, locale_id, state.buffer) {
        Some(ns_name) if ns_name != "" ->
          ResolveState(..state, buffer: ns_name, resolved: True)
        _ ->
          case state.buffer {
            "native" | "finance" ->
              resolve_numbering_system_buffer(
                bundle,
                locale_id,
                ResolveState(..state, buffer: g_default),
              )
            "traditional" ->
              resolve_numbering_system_buffer(
                bundle,
                locale_id,
                ResolveState(..state, buffer: g_native),
              )
            _ -> ResolveState(..state, resolved: True, using_fallback: True)
          }
      }
  }
}

pub fn numbering_system_create_instance_for_locale(
  bundle: Bundle,
  in_locale: String,
) -> NumberingSystem {
  let keyword_value = uloc.get_keyword_value(Some(in_locale), "numbers")
  let initial = case keyword_value {
    "" -> ResolveState(g_default, False, False)
    v ->
      case
        v == g_default || v == g_native || v == g_traditional || v == g_finance
      {
        True -> ResolveState(v, False, False)
        False -> ResolveState(v, True, False)
      }
  }

  let final_state = resolve_numbering_system_buffer(bundle, in_locale, initial)

  case final_state.using_fallback {
    True -> create_numbering_system()
    False ->
      case
        numbering_system_create_instance_by_name(bundle, final_state.buffer)
      {
        Ok(ns) -> ns
        Error(_) -> create_numbering_system()
      }
  }
}

pub fn numbering_system_get_description(ns: NumberingSystem) -> String {
  ns.desc
}

pub fn numbering_system_get_name(ns: NumberingSystem) -> String {
  ns.name
}

pub fn numbering_system_is_algorithmic(ns: NumberingSystem) -> Bool {
  ns.algorithmic
}

pub fn create_instance_for_locale(
  bundle: Bundle,
  locale_id: String,
) -> NumberingSystem {
  numbering_system_create_instance_for_locale(bundle, locale_id)
}
