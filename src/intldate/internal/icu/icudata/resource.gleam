import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/uresimp

pub type Node {
  NTable(by_key: Dict(String, Int), by_index: Dict(Int, String), length: Int)
  NArray(by_index: Dict(Int, Int), length: Int)
  NString(text: String)
  NAlias(text: String)
  NIntVector(values: List(Int))
  NBinary(bytes: BitArray)
}

pub type ResourceData {
  ResourceData(
    arena: Dict(Int, Node),
    root_res: Int,
    no_fallback: Bool,
    uses_pool_bundle: Bool,
  )
}

pub type ResourceString {
  ResourceString(text: String, length: Int)
}

pub type ResourceTableView {
  ResourceTableView(
    length: Int,
    get_key: Option(fn(Int) -> String),
    get_res: Option(fn(Int) -> Int),
  )
}

pub type ResourceArrayView {
  ResourceArrayView(length: Int, get_res: Option(fn(Int) -> Int))
}

pub type ResourceValue {
  ResourceValue(data: Option(ResourceData), res: Int)
}

pub fn create_resource_value(
  data: Option(ResourceData),
  res: Int,
) -> ResourceValue {
  ResourceValue(data:, res:)
}

pub fn resource_value_get_string(
  value: ResourceValue,
) -> Option(ResourceString) {
  case value.data {
    None -> None
    Some(data) -> get_string(data, value.res)
  }
}

pub fn resource_value_get_alias_string(
  value: ResourceValue,
) -> Option(ResourceString) {
  case value.data {
    None -> None
    Some(data) -> get_alias(data, value.res)
  }
}

pub fn resource_value_get_int(value: ResourceValue) -> Int {
  get_int(value.res)
}

pub fn resource_value_get_array(
  value: ResourceValue,
) -> Option(ResourceArrayView) {
  case value.data {
    None -> None
    Some(data) -> get_array_safe(data, value.res)
  }
}

pub fn resource_value_get_binary(value: ResourceValue) -> Option(BitArray) {
  case value.data {
    None -> None
    Some(data) -> get_binary(data, value.res)
  }
}

pub fn resource_value_get_int_vector(
  value: ResourceValue,
) -> Option(List(Int)) {
  case value.data {
    None -> None
    Some(data) -> get_int_vector(data, value.res)
  }
}

fn find_node(rd: ResourceData, res: Int) -> Option(Node) {
  case dict.get(rd.arena, uresimp.res_get_offset(res)) {
    Ok(node) -> Some(node)
    Error(_) -> None
  }
}

fn get_string(rd: ResourceData, res: Int) -> Option(ResourceString) {
  case find_node(rd, res) {
    Some(NString(text)) -> Some(ResourceString(text, string.length(text)))
    _ -> None
  }
}

fn get_alias(rd: ResourceData, res: Int) -> Option(ResourceString) {
  case find_node(rd, res) {
    Some(NAlias(text)) -> Some(ResourceString(text, string.length(text)))
    _ -> None
  }
}

fn get_binary(rd: ResourceData, res: Int) -> Option(BitArray) {
  case find_node(rd, res) {
    Some(NBinary(bytes)) -> Some(bytes)
    _ -> None
  }
}

fn get_int_vector(rd: ResourceData, res: Int) -> Option(List(Int)) {
  case find_node(rd, res) {
    Some(NIntVector(values)) -> Some(values)
    _ -> None
  }
}

fn get_int(res: Int) -> Int {
  let raw = uresimp.res_get_offset(res)
  case raw >= 0x8000000 {
    True -> raw - 0x10000000
    False -> raw
  }
}

pub fn get_table(rd: ResourceData, res: Int) -> ResourceTableView {
  case find_node(rd, res) {
    Some(NTable(by_key:, by_index:, length:)) ->
      ResourceTableView(
        length,
        Some(fn(i) {
          let assert Ok(key) = dict.get(by_index, i)
          key
        }),
        Some(fn(i) {
          let assert Ok(key) = dict.get(by_index, i)
          let assert Ok(item_res) = dict.get(by_key, key)
          item_res
        }),
      )
    _ -> panic as "resource is not a table"
  }
}

pub fn get_table_safe(rd: ResourceData, res: Int) -> Option(ResourceTableView) {
  case find_node(rd, res) {
    Some(NTable(..)) -> Some(get_table(rd, res))
    _ -> None
  }
}

pub fn get_array(rd: ResourceData, res: Int) -> ResourceArrayView {
  case find_node(rd, res) {
    Some(NArray(by_index:, length:)) ->
      ResourceArrayView(
        length,
        Some(fn(i) {
          let assert Ok(item_res) = dict.get(by_index, i)
          item_res
        }),
      )
    _ -> panic as "resource is not an array"
  }
}

fn get_array_safe(rd: ResourceData, res: Int) -> Option(ResourceArrayView) {
  case find_node(rd, res) {
    Some(NArray(..)) -> Some(get_array(rd, res))
    _ -> None
  }
}

pub fn get_table_item_by_key(rd: ResourceData, table: Int, key: String) -> Int {
  case find_node(rd, table) {
    Some(NTable(by_key:, ..)) ->
      case dict.get(by_key, key) {
        Ok(item_res) -> item_res
        Error(_) -> uresimp.res_bogus
      }
    _ -> uresimp.res_bogus
  }
}

pub fn get_resource(rd: ResourceData, key: String) -> Int {
  get_table_item_by_key(rd, rd.root_res, key)
}

type Builder {
  Builder(nodes: Dict(Int, Node), next_id: Int)
}

fn alloc(builder: Builder, node: Node) -> #(Builder, Int) {
  let id = builder.next_id
  #(Builder(dict.insert(builder.nodes, id, node), id + 1), id)
}

type RawNode {
  RawInt(Int)
  RawString(String)
  RawArray(List(Dynamic))
  RawAlias(String)
  RawIntVector(List(Int))
  RawBinary(BitArray)
  RawTable(List(#(String, Dynamic)))
}

@external(erlang, "intldate_icudata_ffi", "classify_node")
fn classify_node(_value: Dynamic) -> RawNode {
  panic as "unsupported Target"
}

fn build_node(builder: Builder, value: Dynamic) -> #(Builder, Int) {
  case classify_node(value) {
    RawInt(n) -> #(
      builder,
      uresimp.res_make_resource(uresimp.ResInt, int.bitwise_and(n, 0xfffffff)),
    )
    RawString(text) -> {
      let #(builder, id) = alloc(builder, NString(text))
      #(builder, uresimp.res_make_resource(uresimp.ResStringV2, id))
    }
    RawArray(items) -> build_array(builder, items)
    RawAlias(text) -> {
      let #(builder, id) = alloc(builder, NAlias(text))
      #(builder, uresimp.res_make_resource(uresimp.ResAlias, id))
    }
    RawIntVector(values) -> {
      let #(builder, id) = alloc(builder, NIntVector(values))
      #(builder, uresimp.res_make_resource(uresimp.ResIntVector, id))
    }
    RawBinary(bytes) -> {
      let #(builder, id) = alloc(builder, NBinary(bytes))
      #(builder, uresimp.res_make_resource(uresimp.ResBinary, id))
    }
    RawTable(pairs) -> build_table(builder, pairs)
  }
}

fn build_array(builder: Builder, items: List(Dynamic)) -> #(Builder, Int) {
  let #(builder, by_index, length) =
    build_array_loop(builder, items, dict.new(), 0)
  let #(builder, id) = alloc(builder, NArray(by_index:, length:))
  #(builder, uresimp.res_make_resource(uresimp.ResArray, id))
}

fn build_array_loop(
  builder: Builder,
  items: List(Dynamic),
  by_index: Dict(Int, Int),
  i: Int,
) -> #(Builder, Dict(Int, Int), Int) {
  case items {
    [] -> #(builder, by_index, i)
    [item, ..rest] -> {
      let #(builder, item_res) = build_node(builder, item)
      build_array_loop(builder, rest, dict.insert(by_index, i, item_res), i + 1)
    }
  }
}

fn build_table(
  builder: Builder,
  pairs: List(#(String, Dynamic)),
) -> #(Builder, Int) {
  let #(builder, by_key, by_index, length) =
    build_table_loop(builder, pairs, dict.new(), dict.new(), 0)
  let #(builder, id) = alloc(builder, NTable(by_key:, by_index:, length:))
  #(builder, uresimp.res_make_resource(uresimp.ResTable, id))
}

fn build_table_loop(
  builder: Builder,
  pairs: List(#(String, Dynamic)),
  by_key: Dict(String, Int),
  by_index: Dict(Int, String),
  i: Int,
) -> #(Builder, Dict(String, Int), Dict(Int, String), Int) {
  case pairs {
    [] -> #(builder, by_key, by_index, i)
    [#(key, value), ..rest] -> {
      let #(builder, item_res) = build_node(builder, value)
      build_table_loop(
        builder,
        rest,
        dict.insert(by_key, key, item_res),
        dict.insert(by_index, i, key),
        i + 1,
      )
    }
  }
}

pub fn from_dynamic(value: Dynamic) -> ResourceData {
  let #(builder, root_res) = build_node(Builder(dict.new(), 0), value)
  ResourceData(
    arena: builder.nodes,
    root_res:,
    no_fallback: False,
    uses_pool_bundle: False,
  )
}
