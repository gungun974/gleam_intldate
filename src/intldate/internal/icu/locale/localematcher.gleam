import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/locale/locdistance
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/lsr.{type LSR}
import intldate/internal/icu/locale/uloc

pub const ulocmatch_demotion_region = 1

pub type LocaleMatcherResult {
  LocaleMatcherResult(
    desired_locale: Option(String),
    supported_locale: Option(String),
    desired_index: Int,
    supported_index: Int,
  )
}

pub type LocaleMatcherBuilder {
  LocaleMatcherBuilder(
    supported_locales: List(String),
    default_locale: Option(String),
    threshold_distance: Int,
    demotion: Int,
    favor: Int,
    direction: Int,
    with_default: Bool,
    max_distance_desired: Option(String),
    max_distance_supported: Option(String),
  )
}

pub type LocaleMatcher {
  LocaleMatcher(
    bundle: Bundle,
    likely_subtags: loclikelysubtags.LikelySubtagsState,
    locale_distance: locdistance.LocaleDistance,
    threshold_distance: Int,
    demotion_per_desired_locale: Int,
    favor_subtag: Int,
    direction: Int,
    supported_locales: List(String),
    supported_locales_by_index: Dict(Int, String),
    supported_locales_length: Int,
    supported_lsr_to_index: Dict(String, Int),
    supported_lsrs: Dict(Int, LSR),
    supported_indexes: Dict(Int, Int),
    supported_lsrs_length: Int,
    default_locale: Option(String),
  )
}

fn und_lsr() -> LSR {
  lsr.create_lsr("und", "", "", lsr.explicit_lsr)
}

fn create_result(
  desired_locale: Option(String),
  supported_locale: Option(String),
  desired_index: Int,
  supported_index: Int,
) -> LocaleMatcherResult {
  LocaleMatcherResult(
    desired_locale:,
    supported_locale:,
    desired_index:,
    supported_index:,
  )
}

pub fn get_maximal_lsr_or_und(
  likely_subtags: loclikelysubtags.LikelySubtagsState,
  locale_id: Option(String),
) -> LSR {
  case locale_id {
    None -> und_lsr()
    Some(id) ->
      case uloc.get_language(Some(id)) {
        "" -> und_lsr()
        language ->
          loclikelysubtags.maximize(
            likely_subtags,
            language,
            uloc.get_script(Some(id)),
            uloc.get_region(Some(id)),
            False,
          )
      }
  }
}

pub fn create_builder() -> LocaleMatcherBuilder {
  LocaleMatcherBuilder(
    supported_locales: [],
    default_locale: None,
    threshold_distance: -1,
    demotion: ulocmatch_demotion_region,
    favor: locdistance.ulocmatch_favor_language,
    direction: locdistance.ulocmatch_direction_with_one_way,
    with_default: True,
    max_distance_desired: None,
    max_distance_supported: None,
  )
}

pub fn add_supported_locale(
  builder: LocaleMatcherBuilder,
  locale: String,
) -> LocaleMatcherBuilder {
  LocaleMatcherBuilder(
    ..builder,
    supported_locales: list.append(builder.supported_locales, [locale]),
  )
}

pub fn builder_from_supported_locales(
  supported_locale_names: List(String),
) -> LocaleMatcherBuilder {
  list.fold(supported_locale_names, create_builder(), add_supported_locale)
}

fn lsr_key(lsr_value: LSR) -> String {
  int.to_string(lsr_value.hash_code)
  <> "\u{0}"
  <> lsr_value.language
  <> "\u{0}"
  <> lsr_value.script
  <> "\u{0}"
  <> lsr_value.region
}

type Order {
  Order1
  Order2
  Order3
}

fn put_if_absent(
  supported_lsr_to_index: Dict(String, Int),
  supported_lsrs: List(#(Int, LSR)),
  supported_indexes: List(#(Int, Int)),
  lsr_value: LSR,
  i: Int,
  supp_length: Int,
) -> #(Dict(String, Int), List(#(Int, LSR)), List(#(Int, Int)), Int) {
  let key = lsr_key(lsr_value)
  case dict.has_key(supported_lsr_to_index, key) {
    True -> #(
      supported_lsr_to_index,
      supported_lsrs,
      supported_indexes,
      supp_length,
    )
    False -> #(
      dict.insert(supported_lsr_to_index, key, i),
      [#(supp_length, lsr_value), ..supported_lsrs],
      [#(supp_length, i), ..supported_indexes],
      supp_length + 1,
    )
  }
}

fn index_dict(values: List(a)) -> Dict(Int, a) {
  values
  |> list.index_map(fn(value, i) { #(i, value) })
  |> dict.from_list
}

fn dict_at(entries: Dict(Int, a), index: Int, default: a) -> a {
  case dict.get(entries, index) {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn sparse_to_list(
  entries: List(#(Int, a)),
  length: Int,
  default: a,
) -> List(a) {
  let by_index =
    list.fold(entries, dict.new(), fn(acc, entry) {
      case dict.has_key(acc, entry.0) {
        True -> acc
        False -> dict.insert(acc, entry.0, entry.1)
      }
    })
  sparse_to_list_loop(by_index, 0, length, default)
}

fn sparse_to_list_loop(
  entries: Dict(Int, a),
  i: Int,
  length: Int,
  default: a,
) -> List(a) {
  case i >= length {
    True -> []
    False -> {
      let value = case dict.get(entries, i) {
        Ok(value) -> value
        Error(_) -> default
      }
      [value, ..sparse_to_list_loop(entries, i + 1, length, default)]
    }
  }
}

type ClassifyState {
  ClassifyState(
    def: Option(String),
    def_lsr: Option(LSR),
    supported_lsr_to_index: Dict(String, Int),
    supported_lsrs: List(#(Int, LSR)),
    supported_indexes: List(#(Int, Int)),
    supp_length: Int,
    num_paradigms: Int,
    order: List(#(LSR, Order)),
  )
}

fn classify_locales(
  locale_distance: locdistance.LocaleDistance,
  locales: List(String),
  lsrs: List(LSR),
  with_default: Bool,
  state: ClassifyState,
) -> ClassifyState {
  case locales, lsrs {
    [locale, ..rest_locales], [lsr_value, ..rest_lsrs] -> {
      let is_first_default = state.def_lsr == None && with_default
      let is_equiv_default = case state.def_lsr {
        Some(d) -> lsr.is_equivalent_to(lsr_value, d)
        None -> False
      }
      let state = case is_first_default, is_equiv_default {
        True, _ -> {
          let #(
            supported_lsr_to_index,
            supported_lsrs,
            supported_indexes,
            supp_length,
          ) =
            put_if_absent(
              state.supported_lsr_to_index,
              state.supported_lsrs,
              state.supported_indexes,
              lsr_value,
              0,
              state.supp_length,
            )
          ClassifyState(
            ..state,
            def: Some(locale),
            def_lsr: Some(lsr_value),
            supported_lsr_to_index:,
            supported_lsrs:,
            supported_indexes:,
            supp_length:,
            order: [#(lsr_value, Order1), ..state.order],
          )
        }
        False, True -> {
          let index_here = list.length(state.order)
          let #(
            supported_lsr_to_index,
            supported_lsrs,
            supported_indexes,
            supp_length,
          ) =
            put_if_absent(
              state.supported_lsr_to_index,
              state.supported_lsrs,
              state.supported_indexes,
              lsr_value,
              index_here,
              state.supp_length,
            )
          ClassifyState(
            ..state,
            supported_lsr_to_index:,
            supported_lsrs:,
            supported_indexes:,
            supp_length:,
            order: [#(lsr_value, Order1), ..state.order],
          )
        }
        False, False ->
          case locdistance.is_paradigm_lsr(locale_distance.state, lsr_value) {
            True ->
              ClassifyState(
                ..state,
                num_paradigms: state.num_paradigms + 1,
                order: [#(lsr_value, Order2), ..state.order],
              )
            False ->
              ClassifyState(..state, order: [
                #(lsr_value, Order3),
                ..state.order
              ])
          }
      }
      classify_locales(
        locale_distance,
        rest_locales,
        rest_lsrs,
        with_default,
        state,
      )
    }
    _, _ -> state
  }
}

pub fn create_locale_matcher(
  bundle: Bundle,
  supported_locale_names: List(String),
  builder_override: Option(LocaleMatcherBuilder),
) -> LocaleMatcher {
  let builder = case builder_override {
    Some(b) -> b
    None -> builder_from_supported_locales(supported_locale_names)
  }

  let likely_subtags = case loclikelysubtags.create_likely_subtags(bundle) {
    Ok(state) -> state
    Error(msg) -> panic as msg
  }
  let likely = loclikelysubtags.to_likely_subtags(likely_subtags)
  let locale_distance = locdistance.create_locale_distance(likely)
  let favor_subtag = builder.favor
  let direction = builder.direction

  let def = builder.default_locale
  let def_lsr = case def {
    Some(d) -> Some(get_maximal_lsr_or_und(likely_subtags, Some(d)))
    None -> None
  }

  let supported_locales_length = list.length(builder.supported_locales)

  let #(
    def,
    supported_locales,
    supported_lsr_to_index,
    supported_lsrs,
    supported_indexes,
    supported_lsrs_length,
  ) = case supported_locales_length > 0 {
    False -> #(def, [], dict.new(), dict.new(), dict.new(), 0)
    True -> {
      let lsrs =
        list.map(builder.supported_locales, fn(locale) {
          lsr.with_hash_code(get_maximal_lsr_or_und(
            likely_subtags,
            Some(locale),
          ))
        })

      let initial_state =
        ClassifyState(
          def:,
          def_lsr:,
          supported_lsr_to_index: dict.new(),
          supported_lsrs: [],
          supported_indexes: [],
          supp_length: 0,
          num_paradigms: 0,
          order: [],
        )

      let classified =
        classify_locales(
          locale_distance,
          builder.supported_locales,
          lsrs,
          builder.with_default,
          initial_state,
        )

      let order_list = list.reverse(classified.order)
      let paradigm_limit = classified.supp_length + classified.num_paradigms

      let #(
        supported_lsr_to_index,
        supported_lsrs,
        supported_indexes,
        supp_length,
      ) =
        fold_order2(
          order_list,
          0,
          classified.supported_lsr_to_index,
          classified.supported_lsrs,
          classified.supported_indexes,
          classified.supp_length,
          paradigm_limit,
        )

      let #(
        supported_lsr_to_index,
        supported_lsrs,
        supported_indexes,
        supp_length,
      ) =
        fold_order3(
          order_list,
          0,
          supported_lsr_to_index,
          supported_lsrs,
          supported_indexes,
          supp_length,
        )

      #(
        classified.def,
        builder.supported_locales,
        supported_lsr_to_index,
        index_dict(sparse_to_list(
          supported_lsrs,
          supp_length,
          lsr.create_lsr("", "", "", 0),
        )),
        index_dict(sparse_to_list(supported_indexes, supp_length, 0)),
        supp_length,
      )
    }
  }

  let demotion_per_desired_locale = case
    builder.demotion == ulocmatch_demotion_region
  {
    True -> locale_distance.default_demotion_per_desired_locale
    False -> 0
  }

  let threshold_distance = case builder.threshold_distance >= 0 {
    True -> builder.threshold_distance
    False ->
      case builder.max_distance_desired {
        Some(max_desired) -> {
          let supp_lsr =
            get_maximal_lsr_or_und(
              likely_subtags,
              builder.max_distance_supported,
            )
          let index_and_distance =
            locdistance.get_best_index_and_distance(
              locale_distance.state,
              get_maximal_lsr_or_und(likely_subtags, Some(max_desired)),
              dict.from_list([#(0, supp_lsr)]),
              1,
              locdistance.shift_distance(100),
              favor_subtag,
              direction,
            )
          locdistance.get_distance_floor(index_and_distance) + 1
        }
        None -> locale_distance.default_script_distance
      }
  }

  LocaleMatcher(
    bundle:,
    likely_subtags:,
    locale_distance:,
    threshold_distance:,
    demotion_per_desired_locale:,
    favor_subtag:,
    direction:,
    supported_locales:,
    supported_locales_by_index: index_dict(supported_locales),
    supported_locales_length:,
    supported_lsr_to_index:,
    supported_lsrs:,
    supported_indexes:,
    supported_lsrs_length:,
    default_locale: def,
  )
}

fn fold_order2(
  order_list: List(#(LSR, Order)),
  i: Int,
  supported_lsr_to_index: Dict(String, Int),
  supported_lsrs: List(#(Int, LSR)),
  supported_indexes: List(#(Int, Int)),
  supp_length: Int,
  paradigm_limit: Int,
) -> #(Dict(String, Int), List(#(Int, LSR)), List(#(Int, Int)), Int) {
  case order_list {
    [] -> #(
      supported_lsr_to_index,
      supported_lsrs,
      supported_indexes,
      supp_length,
    )
    [#(entry_lsr, order), ..rest] ->
      case supp_length >= paradigm_limit {
        True -> #(
          supported_lsr_to_index,
          supported_lsrs,
          supported_indexes,
          supp_length,
        )
        False ->
          case order == Order2 {
            False ->
              fold_order2(
                rest,
                i + 1,
                supported_lsr_to_index,
                supported_lsrs,
                supported_indexes,
                supp_length,
                paradigm_limit,
              )
            True -> {
              let #(
                supported_lsr_to_index,
                supported_lsrs,
                supported_indexes,
                supp_length,
              ) =
                put_if_absent(
                  supported_lsr_to_index,
                  supported_lsrs,
                  supported_indexes,
                  entry_lsr,
                  i,
                  supp_length,
                )
              fold_order2(
                rest,
                i + 1,
                supported_lsr_to_index,
                supported_lsrs,
                supported_indexes,
                supp_length,
                paradigm_limit,
              )
            }
          }
      }
  }
}

fn fold_order3(
  order_list: List(#(LSR, Order)),
  i: Int,
  supported_lsr_to_index: Dict(String, Int),
  supported_lsrs: List(#(Int, LSR)),
  supported_indexes: List(#(Int, Int)),
  supp_length: Int,
) -> #(Dict(String, Int), List(#(Int, LSR)), List(#(Int, Int)), Int) {
  case order_list {
    [] -> #(
      supported_lsr_to_index,
      supported_lsrs,
      supported_indexes,
      supp_length,
    )
    [#(entry_lsr, order), ..rest] ->
      case order == Order3 {
        False ->
          fold_order3(
            rest,
            i + 1,
            supported_lsr_to_index,
            supported_lsrs,
            supported_indexes,
            supp_length,
          )
        True -> {
          let #(
            supported_lsr_to_index,
            supported_lsrs,
            supported_indexes,
            supp_length,
          ) =
            put_if_absent(
              supported_lsr_to_index,
              supported_lsrs,
              supported_indexes,
              entry_lsr,
              i,
              supp_length,
            )
          fold_order3(
            rest,
            i + 1,
            supported_lsr_to_index,
            supported_lsrs,
            supported_indexes,
            supp_length,
          )
        }
      }
  }
}

fn get_best_supp_index(
  matcher: LocaleMatcher,
  desired_lsr: LSR,
) -> Option(Int) {
  let key = lsr_key(desired_lsr)
  case dict.get(matcher.supported_lsr_to_index, key) {
    Ok(index) -> Some(index)
    Error(_) -> {
      let best_index_and_distance =
        locdistance.get_best_index_and_distance(
          matcher.locale_distance.state,
          desired_lsr,
          matcher.supported_lsrs,
          matcher.supported_lsrs_length,
          locdistance.shift_distance(matcher.threshold_distance),
          matcher.favor_subtag,
          matcher.direction,
        )
      case best_index_and_distance < 0 {
        True -> None
        False ->
          Some(dict_at(
            matcher.supported_indexes,
            locdistance.get_index(best_index_and_distance),
            0,
          ))
      }
    }
  }
}

pub fn get_best_match(
  matcher: LocaleMatcher,
  desired_locale_id: String,
) -> Option(LocaleMatcherResult) {
  let desired_lsr =
    get_maximal_lsr_or_und(matcher.likely_subtags, Some(desired_locale_id))
  case get_best_supp_index(matcher, desired_lsr) {
    None -> None
    Some(supp_index) ->
      Some(create_result(
        Some(desired_locale_id),
        Some(dict_at(matcher.supported_locales_by_index, supp_index, "")),
        0,
        supp_index,
      ))
  }
}

pub fn accept_language_with_matcher(
  matcher: LocaleMatcher,
  accept_list: List(String),
  fallback: Bool,
  current_default: String,
) -> Option(String) {
  case accept_list {
    [] ->
      case fallback {
        True -> Some(current_default)
        False -> None
      }
    _ ->
      case find_first_match(matcher, accept_list) {
        Some(result) -> result.supported_locale
        None ->
          case fallback {
            True -> Some(current_default)
            False -> None
          }
      }
  }
}

fn find_first_match(
  matcher: LocaleMatcher,
  accept_list: List(String),
) -> Option(LocaleMatcherResult) {
  case accept_list {
    [] -> None
    [locale, ..rest] ->
      case get_best_match(matcher, locale) {
        Some(result) -> Some(result)
        None -> find_first_match(matcher, rest)
      }
  }
}
