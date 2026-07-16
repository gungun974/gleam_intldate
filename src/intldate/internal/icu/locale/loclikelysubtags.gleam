import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/bytestrie.{type BytesTrie}
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/locdistance.{
  type DistanceData, type EncodedLSR, type LikelySubtags, DistanceData,
  EncodedLSR, LikelySubtags,
}
import intldate/internal/icu/locale/lsr.{type LSR}
import intldate/internal/math

pub const pseudo_accents_prefix = "'"

pub const pseudo_bidi_prefix = "+"

pub const pseudo_cracked_prefix = ","

const skip_script = 1

const cache_key = "likely-subtags-state"

const script_short_names = [
  "Zyyy", "Zinh", "Arab", "Armn", "Beng", "Bopo", "Cher", "Copt", "Cyrl", "Dsrt",
  "Deva", "Ethi", "Geor", "Goth", "Grek", "Gujr", "Guru", "Hani", "Hang", "Hebr",
  "Hira", "Knda", "Kana", "Khmr", "Laoo", "Latn", "Mlym", "Mong", "Mymr", "Ogam",
  "Ital", "Orya", "Runr", "Sinh", "Syrc", "Taml", "Telu", "Thaa", "Thai", "Tibt",
  "Cans", "Yiii", "Tglg", "Hano", "Buhd", "Tagb", "Brai", "Cprt", "Limb", "Linb",
  "Osma", "Shaw", "Tale", "Ugar", "Hrkt", "Bugi", "Glag", "Khar", "Sylo", "Talu",
  "Tfng", "Xpeo", "Bali", "Batk", "Blis", "Brah", "Cham", "Cirt", "Cyrs", "Egyd",
  "Egyh", "Egyp", "Geok", "Hans", "Hant", "Hmng", "Hung", "Inds", "Java", "Kali",
  "Latf", "Latg", "Lepc", "Lina", "Mand", "Maya", "Mero", "Nkoo", "Orkh", "Perm",
  "Phag", "Phnx", "Plrd", "Roro", "Sara", "Syre", "Syrj", "Syrn", "Teng", "Vaii",
  "Visp", "Xsux", "Zxxx", "Zzzz", "Cari", "Jpan", "Lana", "Lyci", "Lydi", "Olck",
  "Rjng", "Saur", "Sgnw", "Sund", "Moon", "Mtei", "Armi", "Avst", "Cakm", "Kore",
  "Kthi", "Mani", "Phli", "Phlp", "Phlv", "Prti", "Samr", "Tavt", "Zmth", "Zsym",
  "Bamu", "Lisu", "Nkgb", "Sarb", "Bass", "Dupl", "Elba", "Gran", "Kpel", "Loma",
  "Mend", "Merc", "Narb", "Nbat", "Palm", "Sind", "Wara", "Afak", "Jurc", "Mroo",
  "Nshu", "Shrd", "Sora", "Takr", "Tang", "Wole", "Hluw", "Khoj", "Tirh", "Aghb",
  "Mahj", "Ahom", "Hatr", "Modi", "Mult", "Pauc", "Sidd", "Adlm", "Bhks", "Marc",
  "Newa", "Osge", "Hanb", "Jamo", "Zsye", "Gonm", "Soyo", "Zanb", "Dogr", "Gong",
  "Maka", "Medf", "Rohg", "Sogd", "Sogo", "Elym", "Hmnp", "Nand", "Wcho", "Chrs",
  "Diak", "Kits", "Yezi", "Cpmn", "Ougr", "Tnsa", "Toto", "Vith", "Kawi", "Nagm",
  "Aran", "Gara", "Gukh", "Krai", "Onao", "Sunu", "Todr", "Tutg", "Berf", "Sidt",
  "Tayo", "Tols", "Hntl",
]

fn script_short_name(code: Int) -> String {
  case code < 0 {
    True -> ""
    False ->
      case list.drop(script_short_names, code) |> list.first {
        Ok(name) -> name
        Error(_) -> ""
      }
  }
}

const macroregions = [
  "001", "002", "003", "005", "009", "011", "013", "014", "015", "017", "018",
  "019", "021", "029", "030", "034", "035", "039", "053", "054", "057", "061",
  "142", "143", "145", "150", "151", "154", "155", "202", "419", "EU", "EZ",
  "QO", "UN",
]

fn is_macroregion(region: String) -> Bool {
  list.contains(macroregions, region)
}

fn char_from_code(code: Int) -> String {
  case string.utf_codepoint(code) {
    Ok(cp) -> string.from_utf_codepoints([cp])
    Error(_) -> ""
  }
}

fn to_language(encoded: Int) -> String {
  case encoded {
    0 -> ""
    1 -> "skip"
    _ -> {
      let encoded = int.bitwise_and(encoded, 0x00ffffff)
      let encoded = encoded % { 27 * 27 * 27 }
      let c0 = 97 + { { encoded % 27 } - 1 }
      let c1 = 97 + { math.floor_div(encoded, 27) % 27 } - 1
      case math.floor_div(encoded, 27 * 27) == 0 {
        True -> char_from_code(c0) <> char_from_code(c1)
        False -> {
          let c2 = 97 + math.floor_div(encoded, 27 * 27) - 1
          char_from_code(c0) <> char_from_code(c1) <> char_from_code(c2)
        }
      }
    }
  }
}

fn to_script(encoded: Int) -> String {
  case encoded {
    0 -> ""
    1 -> "script"
    _ -> {
      let encoded = int.bitwise_and(int.bitwise_shift_right(encoded, 24), 0xff)
      script_short_name(encoded)
    }
  }
}

fn to_region(m49_array: Dict(Int, String), encoded: Int) -> String {
  case encoded == 0 || encoded == 1 {
    True -> ""
    False -> {
      let encoded = int.bitwise_and(encoded, 0x00ffffff)
      let encoded = math.floor_div(encoded, 27 * 27 * 27)
      let encoded = encoded % { 27 * 27 }
      case encoded < 27 {
        True ->
          case dict.get(m49_array, encoded) {
            Ok(value) -> value
            Error(_) -> ""
          }
        False -> {
          let c0 = 65 + { { encoded % 27 } - 1 }
          let c1 = 65 + { math.floor_div(encoded, 27) % 27 } - 1
          char_from_code(c0) <> char_from_code(c1)
        }
      }
    }
  }
}

fn get_canonical(aliases: Dict(String, String), alias: String) -> String {
  case dict.get(aliases, alias) {
    Ok(canonical) -> canonical
    Error(_) -> alias
  }
}

fn normalize_language(language: String) -> String {
  case language == "und" {
    True -> ""
    False -> language
  }
}

fn normalize_script(script: String) -> String {
  case script == "Zzzz" {
    True -> ""
    False -> script
  }
}

fn normalize_region(region: String) -> String {
  case region == "ZZ" {
    True -> ""
    False -> region
  }
}

fn string_to_code_units(s: String) -> List(Int) {
  string.to_utf_codepoints(s) |> list.map(string.utf_codepoint_to_int)
}

fn trie_next_string(iter: BytesTrie, s: String) -> #(Int, BytesTrie) {
  case s == "" {
    True -> {
      let #(result, iter) = bytestrie.next(iter, 0x2a)
      classify_trie_result(result, iter)
    }
    False -> {
      let #(result, iter) = trie_next_string_loop(iter, string_to_code_units(s))
      classify_trie_result(result, iter)
    }
  }
}

fn trie_next_string_loop(
  iter: BytesTrie,
  units: List(Int),
) -> #(bytestrie.TrieMatch, BytesTrie) {
  case units {
    [c] -> bytestrie.next(iter, int.bitwise_or(c, 0x80))
    [c, ..rest] -> {
      let #(result, iter) = bytestrie.next(iter, c)
      case bytestrie.has_next(result) {
        True -> trie_next_string_loop(iter, rest)
        False -> #(bytestrie.NoMatch, iter)
      }
    }
    [] -> #(bytestrie.NoMatch, iter)
  }
}

fn classify_trie_result(
  result: bytestrie.TrieMatch,
  iter: BytesTrie,
) -> #(Int, BytesTrie) {
  case result {
    bytestrie.NoMatch -> #(-1, iter)
    bytestrie.NoValue -> #(0, iter)
    bytestrie.IntermediateValue -> #(skip_script, iter)
    bytestrie.FinalValue -> #(bytestrie.get_value(iter), iter)
  }
}

fn load_match_data(
  data: resource.LikelySubtagsData,
  m49_array: Dict(Int, String),
) -> DistanceData {
  let paradigms =
    list.map(data.match_paradigmnum, fn(v) {
      EncodedLSR(to_language(v), to_script(v), to_region(m49_array, v))
    })

  DistanceData(
    distance_trie_bytes: Some(data.match_trie),
    region_to_partitions: Some(data.match_region_to_partitions),
    partitions: data.match_partitions,
    paradigms:,
    paradigms_length: list.length(paradigms),
    distances: data.match_distances,
  )
}

pub type MaximizeSubtagsResult {
  MaximizeSubtagsResult(
    language: String,
    script: String,
    region: String,
    retain_language: Bool,
    retain_script: Bool,
    retain_region: Bool,
    match_index: Int,
    match_language: Bool,
    match_script: Bool,
    match_region: Bool,
  )
}

pub type LikelySubtagsState {
  LikelySubtagsState(
    lsrs: Dict(Int, LSR),
    language_aliases: Dict(String, String),
    region_aliases: Dict(String, String),
    trie_buf: BitArray,
    trie_und_state: bytestrie.BytesTrieState,
    trie_und_zzzz_state: bytestrie.BytesTrieState,
    default_lsr_index: Int,
    distance_trie_buf: Option(BitArray),
    region_to_partitions_buf: Option(BitArray),
    partitions: List(String),
    paradigm_lsrs: List(EncodedLSR),
    distances: List(Int),
  )
}

pub fn maximize_subtags(
  state: LikelySubtagsState,
  language: String,
  script: String,
  region: String,
) -> MaximizeSubtagsResult {
  let language = normalize_language(language)
  let script = normalize_script(script)
  let region = normalize_region(region)
  case script != "" && region != "" && language != "" {
    True ->
      MaximizeSubtagsResult(
        language,
        script,
        region,
        True,
        True,
        True,
        -1,
        True,
        True,
        True,
      )
    False -> {
      let iter = bytestrie.create_bytes_trie(state.trie_buf, 0)
      let #(value, iter) = trie_next_string(iter, language)
      let match_language = value >= 0
      let #(retain_language, trie_state, iter) = case value >= 0 {
        True -> #(language != "", Some(bytestrie.save_state(iter)), iter)
        False -> #(
          True,
          None,
          bytestrie.restore_state(iter, state.trie_und_state),
        )
      }

      let match_script = value >= 0 && script != ""

      let #(value, retain_script, trie_state, iter) = case value > 0 {
        True -> {
          let value2 = case value == skip_script {
            True -> 0
            False -> value
          }
          #(value2, script != "", trie_state, iter)
        }
        False -> {
          let #(value2, iter) = trie_next_string(iter, script)
          case value2 >= 0 {
            True -> #(
              value2,
              script != "",
              Some(bytestrie.save_state(iter)),
              iter,
            )
            False ->
              case trie_state {
                None -> #(
                  value2,
                  True,
                  None,
                  bytestrie.restore_state(iter, state.trie_und_zzzz_state),
                )
                Some(saved) -> {
                  let iter = bytestrie.restore_state(iter, saved)
                  let #(value3, iter) = trie_next_string(iter, "")
                  #(value3, True, Some(bytestrie.save_state(iter)), iter)
                }
              }
          }
        }
      }

      let match_region = False
      let #(
        value,
        retain_region,
        match_region,
        retain_language,
        retain_script,
        _iter,
      ) = case value > 0 {
        True -> #(
          value,
          region != "",
          match_region,
          retain_language,
          retain_script,
          iter,
        )
        False -> {
          let #(value2, iter) = trie_next_string(iter, region)
          case value2 >= 0 {
            True ->
              case region != "" && !is_macroregion(region) {
                True -> #(
                  value2,
                  True,
                  True,
                  retain_language,
                  retain_script,
                  iter,
                )
                False -> #(
                  value2,
                  False,
                  match_region,
                  retain_language,
                  retain_script,
                  iter,
                )
              }
            False ->
              case trie_state {
                None -> #(
                  state.default_lsr_index,
                  True,
                  match_region,
                  retain_language,
                  retain_script,
                  iter,
                )
                Some(saved) -> {
                  let iter = bytestrie.restore_state(iter, saved)
                  let #(value3, iter) = trie_next_string(iter, "")
                  case value3 < 0 {
                    True -> {
                      let iter =
                        bytestrie.restore_state(iter, state.trie_und_state)
                      let #(_value4, iter) = trie_next_string(iter, "")
                      let trie_und_empty_state = bytestrie.save_state(iter)
                      let #(value5, iter) = trie_next_string(iter, region)
                      let #(value6, iter) = case value5 < 0 {
                        True -> {
                          let iter =
                            bytestrie.restore_state(iter, trie_und_empty_state)
                          trie_next_string(iter, "")
                        }
                        False -> #(value5, iter)
                      }
                      #(
                        value6,
                        True,
                        match_region,
                        language != "",
                        script != "",
                        iter,
                      )
                    }
                    False -> #(
                      value3,
                      True,
                      match_region,
                      retain_language,
                      retain_script,
                      iter,
                    )
                  }
                }
              }
          }
        }
      }

      case dict.get(state.lsrs, value) {
        Error(_) ->
          MaximizeSubtagsResult(
            language,
            script,
            region,
            True,
            True,
            True,
            -1,
            match_language,
            match_script,
            match_region,
          )
        Ok(matched_lsr) -> {
          let language = case language == "" {
            True -> "und"
            False -> language
          }
          let language = case retain_language {
            True -> language
            False -> matched_lsr.language
          }
          let script = case retain_script {
            True -> script
            False -> matched_lsr.script
          }
          let region = case retain_region {
            True -> region
            False -> matched_lsr.region
          }
          MaximizeSubtagsResult(
            language,
            script,
            region,
            retain_language,
            retain_script,
            retain_region,
            value,
            match_language,
            match_script,
            match_region,
          )
        }
      }
    }
  }
}

pub fn maximize(
  state: LikelySubtagsState,
  language: String,
  script: String,
  region: String,
  return_input_if_unmatch: Bool,
) -> LSR {
  case !return_input_if_unmatch && region == "XA" {
    True ->
      lsr.create_lsr_with_prefix(
        pseudo_accents_prefix,
        language,
        script,
        region,
        lsr.explicit_lsr,
      )
    False ->
      case !return_input_if_unmatch && region == "XB" {
        True ->
          lsr.create_lsr_with_prefix(
            pseudo_bidi_prefix,
            language,
            script,
            region,
            lsr.explicit_lsr,
          )
        False ->
          case !return_input_if_unmatch && region == "XC" {
            True ->
              lsr.create_lsr_with_prefix(
                pseudo_cracked_prefix,
                language,
                script,
                region,
                lsr.explicit_lsr,
              )
            False ->
              maximize_normal(
                state,
                language,
                script,
                region,
                return_input_if_unmatch,
              )
          }
      }
  }
}

fn maximize_normal(
  state: LikelySubtagsState,
  language: String,
  script: String,
  region: String,
  return_input_if_unmatch: Bool,
) -> LSR {
  let language = get_canonical(state.language_aliases, language)
  let region = get_canonical(state.region_aliases, region)
  let r = maximize_subtags(state, language, script, region)
  let unmatched =
    !{
      r.match_language || r.match_script || { r.match_region && language == "" }
    }
  case return_input_if_unmatch && unmatched {
    True -> lsr.create_lsr("", "", "", lsr.explicit_lsr)
    False -> {
      let language_bit = case r.retain_language {
        True -> 4
        False -> 0
      }
      let script_bit = case r.retain_script {
        True -> 2
        False -> 0
      }
      let region_bit = case r.retain_region {
        True -> 1
        False -> 0
      }
      let retain_mask = language_bit + script_bit + region_bit
      lsr.create_lsr(r.language, r.script, r.region, retain_mask)
    }
  }
}

pub fn get_likely_index(
  state: LikelySubtagsState,
  language: String,
  script: String,
) -> Int {
  let language = normalize_language(language)
  let script = normalize_script(script)
  maximize_subtags(state, language, script, "").match_index
}

pub fn compare_likely(
  state: LikelySubtagsState,
  target: LSR,
  other: LSR,
  likely_info: Int,
) -> Int {
  case target.language != other.language {
    True -> -4
    False ->
      case target.script != other.script {
        True -> {
          let #(index, likely_info) = case
            likely_info >= 0 && int.bitwise_and(likely_info, 2) == 0
          {
            True -> #(int.bitwise_shift_right(likely_info, 2), likely_info)
            False -> {
              let index = get_likely_index(state, target.language, "")
              #(index, int.bitwise_shift_left(index, 2))
            }
          }
          let assert Ok(likely) = dict.get(state.lsrs, index)
          case target.script == likely.script {
            True -> int.bitwise_or(likely_info, 1)
            False ->
              int.bitwise_and(likely_info, int.bitwise_exclusive_or(-1, 1))
          }
        }
        False ->
          case target.region != other.region {
            True -> {
              let #(index, likely_info) = case
                likely_info >= 0 && int.bitwise_and(likely_info, 2) != 0
              {
                True -> #(int.bitwise_shift_right(likely_info, 2), likely_info)
                False -> {
                  let index =
                    get_likely_index(state, target.language, target.region)
                  #(index, int.bitwise_or(int.bitwise_shift_left(index, 2), 2))
                }
              }
              let assert Ok(likely) = dict.get(state.lsrs, index)
              case target.region == likely.region {
                True -> int.bitwise_or(likely_info, 1)
                False ->
                  int.bitwise_and(likely_info, int.bitwise_exclusive_or(-1, 1))
              }
            }
            False ->
              int.bitwise_and(likely_info, int.bitwise_exclusive_or(-1, 1))
          }
      }
  }
}

pub fn get_distance_data(state: LikelySubtagsState) -> DistanceData {
  DistanceData(
    distance_trie_bytes: state.distance_trie_buf,
    region_to_partitions: state.region_to_partitions_buf,
    partitions: state.partitions,
    paradigms: state.paradigm_lsrs,
    paradigms_length: list.length(state.paradigm_lsrs),
    distances: state.distances,
  )
}

pub fn create_likely_subtags(
  bundle: Bundle,
) -> Result(LikelySubtagsState, String) {
  case cache.get(cache_key) {
    Ok(state) -> Ok(state)
    Error(_) -> {
      use state <- result.try(create_likely_subtags_uncached(bundle))
      Ok(cache.put(cache_key, state))
    }
  }
}

fn create_likely_subtags_uncached(
  bundle: Bundle,
) -> Result(LikelySubtagsState, String) {
  let data = bundle.likely_subtags

  let m49_array =
    data.m49
    |> list.index_map(fn(value, i) { #(i, value) })
    |> dict.from_list

  let lsrs =
    list.map(data.lsrnum, fn(v) {
      lsr.create_lsr(
        to_language(v),
        to_script(v),
        to_region(m49_array, v),
        lsr.implicit_lsr,
      )
    })

  let language_aliases = pairs_to_dict(data.language_aliases)
  let region_aliases = pairs_to_dict(data.region_aliases)

  build_likely_subtags_state(
    data,
    m49_array,
    lsrs,
    language_aliases,
    region_aliases,
    data.trie,
  )
}

fn pairs_to_dict(values: List(String)) -> Dict(String, String) {
  pairs_to_dict_loop(values, dict.new())
}

fn pairs_to_dict_loop(
  values: List(String),
  acc: Dict(String, String),
) -> Dict(String, String) {
  case values {
    [from, to, ..rest] -> pairs_to_dict_loop(rest, dict.insert(acc, from, to))
    _ -> acc
  }
}

fn build_likely_subtags_state(
  data: resource.LikelySubtagsData,
  m49_array: Dict(Int, String),
  lsrs: List(LSR),
  language_aliases: Dict(String, String),
  region_aliases: Dict(String, String),
  trie_buf: BitArray,
) -> Result(LikelySubtagsState, String) {
  let trie = bytestrie.create_bytes_trie(trie_buf, 0)
  let #(result, trie) = bytestrie.next(trie, 0x2a)
  case !bytestrie.has_next(result) {
    True -> Error("likelySubtags trie: bad und state")
    False -> {
      let trie_und_state = bytestrie.save_state(trie)
      let #(result, trie) = bytestrie.next(trie, 0x2a)
      case !bytestrie.has_next(result) {
        True -> Error("likelySubtags trie: bad und-Zzzz state")
        False -> {
          let trie_und_zzzz_state = bytestrie.save_state(trie)
          let #(result, trie) = bytestrie.next(trie, 0x2a)
          case
            result != bytestrie.IntermediateValue
            && result != bytestrie.FinalValue
          {
            True -> Error("likelySubtags trie: bad default value")
            False -> {
              let default_lsr_index = bytestrie.get_value(trie)
              let match_data = load_match_data(data, m49_array)
              Ok(LikelySubtagsState(
                lsrs: lsrs
                  |> list.index_map(fn(l, i) { #(i, l) })
                  |> dict.from_list,
                language_aliases:,
                region_aliases:,
                trie_buf:,
                trie_und_state:,
                trie_und_zzzz_state:,
                default_lsr_index:,
                distance_trie_buf: match_data.distance_trie_bytes,
                region_to_partitions_buf: match_data.region_to_partitions,
                partitions: match_data.partitions,
                paradigm_lsrs: match_data.paradigms,
                distances: match_data.distances,
              ))
            }
          }
        }
      }
    }
  }
}

pub fn to_likely_subtags(state: LikelySubtagsState) -> LikelySubtags {
  LikelySubtags(
    get_distance_data: fn() { get_distance_data(state) },
    compare_likely: fn(target, other, likely_info) {
      compare_likely(state, target, other, likely_info)
    },
  )
}
