import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/icudata/uresimp
import intldate/internal/icu/locale/uloc

const default_digits = "0123456789"

const g_default = "default"

const g_native = "native"

const g_traditional = "traditional"

const g_finance = "finance"

const g_latn = "latn"

pub type NumberingSystem {
  NumberingSystem(radix: Int, algorithmic: Bool, desc: String, name: String)
}

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

fn resource_string_text(rd: resource.ResourceData, res: Int) -> Option(String) {
  case
    resource.resource_value_get_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> Some(s.text)
    None -> None
  }
}

fn table_keys_and_res(
  table: resource.ResourceTableView,
) -> List(#(String, Int)) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      table_keys_and_res_loop(get_key, get_res, 0, table.length)
    _, _ -> []
  }
}

fn table_keys_and_res_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(#(String, Int)) {
  case i >= length {
    True -> []
    False -> [
      #(get_key(i), get_res(i)),
      ..table_keys_and_res_loop(get_key, get_res, i + 1, length)
    ]
  }
}

pub fn numbering_system_create_instance_by_name(
  bundle: Bundle,
  name: String,
) -> Result(NumberingSystem, String) {
  case resbund.open_direct(bundle, "numberingSystems") {
    None -> Error("U_UNSUPPORTED_ERROR")
    Some(rd) -> {
      let chain = [resbund.LocaleChainEntry("numberingSystems", Some(rd))]
      case resbund.get_by_path(bundle, chain, "numberingSystems/" <> name, 0) {
        None -> Error("U_UNSUPPORTED_ERROR")
        Some(found) -> {
          let table = resource.get_table(found.res_data, found.res)
          let entries = table_keys_and_res(table)
          let #(nsd, radix, algorithmic) =
            read_ns_fields(found.res_data, entries, None, 10, 0)
          case nsd {
            None -> Error("U_UNSUPPORTED_ERROR")
            Some(desc) ->
              case
                numbering_system_create_instance3(radix, algorithmic == 1, desc)
              {
                Error(e) -> Error(e)
                Ok(ns) -> Ok(with_name(ns, name))
              }
          }
        }
      }
    }
  }
}

fn read_ns_fields(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
  nsd: Option(String),
  radix: Int,
  algorithmic: Int,
) -> #(Option(String), Int, Int) {
  case entries {
    [] -> #(nsd, radix, algorithmic)
    [#(key, res), ..rest] ->
      case key {
        "desc" ->
          read_ns_fields(
            rd,
            rest,
            resource_string_text(rd, res),
            radix,
            algorithmic,
          )
        "radix" ->
          case uresimp.res_get_type(res) == uresimp.ResInt {
            True ->
              read_ns_fields(
                rd,
                rest,
                nsd,
                resource.resource_value_get_int(resource.create_resource_value(
                  Some(rd),
                  res,
                )),
                algorithmic,
              )
            False -> read_ns_fields(rd, rest, nsd, radix, algorithmic)
          }
        "algorithmic" ->
          case uresimp.res_get_type(res) == uresimp.ResInt {
            True ->
              read_ns_fields(
                rd,
                rest,
                nsd,
                radix,
                resource.resource_value_get_int(resource.create_resource_value(
                  Some(rd),
                  res,
                )),
              )
            False -> read_ns_fields(rd, rest, nsd, radix, algorithmic)
          }
        _ -> read_ns_fields(rd, rest, nsd, radix, algorithmic)
      }
  }
}

fn get_string_by_key_with_fallback_from_chain(
  bundle: Bundle,
  chain: List(resbund.LocaleChainEntry),
  table_key: String,
  item_key: String,
) -> Option(String) {
  case chain {
    [] -> None
    [level, ..rest] ->
      case
        resbund.get_by_path(bundle, [level], table_key <> "/" <> item_key, 0)
      {
        None ->
          get_string_by_key_with_fallback_from_chain(
            bundle,
            rest,
            table_key,
            item_key,
          )
        Some(found) ->
          case
            resource.resource_value_get_string(resource.create_resource_value(
              Some(found.res_data),
              found.res,
            ))
          {
            Some(s) if s.length > 0 -> Some(s.text)
            _ ->
              get_string_by_key_with_fallback_from_chain(
                bundle,
                rest,
                table_key,
                item_key,
              )
          }
      }
  }
}

fn get_string_by_key_with_fallback(
  bundle: Bundle,
  locale_id: String,
  table_key: String,
  item_key: String,
) -> Option(String) {
  let chain =
    resbund.open_locale_chain(bundle, uloc.get_base_name(Some(locale_id)))
  get_string_by_key_with_fallback_from_chain(bundle, chain, table_key, item_key)
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
      case
        get_string_by_key_with_fallback(
          bundle,
          locale_id,
          "NumberElements",
          state.buffer,
        )
      {
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
