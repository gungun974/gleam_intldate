@external(erlang, "intldate_icudata_ffi", "cache_get")
pub fn get(_key: String) -> Result(a, Nil) {
  Error(Nil)
}

@external(erlang, "intldate_icudata_ffi", "cache_put")
pub fn put(_key: String, value: a) -> a {
  value
}
