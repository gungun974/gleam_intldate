import gleam/string

pub const explicit_lsr = 7

pub const implicit_lsr = 0

pub type LSR {
  LSR(
    language: String,
    script: String,
    region: String,
    region_index: Int,
    flags: Int,
    hash_code: Int,
  )
}

fn upper_ordinal(c: Int) -> Int {
  let upper = case c >= 97 && c <= 122 {
    True -> c - 32
    False -> c
  }
  let a = upper - 65
  case 0 <= a && a <= 25 {
    True -> a
    False -> -1
  }
}

pub fn hash_chars_n(s: String) -> Int {
  hash_codepoints(string.to_utf_codepoints(s), 0)
}

fn hash_codepoints(codepoints, h: Int) -> Int {
  case codepoints {
    [cp, ..rest] ->
      hash_codepoints(rest, int32(h * 37 + string.utf_codepoint_to_int(cp)))
    [] -> h
  }
}

fn int32(x: Int) -> Int {
  let masked = x % 4_294_967_296
  let masked = case masked < 0 {
    True -> masked + 4_294_967_296
    False -> masked
  }
  case masked >= 2_147_483_648 {
    True -> masked - 4_294_967_296
    False -> masked
  }
}

pub fn index_for_region(region: String) -> Int {
  case string.to_utf_codepoints(region) {
    [c0, c1, c2] -> {
      let a = string.utf_codepoint_to_int(c0) - 48
      case 0 <= a && a <= 9 {
        True -> {
          let b = string.utf_codepoint_to_int(c1) - 48
          let c = string.utf_codepoint_to_int(c2) - 48
          case b < 0 || 9 < b || c < 0 || 9 < c {
            True -> 0
            False -> { 10 * a + b } * 10 + c + 1
          }
        }
        False -> 0
      }
    }
    [c0, c1] -> {
      let a = upper_ordinal(string.utf_codepoint_to_int(c0))
      let b = upper_ordinal(string.utf_codepoint_to_int(c1))
      case a < 0 || 25 < a || b < 0 || 25 < b {
        True -> 0
        False -> 26 * a + b + 1001
      }
    }
    _ -> 0
  }
}

pub fn create_lsr(
  language: String,
  script: String,
  region: String,
  flags: Int,
) -> LSR {
  LSR(
    language:,
    script:,
    region:,
    region_index: index_for_region(region),
    flags:,
    hash_code: 0,
  )
}

pub fn create_lsr_with_prefix(
  prefix: String,
  language: String,
  script: String,
  region: String,
  flags: Int,
) -> LSR {
  LSR(
    language: prefix <> language,
    script: prefix <> script,
    region:,
    region_index: index_for_region(region),
    flags:,
    hash_code: 0,
  )
}

pub fn is_equivalent_to(lsr: LSR, other: LSR) -> Bool {
  lsr.language == other.language
  && lsr.script == other.script
  && lsr.region_index == other.region_index
  && { lsr.region_index > 0 || lsr.region == other.region }
}

pub fn with_hash_code(lsr: LSR) -> LSR {
  case lsr.hash_code != 0 {
    True -> lsr
    False -> {
      let h = hash_chars_n(lsr.language)
      let h = int32(h * 37 + hash_chars_n(lsr.script))
      let h = int32(h * 37 + lsr.region_index)
      let h = int32(h * 37 + lsr.flags)
      LSR(..lsr, hash_code: h)
    }
  }
}
