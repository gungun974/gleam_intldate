import gleam/dict.{type Dict}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resource.{
  type LocExtKeyData, type LocExtKeyMap, type LocExtType, LocExtKeyData,
  LocExtType,
}

pub const specialtype_none = 0

pub const specialtype_codepoints = 1

pub const specialtype_reorder_code = 2

pub const specialtype_rg_key_value = 4

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

pub fn ulocimp_to_bcp_key(
  key_map: LocExtKeyMap,
  key: Option(String),
) -> Option(String) {
  case map_get_ignore_case(key_map, key) {
    Some(key_data) -> Some(key_data.bcp_id)
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

pub fn ulocimp_to_bcp_type(
  key_map: LocExtKeyMap,
  key: Option(String),
  type_: String,
) -> Option(String) {
  case map_get_ignore_case(key_map, key) {
    None -> None
    Some(key_data) ->
      case map_get_ignore_case(key_data.type_map, Some(type_)) {
        Some(t) -> Some(t.bcp_id)
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
