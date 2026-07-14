import gleam/int
import gleam/option

pub type ResourceDataRef {
  ResourceDataRef(
    buf: BitArray,
    payload_offset: Int,
    format_version: List(Int),
    root_res: Int,
  )
}

pub type UResourceDataEntry {
  UResourceDataEntry(
    f_name: option.Option(String),
    f_path: option.Option(String),
    f_parent: option.Option(UResourceDataEntry),
    f_alias: option.Option(UResourceDataEntry),
    f_pool: option.Option(UResourceDataEntry),
    f_data: option.Option(ResourceDataRef),
    f_name_buffer: String,
    f_count_existing: Int,
    f_bogus: option.Option(String),
  )
}

pub type UResourceBundle {
  UResourceBundle(
    f_key: option.Option(String),
    f_data: option.Option(UResourceDataEntry),
    f_version: option.Option(String),
    f_valid_locale_data_entry: option.Option(UResourceDataEntry),
    f_res_path: option.Option(String),
    f_res_buf: String,
    f_res_path_len: Int,
    f_res: Int,
    f_has_fallback: Bool,
    f_is_top_level: Bool,
    f_magic1: Int,
    f_magic2: Int,
    f_index: Int,
    f_size: Int,
  )
}

pub type ResType {
  ResString
  ResBinary
  ResTable
  ResAlias
  ResTable32
  ResTable16
  ResStringV2
  ResInt
  ResArray
  ResArray16
  ResIntVector
  ResUnknown(Int)
}

fn res_type_from_int(value: Int) -> ResType {
  case value {
    0 -> ResString
    1 -> ResBinary
    2 -> ResTable
    3 -> ResAlias
    4 -> ResTable32
    5 -> ResTable16
    6 -> ResStringV2
    7 -> ResInt
    8 -> ResArray
    9 -> ResArray16
    14 -> ResIntVector
    other -> ResUnknown(other)
  }
}

fn res_type_to_int(type_: ResType) -> Int {
  case type_ {
    ResString -> 0
    ResBinary -> 1
    ResTable -> 2
    ResAlias -> 3
    ResTable32 -> 4
    ResTable16 -> 5
    ResStringV2 -> 6
    ResInt -> 7
    ResArray -> 8
    ResArray16 -> 9
    ResIntVector -> 14
    ResUnknown(value) -> value
  }
}

pub const res_bogus = 0xffffffff

pub fn res_get_type(res: Int) -> ResType {
  int.bitwise_shift_right(res, 28)
  |> int.bitwise_and(0xf)
  |> res_type_from_int
}

pub fn res_get_offset(res: Int) -> Int {
  int.bitwise_and(res, 0x0fffffff)
}

pub fn res_make_resource(type_: ResType, offset: Int) -> Int {
  int.bitwise_shift_left(res_type_to_int(type_), 28)
  |> int.bitwise_and(0xffffffff)
  |> int.bitwise_or(offset)
}

pub fn ures_is_array(type_: ResType) -> Bool {
  type_ == ResArray || type_ == ResArray16
}

pub fn ures_is_table(type_: ResType) -> Bool {
  type_ == ResTable || type_ == ResTable16 || type_ == ResTable32
}
