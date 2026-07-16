import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/locale/uloc

const maxextlang = 3

const minlen = 2

const sep = "-"

const privateuse = "x"

const ldmlext = "u"

const locale_sep = "_"

const lang_und = "und"

const posix_key = "va"

const posix_value = "posix"

const locale_attribute_key = "attribute"

const locale_type_yes = "yes"

pub type ULanguageTag {
  ULanguageTag(
    buf: Option(String),
    language: String,
    extlang: List(Option(String)),
    script: String,
    region: String,
    variants: List(String),
    extensions: List(#(String, String)),
    privateuse: String,
    legacy: String,
  )
}

pub type UltagParseResult {
  UltagParseResult(langtag: ULanguageTag, parsed_len: Int)
}

pub type ForLanguageTagResult {
  ForLanguageTagResult(locale_id: String, parsed: Int)
}

pub type ForLanguageTagSinkResult {
  ForLanguageTagSinkResult(sink_value: String, parsed: Int)
}

const legacy = [
  #("art-lojban", "jbo"),
  #("en-gb-oed", "en-gb-oxendict"),
  #("i-ami", "ami"),
  #("i-bnn", "bnn"),
  #("i-hak", "hak"),
  #("i-klingon", "tlh"),
  #("i-lux", "lb"),
  #("i-navajo", "nv"),
  #("i-pwn", "pwn"),
  #("i-tao", "tao"),
  #("i-tay", "tay"),
  #("i-tsu", "tsu"),
  #("no-bok", "nb"),
  #("no-nyn", "nn"),
  #("sgn-be-fr", "sfb"),
  #("sgn-be-nl", "vgt"),
  #("sgn-ch-de", "sgg"),
  #("zh-guoyu", "cmn"),
  #("zh-hakka", "hak"),
  #("zh-min-nan", "nan"),
  #("zh-xiang", "hsn"),
  #("i-default", "en-x-i-default"),
  #("i-enochian", "und-x-i-enochian"),
  #("i-mingo", "see-x-i-mingo"),
  #("zh-min", "nan-x-zh-min"),
]

const redundant = [
  #("sgn-br", "bzs"),
  #("sgn-co", "csn"),
  #("sgn-de", "gsg"),
  #("sgn-dk", "dsl"),
  #("sgn-es", "ssp"),
  #("sgn-fr", "fsl"),
  #("sgn-gb", "bfi"),
  #("sgn-gr", "gss"),
  #("sgn-ie", "isg"),
  #("sgn-it", "ise"),
  #("sgn-jp", "jsl"),
  #("sgn-mx", "mfs"),
  #("sgn-ni", "ncs"),
  #("sgn-nl", "dse"),
  #("sgn-no", "nsl"),
  #("sgn-pt", "psr"),
  #("sgn-se", "swl"),
  #("sgn-us", "ase"),
  #("sgn-za", "sfs"),
  #("zh-cmn", "cmn"),
  #("zh-cmn-hans", "cmn-hans"),
  #("zh-cmn-hant", "cmn-hant"),
  #("zh-gan", "gan"),
  #("zh-wuu", "wuu"),
  #("zh-yue", "yue"),
  #("ja-latn-hepburn-heploc", "ja-latn-alalc97"),
]

const deprecatedlangs = [
  #("in", "id"),
  #("iw", "he"),
  #("ji", "yi"),
  #("jw", "jv"),
  #("mo", "ro"),
  #("aam", "aas"),
  #("adp", "dz"),
  #("aue", "ktz"),
  #("ayx", "nun"),
  #("bgm", "bcg"),
  #("bjd", "drl"),
  #("ccq", "rki"),
  #("cjr", "mom"),
  #("cka", "cmr"),
  #("cmk", "xch"),
  #("coy", "pij"),
  #("cqu", "quh"),
  #("drh", "khk"),
  #("drw", "prs"),
  #("gav", "dev"),
  #("gfx", "vaj"),
  #("ggn", "gvr"),
  #("gti", "nyc"),
  #("guv", "duz"),
  #("hrr", "jal"),
  #("ibi", "opa"),
  #("ilw", "gal"),
  #("jeg", "oyb"),
  #("kgc", "tdf"),
  #("kgh", "kml"),
  #("koj", "kwv"),
  #("krm", "bmf"),
  #("ktr", "dtp"),
  #("kvs", "gdj"),
  #("kwq", "yam"),
  #("kxe", "tvd"),
  #("kzj", "dtp"),
  #("kzt", "dtp"),
  #("lii", "raq"),
  #("lmm", "rmx"),
  #("meg", "cir"),
  #("mst", "mry"),
  #("mwj", "vaj"),
  #("myt", "mry"),
  #("nad", "xny"),
  #("ncp", "kdz"),
  #("nnx", "ngv"),
  #("nts", "pij"),
  #("oun", "vaj"),
  #("pcr", "adx"),
  #("pmc", "huw"),
  #("pmu", "phr"),
  #("ppa", "bfy"),
  #("ppr", "lcq"),
  #("pry", "prt"),
  #("puz", "pub"),
  #("sca", "hle"),
  #("skk", "oyb"),
  #("tdu", "dtp"),
  #("thc", "tpo"),
  #("thx", "oyb"),
  #("tie", "ras"),
  #("tkk", "twm"),
  #("tlw", "weo"),
  #("tmp", "tyj"),
  #("tne", "kak"),
  #("tnf", "prs"),
  #("tsf", "taj"),
  #("uok", "ema"),
  #("xba", "cax"),
  #("xia", "acn"),
  #("xkh", "waw"),
  #("xsj", "suj"),
  #("ybd", "rki"),
  #("yma", "lrr"),
  #("ymt", "mtm"),
  #("yos", "zom"),
  #("yuu", "yug"),
]

const deprecatedregions = [
  #("BU", "MM"),
  #("DD", "DE"),
  #("FX", "FR"),
  #("TP", "TL"),
  #("YD", "YE"),
  #("ZR", "CD"),
]

fn code_points(s: String) -> List(String) {
  string.to_graphemes(s)
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

fn is_alpha(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn is_digit(c: String) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
}

fn is_alphanum(c: String) -> Bool {
  is_alpha(c) || is_digit(c)
}

fn is_alpha_string(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_alpha(c) {
        True -> is_alpha_string(rest)
        False -> False
      }
  }
}

fn is_numeric_string(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_digit(c) {
        True -> is_numeric_string(rest)
        False -> False
      }
  }
}

fn is_alphanumeric_string(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_alphanum(c) {
        True -> is_alphanumeric_string(rest)
        False -> False
      }
  }
}

fn is_alpha_string_len(s: String, len: Int) -> Bool {
  let chars = code_points(s)
  list.length(chars) == len && is_alpha_string(chars)
}

fn is_numeric_string_len(s: String, len: Int) -> Bool {
  let chars = code_points(s)
  list.length(chars) == len && is_numeric_string(chars)
}

fn is_alphanumeric_string_limited_length(
  s: String,
  min: Int,
  max: Int,
) -> Bool {
  let len = list.length(code_points(s))
  len >= min && len <= max && is_alphanumeric_string(code_points(s))
}

pub fn ultag_is_language_subtag(s: String) -> Bool {
  let len = list.length(code_points(s))
  len >= 2 && len <= 8 && is_alpha_string(code_points(s))
}

fn is_extlang_subtag(s: String) -> Bool {
  is_alpha_string_len(s, 3)
}

pub fn ultag_is_script_subtag(s: String) -> Bool {
  is_alpha_string_len(s, 4)
}

pub fn ultag_is_region_subtag(s: String) -> Bool {
  is_alpha_string_len(s, 2) || is_numeric_string_len(s, 3)
}

fn is_variant_subtag(s: String) -> Bool {
  case is_alphanumeric_string_limited_length(s, 5, 8) {
    True -> True
    False ->
      case list.length(code_points(s)) == 4 {
        False -> False
        True -> {
          let chars = code_points(s)
          case chars {
            [c0, ..rest] ->
              is_digit(c0)
              && is_alphanumeric_string_limited_length(
                string.join(rest, ""),
                3,
                3,
              )
            [] -> False
          }
        }
      }
  }
}

fn is_privateuse_variant_subtag(s: String) -> Bool {
  is_alphanumeric_string_limited_length(s, 1, 8)
}

fn is_extension_singleton(s: String) -> Bool {
  case list.length(code_points(s)) == 1 {
    False -> False
    True -> is_alphanum(s) && string.lowercase(s) != privateuse
  }
}

fn is_extension_subtag(s: String) -> Bool {
  is_alphanumeric_string_limited_length(s, 2, 8)
}

fn is_privateuse_value_subtag(s: String) -> Bool {
  is_alphanumeric_string_limited_length(s, 1, 8)
}

pub fn ultag_is_unicode_locale_attribute(s: String) -> Bool {
  is_alphanumeric_string_limited_length(s, 3, 8)
}

pub fn ultag_is_unicode_locale_key(s: String) -> Bool {
  case list.length(code_points(s)) == 2 {
    False -> False
    True -> {
      let chars = code_points(s)
      case chars {
        [c0, c1] -> is_alphanum(c0) && is_alpha(c1)
        _ -> False
      }
    }
  }
}

fn to_lower(s: String) -> String {
  string.lowercase(s)
}

fn to_upper(s: String) -> String {
  string.uppercase(s)
}

fn to_title(s: String) -> String {
  case s {
    "" -> ""
    _ ->
      string.uppercase(string.slice(s, 0, 1))
      <> string.lowercase(string.drop_start(s, 1))
  }
}

fn find_in_pairs(
  pairs: List(#(String, String)),
  key: String,
) -> Option(String) {
  case list.key_find(pairs, key) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

type GrandfatheredReplacement {
  GrandfatheredReplacement(tag: String, parsed_len_delta: Int)
}

fn replace_grandfathered(tag: String) -> GrandfatheredReplacement {
  let lower = string.lowercase(tag)
  case find_grandfathered(legacy, lower, tag) {
    Some(result) -> result
    None ->
      case find_grandfathered(redundant, lower, tag) {
        Some(result) -> result
        None -> GrandfatheredReplacement(tag, 0)
      }
  }
}

fn find_grandfathered(
  table: List(#(String, String)),
  lower: String,
  tag: String,
) -> Option(GrandfatheredReplacement) {
  case table {
    [] -> None
    [#(from, to), ..rest] ->
      case lower == from || string.starts_with(lower, from <> sep) {
        True -> {
          let from_len = string.length(from)
          Some(GrandfatheredReplacement(
            to <> string.drop_start(tag, from_len),
            from_len - string.length(to),
          ))
        }
        False -> find_grandfathered(rest, lower, tag)
      }
  }
}

pub fn create_ulanguage_tag() -> ULanguageTag {
  ULanguageTag(
    buf: None,
    language: "",
    extlang: [None, None, None],
    script: "",
    region: "",
    variants: [],
    extensions: [],
    privateuse: "",
    legacy: "",
  )
}

type ExtensionAccum {
  ExtensionAccum(key: String, value: List(String))
}

type ParseState {
  ParseState(
    language: String,
    extlang: List(Option(String)),
    extlang_idx: Int,
    script: String,
    region: String,
    variants: List(String),
    extensions: List(#(String, String)),
    privateuse: String,
    parsed_len: Int,
    last_parsed_index: Int,
    in_private_use: Bool,
    current_extension: Option(ExtensionAccum),
    privateuse_var: Bool,
    extlang_allowed: Bool,
    current_extension_last_value_index: Int,
  )
}

fn initial_parse_state() -> ParseState {
  ParseState(
    language: "",
    extlang: [None, None, None],
    extlang_idx: 0,
    script: "",
    region: "",
    variants: [],
    extensions: [],
    privateuse: "",
    parsed_len: 0,
    last_parsed_index: -1,
    in_private_use: False,
    current_extension: None,
    privateuse_var: False,
    extlang_allowed: False,
    current_extension_last_value_index: -1,
  )
}

fn extlang_set(
  extlang: List(Option(String)),
  idx: Int,
  value: String,
) -> List(Option(String)) {
  case extlang, idx {
    [_, b, c], 0 -> [Some(value), b, c]
    [a, _, c], 1 -> [a, Some(value), c]
    [a, b, _], 2 -> [a, b, Some(value)]
    _, _ -> extlang
  }
}

fn finalize_extension(state: ParseState) -> #(ParseState, Bool) {
  case state.current_extension {
    None -> #(state, False)
    Some(ext) ->
      case ext.value {
        [] -> #(state, False)
        [_, ..] ->
          case has_extension_key(state.extensions, ext.key) {
            True -> #(state, False)
            False -> #(
              ParseState(
                ..state,
                extensions: list.append(state.extensions, [
                  #(ext.key, string.join(list.reverse(ext.value), sep)),
                ]),
                last_parsed_index: state.current_extension_last_value_index,
              ),
              True,
            )
          }
      }
  }
}

fn has_extension_key(extensions: List(#(String, String)), key: String) -> Bool {
  case extensions {
    [] -> False
    [#(k, _), ..rest] ->
      case k == key {
        True -> True
        False -> has_extension_key(rest, key)
      }
  }
}

fn parse_subtags(
  subtags: List(String),
  i: Int,
  state: ParseState,
) -> ParseState {
  case subtags {
    [] ->
      case state.current_extension {
        None -> state
        Some(_) -> {
          let #(finalized, ok) = finalize_extension(state)
          case ok {
            True -> finalized
            False -> state
          }
        }
      }
    [subtag, ..rest] ->
      case subtag == "" {
        True -> state
        False -> {
          case parse_one_subtag(subtag, i, state) {
            Ok(state) -> parse_subtags(rest, i + 1, state)
            Error(state) -> state
          }
        }
      }
  }
}

fn parse_one_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case state.in_private_use {
    True -> parse_in_private_use(subtag, i, state)
    False ->
      case state.language == "" {
        True -> parse_language_subtag(subtag, i, state)
        False -> parse_other_subtag(subtag, i, state)
      }
  }
}

fn parse_in_private_use(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case string.starts_with(subtag, "lvariant") {
    True -> Ok(ParseState(..state, in_private_use: False, privateuse_var: True))
    False ->
      case is_privateuse_value_subtag(subtag) {
        False -> Error(state)
        True -> {
          let new_privateuse = case state.privateuse == "" {
            True -> to_lower(subtag)
            False -> state.privateuse <> sep <> to_lower(subtag)
          }
          Ok(
            ParseState(
              ..state,
              privateuse: new_privateuse,
              parsed_len: state.parsed_len + string.length(subtag) + 1,
              last_parsed_index: i,
            ),
          )
        }
      }
  }
}

fn parse_language_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case ultag_is_language_subtag(subtag) {
    False -> Error(state)
    True ->
      Ok(
        ParseState(
          ..state,
          language: to_lower(subtag),
          extlang_allowed: string.length(subtag) <= 3,
          parsed_len: state.parsed_len + string.length(subtag) + 1,
          last_parsed_index: i,
        ),
      )
  }
}

fn parse_other_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case
    state.extlang_allowed
    && state.extlang_idx < maxextlang
    && is_extlang_subtag(subtag)
    && state.script == ""
    && state.region == ""
    && state.variants == []
    && state.current_extension == None
  {
    True ->
      Ok(
        ParseState(
          ..state,
          extlang: extlang_set(
            state.extlang,
            state.extlang_idx,
            to_lower(subtag),
          ),
          extlang_idx: state.extlang_idx + 1,
          parsed_len: state.parsed_len + string.length(subtag) + 1,
          last_parsed_index: i,
        ),
      )
    False -> parse_script_subtag(subtag, i, state)
  }
}

fn parse_script_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case
    state.script == ""
    && ultag_is_script_subtag(subtag)
    && state.current_extension == None
  {
    True ->
      Ok(
        ParseState(
          ..state,
          script: to_title(subtag),
          parsed_len: state.parsed_len + string.length(subtag) + 1,
          last_parsed_index: i,
        ),
      )
    False -> parse_region_subtag(subtag, i, state)
  }
}

fn parse_region_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case
    state.region == ""
    && ultag_is_region_subtag(subtag)
    && state.current_extension == None
  {
    True ->
      Ok(
        ParseState(
          ..state,
          region: to_upper(subtag),
          parsed_len: state.parsed_len + string.length(subtag) + 1,
          last_parsed_index: i,
        ),
      )
    False -> parse_variant_subtag(subtag, i, state)
  }
}

fn parse_variant_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  let matches_variant = case state.privateuse_var {
    True -> is_privateuse_variant_subtag(subtag)
    False -> is_variant_subtag(subtag)
  }
  case matches_variant && state.current_extension == None {
    True -> {
      let variant = to_upper(subtag)
      case list.contains(state.variants, variant) {
        True -> Error(state)
        False ->
          Ok(
            ParseState(
              ..state,
              variants: list.append(state.variants, [variant]),
              parsed_len: state.parsed_len + string.length(subtag) + 1,
              last_parsed_index: i,
            ),
          )
      }
    }
    False -> parse_extension_subtag(subtag, i, state)
  }
}

fn parse_extension_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case is_extension_singleton(subtag) {
    True ->
      case state.current_extension {
        None ->
          Ok(
            ParseState(
              ..state,
              current_extension: Some(ExtensionAccum(to_lower(subtag), [])),
              current_extension_last_value_index: -1,
            ),
          )
        Some(_) -> {
          let #(state, ok) = finalize_extension(state)
          case ok {
            False -> Error(state)
            True ->
              Ok(
                ParseState(
                  ..state,
                  current_extension: Some(ExtensionAccum(to_lower(subtag), [])),
                  current_extension_last_value_index: -1,
                ),
              )
          }
        }
      }
    False -> parse_extension_value_subtag(subtag, i, state)
  }
}

fn parse_extension_value_subtag(
  subtag: String,
  i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case state.current_extension, is_extension_subtag(subtag) {
    Some(ext), True ->
      Ok(
        ParseState(
          ..state,
          current_extension: Some(
            ExtensionAccum(ext.key, [to_lower(subtag), ..ext.value]),
          ),
          current_extension_last_value_index: i,
        ),
      )
    _, _ -> parse_privateuse_marker(subtag, i, state)
  }
}

fn parse_privateuse_marker(
  subtag: String,
  _i: Int,
  state: ParseState,
) -> Result(ParseState, ParseState) {
  case to_lower(subtag) == privateuse {
    False -> Error(state)
    True -> {
      let #(state, ok) = case state.current_extension {
        None -> #(state, True)
        Some(_) -> finalize_extension(state)
      }
      case state.current_extension != None && !ok {
        True -> Error(state)
        False ->
          Ok(ParseState(..state, current_extension: None, in_private_use: True))
      }
    }
  }
}

pub fn ultag_parse(tag: String) -> UltagParseResult {
  case string.length(tag) < minlen {
    True -> UltagParseResult(create_ulanguage_tag(), 0)
    False -> {
      let replacement = replace_grandfathered(tag)
      let buf = replacement.tag
      let subtags = string.split(buf, sep)

      let final_state = parse_subtags(subtags, 0, initial_parse_state())

      let parsed_len = case final_state.last_parsed_index < 0 {
        True -> 0
        False ->
          string.length(string.join(
            list.take(subtags, final_state.last_parsed_index + 1),
            sep,
          ))
      }

      let langtag =
        ULanguageTag(
          buf: Some(buf),
          language: final_state.language,
          extlang: final_state.extlang,
          script: final_state.script,
          region: final_state.region,
          variants: final_state.variants,
          extensions: final_state.extensions,
          privateuse: final_state.privateuse,
          legacy: "",
        )

      UltagParseResult(langtag, parsed_len + replacement.parsed_len_delta)
    }
  }
}

pub fn ultag_get_language(langtag: ULanguageTag) -> String {
  langtag.language
}

fn index_dict(values: List(a)) -> Dict(Int, a) {
  values
  |> list.index_map(fn(value, i) { #(i, value) })
  |> dict.from_list
}

fn dict_at(entries: Dict(Int, a), index: Int) -> Option(a) {
  case dict.get(entries, index) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

pub fn ultag_get_extlang(langtag: ULanguageTag, idx: Int) -> Option(String) {
  case dict_at(index_dict(langtag.extlang), idx) {
    Some(Some(v)) -> Some(v)
    _ -> None
  }
}

pub fn ultag_get_extlang_size(langtag: ULanguageTag) -> Int {
  list.length(list.filter(langtag.extlang, fn(x) { x != None }))
}

pub fn ultag_get_script(langtag: ULanguageTag) -> String {
  langtag.script
}

pub fn ultag_get_region(langtag: ULanguageTag) -> String {
  langtag.region
}

pub fn ultag_get_extensions_size(langtag: ULanguageTag) -> Int {
  list.length(langtag.extensions)
}

pub fn ultag_get_private_use(langtag: ULanguageTag) -> String {
  langtag.privateuse
}

fn append_language_to_locale_id(
  langtag: ULanguageTag,
  current: String,
) -> String {
  let language = case ultag_get_extlang_size(langtag) > 0 {
    True -> option.unwrap(ultag_get_extlang(langtag, 0), "")
    False -> ultag_get_language(langtag)
  }
  case language != "" && language != lang_und {
    True ->
      current
      <> option.unwrap(find_in_pairs(deprecatedlangs, language), language)
    False -> current
  }
}

fn append_script_to_locale_id(
  langtag: ULanguageTag,
  current: String,
) -> String {
  case ultag_get_script(langtag) {
    "" -> current
    script -> current <> locale_sep <> script
  }
}

fn append_region_to_locale_id(
  langtag: ULanguageTag,
  current: String,
) -> String {
  case ultag_get_region(langtag) {
    "" -> current
    region ->
      current
      <> locale_sep
      <> option.unwrap(find_in_pairs(deprecatedregions, region), region)
  }
}

fn append_variants_to_locale_id(
  langtag: ULanguageTag,
  current: String,
) -> String {
  let variants = list.sort(langtag.variants, string.compare)
  case variants {
    [] -> current
    _ -> {
      let next = case current == "" || !string.contains(current, locale_sep) {
        True -> current <> locale_sep
        False -> current
      }
      list.fold(variants, next, fn(acc, variant) {
        acc <> locale_sep <> variant
      })
    }
  }
}

fn append_ldml_extension_as_keywords(
  bundle: Bundle,
  type_: String,
  keyword_map: Dict(String, String),
  posix: Bool,
) -> #(Dict(String, String), Bool) {
  let subtags = index_dict(string.split(type_, sep))
  let #(attributes, rest_idx) = collect_attributes(subtags, 0, [])
  let keyword_map = case attributes {
    [] -> keyword_map
    _ ->
      dict.insert(
        keyword_map,
        locale_attribute_key,
        string.join(list.sort(attributes, string.compare), sep),
      )
  }
  consume_key_value_pairs(bundle, subtags, rest_idx, keyword_map, posix)
}

fn collect_attributes(
  subtags: Dict(Int, String),
  i: Int,
  acc: List(String),
) -> #(List(String), Int) {
  case dict_at(subtags, i) {
    None -> #(list.reverse(acc), i)
    Some(subtag) ->
      case ultag_is_unicode_locale_key(subtag) {
        True -> #(list.reverse(acc), i)
        False ->
          case ultag_is_unicode_locale_attribute(subtag) {
            True ->
              collect_attributes(subtags, i + 1, [to_lower(subtag), ..acc])
            False -> collect_attributes(subtags, i + 1, acc)
          }
      }
  }
}

fn consume_key_value_pairs(
  bundle: Bundle,
  subtags: Dict(Int, String),
  i: Int,
  keyword_map: Dict(String, String),
  posix: Bool,
) -> #(Dict(String, String), Bool) {
  case dict_at(subtags, i) {
    None -> #(keyword_map, posix)
    Some(bcp_key) -> {
      let type_start = i + 1
      let type_end = find_next_key_index(subtags, type_start)
      let bcp_type = case type_end > type_start {
        True -> string.join(dict_slice(subtags, type_start, type_end), sep)
        False -> locale_type_yes
      }
      let key =
        option.unwrap(uloc.to_legacy_key(Some(bundle), bcp_key), bcp_key)
      let value =
        option.unwrap(
          uloc.to_legacy_type(Some(bundle), key, bcp_type),
          bcp_type,
        )
      let #(keyword_map, posix) = case
        !posix && key == posix_key && value == posix_value
      {
        True -> #(keyword_map, True)
        False ->
          case dict.has_key(keyword_map, key) {
            True -> #(keyword_map, posix)
            False -> #(dict.insert(keyword_map, key, value), posix)
          }
      }
      consume_key_value_pairs(bundle, subtags, type_end, keyword_map, posix)
    }
  }
}

fn find_next_key_index(subtags: Dict(Int, String), i: Int) -> Int {
  case dict_at(subtags, i) {
    None -> i
    Some(subtag) ->
      case ultag_is_unicode_locale_key(subtag) {
        True -> i
        False -> find_next_key_index(subtags, i + 1)
      }
  }
}

fn dict_slice(
  entries: Dict(Int, String),
  start: Int,
  end: Int,
) -> List(String) {
  case start >= end {
    True -> []
    False ->
      case dict_at(entries, start) {
        None -> []
        Some(value) -> [value, ..dict_slice(entries, start + 1, end)]
      }
  }
}

fn append_keywords(
  bundle: Bundle,
  langtag: ULanguageTag,
  current: String,
) -> String {
  let posix = list.contains(langtag.variants, "POSIX")
  let #(keyword_map, posix) =
    fold_extensions(
      bundle,
      index_dict(langtag.extensions),
      0,
      ultag_get_extensions_size(langtag),
      dict.new(),
      posix,
    )

  let priv = ultag_get_private_use(langtag)
  let keyword_map = case priv != "" && !dict.has_key(keyword_map, privateuse) {
    True -> dict.insert(keyword_map, privateuse, priv)
    False -> keyword_map
  }

  let locale_id = case posix {
    True -> current <> "_POSIX"
    False -> current
  }

  let sorted =
    dict.to_list(keyword_map)
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })

  list.fold(sorted, locale_id, fn(acc, entry) {
    case uloc.set_keyword_value(entry.0, Some(entry.1), acc) {
      Ok(next) -> next
      Error(_) -> acc
    }
  })
}

fn fold_extensions(
  bundle: Bundle,
  extensions: Dict(Int, #(String, String)),
  i: Int,
  size: Int,
  keyword_map: Dict(String, String),
  posix: Bool,
) -> #(Dict(String, String), Bool) {
  case i >= size {
    True -> #(keyword_map, posix)
    False -> {
      let #(key, type_) = case dict_at(extensions, i) {
        Some(entry) -> entry
        None -> #("", "")
      }
      case key == ldmlext {
        True -> {
          let #(keyword_map, posix) =
            append_ldml_extension_as_keywords(bundle, type_, keyword_map, posix)
          fold_extensions(bundle, extensions, i + 1, size, keyword_map, posix)
        }
        False -> {
          let keyword_map = case dict.has_key(keyword_map, key) {
            True -> keyword_map
            False -> dict.insert(keyword_map, key, type_)
          }
          fold_extensions(bundle, extensions, i + 1, size, keyword_map, posix)
        }
      }
    }
  }
}

pub fn uloc_for_language_tag(
  bundle: Bundle,
  tag: String,
) -> ForLanguageTagResult {
  case string_matches_x_prefix(tag) {
    True ->
      ForLanguageTagResult(
        "@x=" <> string.drop_start(tag, 2),
        string.length(tag),
      )
    False -> {
      let result = ultag_parse(tag)
      let locale_id =
        ""
        |> append_language_to_locale_id(result.langtag, _)
        |> append_script_to_locale_id(result.langtag, _)
        |> append_region_to_locale_id(result.langtag, _)
        |> append_variants_to_locale_id(result.langtag, _)
        |> append_keywords(bundle, result.langtag, _)
      ForLanguageTagResult(locale_id, result.parsed_len)
    }
  }
}

fn string_matches_x_prefix(tag: String) -> Bool {
  string.length(tag) >= 2 && string.lowercase(string.slice(tag, 0, 2)) == "x-"
}
