@external(erlang, "intldate_cache_ffi", "get_persistent_term")
pub fn get_persistent_term(_key: String) -> Result(a, Nil) {
  Error(Nil)
}

@external(erlang, "intldate_cache_ffi", "put_persistent_term")
pub fn put_persistent_term(_key: String, value: a) -> a {
  value
}

@external(erlang, "intldate_cache_ffi", "get_ets")
pub fn get_ets(_key: String) -> Result(a, Nil) {
  Error(Nil)
}

@external(erlang, "intldate_cache_ffi", "put_ets")
pub fn put_ets(_key: String, value: a) -> a {
  value
}
