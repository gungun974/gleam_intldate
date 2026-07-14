import gleam/dict.{type Dict}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

pub const specialtype_none = 0

pub const specialtype_codepoints = 1

pub const specialtype_reorder_code = 2

pub const specialtype_rg_key_value = 4

pub type LocExtType {
  LocExtType(legacy_id: String, bcp_id: String)
}

pub type LocExtKeyData {
  LocExtKeyData(
    legacy_id: String,
    bcp_id: String,
    type_map: Dict(String, LocExtType),
    special_types: Int,
  )
}

pub type LocExtKeyMap =
  Dict(String, LocExtKeyData)

pub type ResourceTableView {
  ResourceTableView(
    length: Int,
    get_key: fn(Int) -> String,
    get_res: fn(Int) -> Int,
  )
}

pub type ResourceData {
  ResourceData(
    get_table: fn(Int) -> ResourceTableView,
    get_table_safe: fn(Int) -> Option(ResourceTableView),
    get_string: fn(Int) -> ResourceStringResult,
  )
}

pub type ResourceStringResult {
  ResourceStringResult(text: Option(String))
}

pub type Bundle {
  Bundle(open_direct: fn(String) -> ResourceData, root_res: Int)
}

pub fn create_loc_ext_key_data(
  legacy_id: String,
  bcp_id: String,
  type_map: Dict(String, LocExtType),
  special_types: Int,
) -> LocExtKeyData {
  LocExtKeyData(legacy_id:, bcp_id:, type_map:, special_types:)
}

pub fn create_loc_ext_type(legacy_id: String, bcp_id: String) -> LocExtType {
  LocExtType(legacy_id:, bcp_id:)
}

fn code_points(s: String) -> List(String) {
  string.to_graphemes(s)
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

pub fn is_special_type_codepoints(val: String) -> Bool {
  is_special_type_codepoints_loop(code_points(val), 0)
}

fn is_hex_digit(c: String) -> Bool {
  let code = char_code(c)
  { code >= 48 && code <= 57 }
  || { code >= 65 && code <= 70 }
  || { code >= 97 && code <= 102 }
}

fn is_special_type_codepoints_loop(
  chars: List(String),
  subtag_len: Int,
) -> Bool {
  case chars {
    [] -> subtag_len >= 4 && subtag_len <= 6
    [c, ..rest] ->
      case c == "-" {
        True ->
          case subtag_len < 4 || subtag_len > 6 {
            True -> False
            False -> is_special_type_codepoints_loop(rest, 0)
          }
        False ->
          case is_hex_digit(c) {
            True -> is_special_type_codepoints_loop(rest, subtag_len + 1)
            False -> False
          }
      }
  }
}

pub fn is_special_type_reorder_code(val: String) -> Bool {
  is_special_type_reorder_code_loop(code_points(val), 0)
}

fn is_alpha(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn is_digit(c: String) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
}

fn is_special_type_reorder_code_loop(
  chars: List(String),
  subtag_len: Int,
) -> Bool {
  case chars {
    [] -> subtag_len >= 3 && subtag_len <= 8
    [c, ..rest] ->
      case c == "-" {
        True ->
          case subtag_len < 3 || subtag_len > 8 {
            True -> False
            False -> is_special_type_reorder_code_loop(rest, 0)
          }
        False ->
          case is_alpha(c) {
            True -> is_special_type_reorder_code_loop(rest, subtag_len + 1)
            False -> False
          }
      }
  }
}

pub fn is_special_type_rg_key_value(val: String) -> Bool {
  is_special_type_rg_key_value_loop(code_points(val), 0)
}

fn is_special_type_rg_key_value_loop(
  chars: List(String),
  subtag_len: Int,
) -> Bool {
  case chars {
    [] -> subtag_len == 6
    [c, ..rest] ->
      case subtag_len < 2 && is_alpha(c) {
        True -> is_special_type_rg_key_value_loop(rest, subtag_len + 1)
        False ->
          case subtag_len >= 2 && { c == "Z" || c == "z" } {
            True -> is_special_type_rg_key_value_loop(rest, subtag_len + 1)
            False -> False
          }
      }
  }
}

pub fn normalize_type_name(is_tz: Bool, name: String) -> String {
  case !is_tz || !string.contains(name, ":") {
    True -> name
    False -> string.replace(name, ":", "/")
  }
}

fn table_index_find(
  table: ResourceTableView,
  key: String,
  i: Int,
) -> Option(Int) {
  case i >= table.length {
    True -> None
    False ->
      case table.get_key(i) == key {
        True -> Some(i)
        False -> table_index_find(table, key, i + 1)
      }
  }
}

pub fn get_table_by_key(
  rd: ResourceData,
  table_res: Int,
  key: String,
) -> Option(ResourceTableView) {
  let table = rd.get_table(table_res)
  case table_index_find(table, key, 0) {
    None -> None
    Some(i) -> rd.get_table_safe(table.get_res(i))
  }
}

pub fn rd_get_string(rd: ResourceData, res: Int) -> String {
  case rd.get_string(res).text {
    None -> ""
    Some("") -> ""
    Some(s) -> s
  }
}

fn add_type_alias_loop(
  rd: ResourceData,
  type_data_map: Dict(String, LocExtType),
  alias_table: ResourceTableView,
  target_id: String,
  target: LocExtType,
  is_tz: Bool,
  i: Int,
) -> Dict(String, LocExtType) {
  case i >= alias_table.length {
    True -> type_data_map
    False -> {
      let to = rd_get_string(rd, alias_table.get_res(i))
      case to != target_id {
        True ->
          add_type_alias_loop(
            rd,
            type_data_map,
            alias_table,
            target_id,
            target,
            is_tz,
            i + 1,
          )
        False -> {
          let from = alias_table.get_key(i)
          let from = case is_tz && string.contains(from, ":") {
            True -> string.replace(from, ":", "/")
            False -> from
          }
          add_type_alias_loop(
            rd,
            dict.insert(type_data_map, from, target),
            alias_table,
            target_id,
            target,
            is_tz,
            i + 1,
          )
        }
      }
    }
  }
}

pub fn add_type_alias(
  rd: ResourceData,
  type_data_map: Dict(String, LocExtType),
  alias_table: Option(ResourceTableView),
  target_id: String,
  target: LocExtType,
  is_tz: Bool,
) -> Dict(String, LocExtType) {
  case alias_table {
    None -> type_data_map
    Some(table) ->
      add_type_alias_loop(rd, type_data_map, table, target_id, target, is_tz, 0)
  }
}

type RootKeys {
  RootKeys(
    key_map_res: Option(Int),
    type_map_res: Option(Int),
    type_alias_res: Option(Int),
    bcp_type_alias_res: Option(Int),
  )
}

fn find_root_keys_loop(
  root: ResourceTableView,
  i: Int,
  acc: RootKeys,
) -> RootKeys {
  case i >= root.length {
    True -> acc
    False -> {
      let key = root.get_key(i)
      let res = root.get_res(i)
      let acc = case key {
        "keyMap" -> RootKeys(..acc, key_map_res: Some(res))
        "typeMap" -> RootKeys(..acc, type_map_res: Some(res))
        "typeAlias" -> RootKeys(..acc, type_alias_res: Some(res))
        "bcpTypeAlias" -> RootKeys(..acc, bcp_type_alias_res: Some(res))
        _ -> acc
      }
      find_root_keys_loop(root, i + 1, acc)
    }
  }
}

fn build_type_data_map(
  key_type_data_res: ResourceData,
  type_map_res_by_key: Option(ResourceTableView),
  type_alias_res_by_key: Option(ResourceTableView),
  bcp_type_alias_res_by_key: Option(ResourceTableView),
  is_tz: Bool,
) -> #(Dict(String, LocExtType), Int) {
  case type_map_res_by_key {
    None -> #(dict.new(), specialtype_none)
    Some(table) ->
      build_type_data_map_loop(
        key_type_data_res,
        table,
        type_alias_res_by_key,
        bcp_type_alias_res_by_key,
        is_tz,
        0,
        dict.new(),
        specialtype_none,
      )
  }
}

fn build_type_data_map_loop(
  rd: ResourceData,
  table: ResourceTableView,
  type_alias_res_by_key: Option(ResourceTableView),
  bcp_type_alias_res_by_key: Option(ResourceTableView),
  is_tz: Bool,
  j: Int,
  type_data_map: Dict(String, LocExtType),
  special_types: Int,
) -> #(Dict(String, LocExtType), Int) {
  case j >= table.length {
    True -> #(type_data_map, special_types)
    False -> {
      let legacy_type_id = table.get_key(j)
      case legacy_type_id {
        "CODEPOINTS" ->
          build_type_data_map_loop(
            rd,
            table,
            type_alias_res_by_key,
            bcp_type_alias_res_by_key,
            is_tz,
            j + 1,
            type_data_map,
            int.bitwise_or(special_types, specialtype_codepoints),
          )
        "REORDER_CODE" ->
          build_type_data_map_loop(
            rd,
            table,
            type_alias_res_by_key,
            bcp_type_alias_res_by_key,
            is_tz,
            j + 1,
            type_data_map,
            int.bitwise_or(special_types, specialtype_reorder_code),
          )
        "RG_KEY_VALUE" ->
          build_type_data_map_loop(
            rd,
            table,
            type_alias_res_by_key,
            bcp_type_alias_res_by_key,
            is_tz,
            j + 1,
            type_data_map,
            int.bitwise_or(special_types, specialtype_rg_key_value),
          )
        _ -> {
          let legacy_type_id = normalize_type_name(is_tz, legacy_type_id)
          let type_map_value = rd_get_string(rd, table.get_res(j))
          let bcp_type_id = case type_map_value {
            "" -> legacy_type_id
            _ -> type_map_value
          }
          let t = create_loc_ext_type(legacy_type_id, bcp_type_id)
          let type_data_map = dict.insert(type_data_map, t.legacy_id, t)
          let type_data_map = case t.bcp_id != t.legacy_id {
            True -> dict.insert(type_data_map, t.bcp_id, t)
            False -> type_data_map
          }
          let type_data_map =
            add_type_alias(
              rd,
              type_data_map,
              type_alias_res_by_key,
              t.legacy_id,
              t,
              is_tz,
            )
          let type_data_map =
            add_type_alias(
              rd,
              type_data_map,
              bcp_type_alias_res_by_key,
              t.bcp_id,
              t,
              False,
            )
          build_type_data_map_loop(
            rd,
            table,
            type_alias_res_by_key,
            bcp_type_alias_res_by_key,
            is_tz,
            j + 1,
            type_data_map,
            special_types,
          )
        }
      }
    }
  }
}

fn build_key_map_loop(
  key_type_data_res: ResourceData,
  key_map: ResourceTableView,
  type_map_res: Option(Int),
  type_alias_res: Option(Int),
  bcp_type_alias_res: Option(Int),
  i: Int,
  acc: LocExtKeyMap,
) -> LocExtKeyMap {
  case i >= key_map.length {
    True -> acc
    False -> {
      let legacy_key_id = key_map.get_key(i)
      let key_map_value = rd_get_string(key_type_data_res, key_map.get_res(i))
      let bcp_key_id = case key_map_value {
        "" -> legacy_key_id
        _ -> key_map_value
      }
      let is_tz = legacy_key_id == "timezone"

      let type_alias_res_by_key = case type_alias_res {
        None -> None
        Some(res) -> get_table_by_key(key_type_data_res, res, legacy_key_id)
      }
      let bcp_type_alias_res_by_key = case bcp_type_alias_res {
        None -> None
        Some(res) -> get_table_by_key(key_type_data_res, res, bcp_key_id)
      }
      let type_map_res_by_key = case type_map_res {
        None -> None
        Some(res) -> get_table_by_key(key_type_data_res, res, legacy_key_id)
      }

      let #(type_data_map, special_types) =
        build_type_data_map(
          key_type_data_res,
          type_map_res_by_key,
          type_alias_res_by_key,
          bcp_type_alias_res_by_key,
          is_tz,
        )

      let key_data =
        create_loc_ext_key_data(
          legacy_key_id,
          bcp_key_id,
          type_data_map,
          special_types,
        )

      let acc = dict.insert(acc, key_data.legacy_id, key_data)
      let acc = case key_data.legacy_id != key_data.bcp_id {
        True -> dict.insert(acc, key_data.bcp_id, key_data)
        False -> acc
      }

      build_key_map_loop(
        key_type_data_res,
        key_map,
        type_map_res,
        type_alias_res,
        bcp_type_alias_res,
        i + 1,
        acc,
      )
    }
  }
}

pub fn init_from_resource_bundle(bundle: Bundle) -> LocExtKeyMap {
  let key_type_data_res = bundle.open_direct("keyTypeData")
  let root = key_type_data_res.get_table(bundle.root_res)
  let keys =
    find_root_keys_loop(
      root,
      0,
      RootKeys(
        key_map_res: None,
        type_map_res: None,
        type_alias_res: None,
        bcp_type_alias_res: None,
      ),
    )

  let assert Some(key_map_res) = keys.key_map_res
  let key_map = key_type_data_res.get_table(key_map_res)

  build_key_map_loop(
    key_type_data_res,
    key_map,
    keys.type_map_res,
    keys.type_alias_res,
    keys.bcp_type_alias_res,
    0,
    dict.new(),
  )
}

pub fn map_get_ignore_case(
  map: Dict(String, a),
  key: Option(String),
) -> Option(a) {
  case key {
    None -> None
    Some(k) ->
      case dict.get(map, k) {
        Ok(v) -> Some(v)
        Error(_) -> {
          let lower = string.lowercase(k)
          case lower == k {
            True -> None
            False ->
              case dict.get(map, lower) {
                Ok(v) -> Some(v)
                Error(_) -> None
              }
          }
        }
      }
  }
}

pub fn ulocimp_to_legacy_key(
  key_map: LocExtKeyMap,
  key: Option(String),
) -> Option(String) {
  case map_get_ignore_case(key_map, key) {
    Some(key_data) -> Some(key_data.legacy_id)
    None -> None
  }
}

pub fn get_type_special_value(
  key_data: LocExtKeyData,
  type_: String,
) -> Option(String) {
  case key_data.special_types == specialtype_none {
    True -> None
    False -> {
      let matched =
        int.bitwise_and(key_data.special_types, specialtype_codepoints) != 0
        && is_special_type_codepoints(type_)
      let matched = case matched {
        True -> True
        False ->
          int.bitwise_and(key_data.special_types, specialtype_reorder_code) != 0
          && is_special_type_reorder_code(type_)
      }
      let matched = case matched {
        True -> True
        False ->
          int.bitwise_and(key_data.special_types, specialtype_rg_key_value) != 0
          && is_special_type_rg_key_value(type_)
      }
      case matched {
        True -> Some(type_)
        False -> None
      }
    }
  }
}

pub fn ulocimp_to_legacy_type(
  key_map: LocExtKeyMap,
  key: Option(String),
  type_: String,
) -> Option(String) {
  case map_get_ignore_case(key_map, key) {
    None -> None
    Some(key_data) ->
      case map_get_ignore_case(key_data.type_map, Some(type_)) {
        Some(t) -> Some(t.legacy_id)
        None -> get_type_special_value(key_data, type_)
      }
  }
}

pub fn is_well_formed_legacy_type(legacy_type: String) -> Bool {
  is_well_formed_legacy_type_loop(code_points(legacy_type), 0)
}

fn is_well_formed_legacy_type_loop(
  chars: List(String),
  alpha_num_len: Int,
) -> Bool {
  case chars {
    [] -> alpha_num_len != 0
    [c, ..rest] ->
      case c == "_" || c == "/" || c == "-" {
        True ->
          case alpha_num_len == 0 {
            True -> False
            False -> is_well_formed_legacy_type_loop(rest, 0)
          }
        False ->
          case is_alpha(c) || is_digit(c) {
            True -> is_well_formed_legacy_type_loop(rest, alpha_num_len + 1)
            False -> False
          }
      }
  }
}

pub fn is_well_formed_legacy_key(key: String) -> Bool {
  case key == "" {
    True -> False
    False -> is_well_formed_legacy_key_loop(code_points(key))
  }
}

fn is_well_formed_legacy_key_loop(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_alpha(c) || is_digit(c) {
        True -> is_well_formed_legacy_key_loop(rest)
        False -> False
      }
  }
}

pub fn ulocimp_to_legacy_key_with_fallback(
  key_map: LocExtKeyMap,
  key: String,
) -> Option(String) {
  case ulocimp_to_legacy_key(key_map, Some(key)) {
    None ->
      case is_well_formed_legacy_key(key) {
        True -> Some(key)
        False -> None
      }
    legacy_key -> legacy_key
  }
}

pub fn ulocimp_to_legacy_type_with_fallback(
  key_map: LocExtKeyMap,
  key: String,
  type_: String,
) -> Option(String) {
  case ulocimp_to_legacy_type(key_map, Some(key), type_) {
    None ->
      case is_well_formed_legacy_type(type_) {
        True -> Some(type_)
        False -> None
      }
    legacy_type -> legacy_type
  }
}
