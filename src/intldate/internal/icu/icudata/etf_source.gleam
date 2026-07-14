import gleam/dynamic.{type Dynamic}

@external(erlang, "intldate_icudata_ffi", "load_bundle")
pub fn load_bundle(_data_path: String, _name: String) -> Result(Dynamic, Nil) {
  panic as "unsupported Target"
}
