import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/string
import intldate/internal/icu/icudata/resource.{type TimezoneTypes}
import intldate/internal/icu/locale/uloc_keytype
import intldate_generate/icurb
import intldate_generate/save
import simplifile

type RawKeyTypeData {
  RawKeyTypeData(
    key_map: dict.Dict(String, String),
    type_map: dict.Dict(String, dict.Dict(String, String)),
    type_alias: dict.Dict(String, dict.Dict(String, String)),
    bcp_type_alias: dict.Dict(String, dict.Dict(String, String)),
  )
}

pub fn generate(icu_path: String, timezone_types: TimezoneTypes) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/keyTypeData.txt")

  let assert Ok(raw) = parse_key_type_data_raw(contents)
  let data = build_loc_ext_key_map(raw, timezone_types)
  save.save_loc_ext_key_map(data)
  data
}

fn alias_tolerant_table_dict() -> decode.Decoder(
  dict.Dict(String, dict.Dict(String, String)),
) {
  // A handful of per-key subtables (namely the "timezone"/"tz" ones) are
  // `:alias{...}` entries pointing into timezoneTypes.txt rather than
  // literal tables, so they decode as a plain string instead of a dict.
  decode.dict(
    decode.string,
    decode.one_of(decode.dict(decode.string, decode.string), [
      {
        use _alias <- decode.then(decode.string)
        decode.success(dict.new())
      },
    ]),
  )
}

fn parse_key_type_data_raw(contents: String) {
  icurb.parse(contents, {
    use key_map <- decode.field(
      "keyMap",
      decode.dict(decode.string, decode.string),
    )
    use type_map <- decode.field("typeMap", alias_tolerant_table_dict())
    use type_alias <- decode.field("typeAlias", alias_tolerant_table_dict())
    use bcp_type_alias <- decode.field(
      "bcpTypeAlias",
      alias_tolerant_table_dict(),
    )

    decode.success(RawKeyTypeData(
      key_map:,
      type_map:,
      type_alias:,
      bcp_type_alias:,
    ))
  })
}

fn build_loc_ext_key_map(
  raw: RawKeyTypeData,
  timezone_types: resource.TimezoneTypes,
) -> resource.LocExtKeyMap {
  let type_map =
    dict.insert(raw.type_map, "timezone", timezone_types.type_map_timezone)
  let type_alias =
    dict.insert(raw.type_alias, "timezone", timezone_types.type_alias_timezone)
  let bcp_type_alias =
    dict.insert(raw.bcp_type_alias, "tz", timezone_types.bcp_type_alias_tz)

  build_key_map(
    dict.to_list(raw.key_map),
    type_map,
    type_alias,
    bcp_type_alias,
    dict.new(),
  )
}

fn build_key_map(
  entries: List(#(String, String)),
  type_map: dict.Dict(String, dict.Dict(String, String)),
  type_alias: dict.Dict(String, dict.Dict(String, String)),
  bcp_type_alias: dict.Dict(String, dict.Dict(String, String)),
  acc: resource.LocExtKeyMap,
) -> resource.LocExtKeyMap {
  case entries {
    [] -> acc
    [#(legacy_key_id, key_map_value), ..rest] -> {
      let bcp_key_id = case key_map_value {
        "" -> legacy_key_id
        _ -> key_map_value
      }
      let is_tz = legacy_key_id == "timezone"

      let #(type_data_map, special_types) =
        build_type_data_map(
          dict.get(type_map, legacy_key_id),
          dict.get(type_alias, legacy_key_id),
          dict.get(bcp_type_alias, bcp_key_id),
          is_tz,
        )

      let key_data =
        uloc_keytype.create_loc_ext_key_data(
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

      build_key_map(rest, type_map, type_alias, bcp_type_alias, acc)
    }
  }
}

fn build_type_data_map(
  type_map_by_key: Result(dict.Dict(String, String), Nil),
  type_alias_by_key: Result(dict.Dict(String, String), Nil),
  bcp_type_alias_by_key: Result(dict.Dict(String, String), Nil),
  is_tz: Bool,
) -> #(dict.Dict(String, resource.LocExtType), Int) {
  case type_map_by_key {
    Error(_) -> #(dict.new(), uloc_keytype.specialtype_none)
    Ok(table) ->
      build_type_data_map_loop(
        dict.to_list(table),
        type_alias_by_key,
        bcp_type_alias_by_key,
        is_tz,
        dict.new(),
        uloc_keytype.specialtype_none,
      )
  }
}

fn build_type_data_map_loop(
  entries: List(#(String, String)),
  type_alias_by_key: Result(dict.Dict(String, String), Nil),
  bcp_type_alias_by_key: Result(dict.Dict(String, String), Nil),
  is_tz: Bool,
  type_data_map: dict.Dict(String, resource.LocExtType),
  special_types: Int,
) -> #(dict.Dict(String, resource.LocExtType), Int) {
  case entries {
    [] -> #(type_data_map, special_types)
    [#(legacy_type_id, type_map_value), ..rest] ->
      case legacy_type_id {
        "CODEPOINTS" ->
          build_type_data_map_loop(
            rest,
            type_alias_by_key,
            bcp_type_alias_by_key,
            is_tz,
            type_data_map,
            int.bitwise_or(special_types, uloc_keytype.specialtype_codepoints),
          )
        "REORDER_CODE" ->
          build_type_data_map_loop(
            rest,
            type_alias_by_key,
            bcp_type_alias_by_key,
            is_tz,
            type_data_map,
            int.bitwise_or(special_types, uloc_keytype.specialtype_reorder_code),
          )
        "RG_KEY_VALUE" ->
          build_type_data_map_loop(
            rest,
            type_alias_by_key,
            bcp_type_alias_by_key,
            is_tz,
            type_data_map,
            int.bitwise_or(special_types, uloc_keytype.specialtype_rg_key_value),
          )
        _ -> {
          let legacy_type_id =
            uloc_keytype.normalize_type_name(is_tz, legacy_type_id)
          let bcp_type_id = case type_map_value {
            "" -> legacy_type_id
            _ -> type_map_value
          }
          let t = uloc_keytype.create_loc_ext_type(legacy_type_id, bcp_type_id)
          let type_data_map = dict.insert(type_data_map, t.legacy_id, t)
          let type_data_map = case t.bcp_id != t.legacy_id {
            True -> dict.insert(type_data_map, t.bcp_id, t)
            False -> type_data_map
          }
          let type_data_map =
            add_type_alias(
              type_data_map,
              type_alias_by_key,
              t.legacy_id,
              t,
              is_tz,
            )
          let type_data_map =
            add_type_alias(
              type_data_map,
              bcp_type_alias_by_key,
              t.bcp_id,
              t,
              False,
            )
          build_type_data_map_loop(
            rest,
            type_alias_by_key,
            bcp_type_alias_by_key,
            is_tz,
            type_data_map,
            special_types,
          )
        }
      }
  }
}

fn add_type_alias(
  type_data_map: dict.Dict(String, resource.LocExtType),
  alias_table: Result(dict.Dict(String, String), Nil),
  target_id: String,
  target: resource.LocExtType,
  is_tz: Bool,
) -> dict.Dict(String, resource.LocExtType) {
  case alias_table {
    Error(_) -> type_data_map
    Ok(table) ->
      add_type_alias_loop(
        dict.to_list(table),
        type_data_map,
        target_id,
        target,
        is_tz,
      )
  }
}

fn add_type_alias_loop(
  entries: List(#(String, String)),
  type_data_map: dict.Dict(String, resource.LocExtType),
  target_id: String,
  target: resource.LocExtType,
  is_tz: Bool,
) -> dict.Dict(String, resource.LocExtType) {
  case entries {
    [] -> type_data_map
    [#(from, to), ..rest] ->
      case to != target_id {
        True ->
          add_type_alias_loop(rest, type_data_map, target_id, target, is_tz)
        False -> {
          let from = case is_tz && string.contains(from, ":") {
            True -> string.replace(from, ":", "/")
            False -> from
          }
          add_type_alias_loop(
            rest,
            dict.insert(type_data_map, from, target),
            target_id,
            target,
            is_tz,
          )
        }
      }
  }
}
