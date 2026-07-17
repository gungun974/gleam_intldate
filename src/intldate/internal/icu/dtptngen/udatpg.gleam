import gleam/dict
import gleam/int
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/dtptngen/dtptngen.{
  type DateTimePatternGenerator, type DtRedundantEnumeration,
}
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/cache

const generator_cache_prefix = "dtpg:"

pub fn udatpg_match_hour_field_length() -> Int {
  dtptngen.udatpg_match_hour_field_length()
}

pub fn udatpg_open_memo(
  bundle: Bundle,
  locale_id: String,
) -> DateTimePatternGenerator {
  case dict.get(bundle.pattern_generators.locale_to_generator, locale_id) {
    Error(_) -> udatpg_open(bundle, Some(locale_id))
    Ok(generator_id) ->
      case cache.get(generator_cache_prefix <> int.to_string(generator_id)) {
        Ok(generator) -> generator
        Error(_) ->
          case dict.get(bundle.pattern_generators.generators, generator_id) {
            Ok(encoded) ->
              case dtptngen.dtpg_decode(encoded) {
                Ok(generator) ->
                  cache.put(
                    generator_cache_prefix <> int.to_string(generator_id),
                    dtptngen.dtpg_prepare_for_runtime(generator),
                  )
                Error(_) -> udatpg_open(bundle, Some(locale_id))
              }
            Error(_) -> udatpg_open(bundle, Some(locale_id))
          }
      }
  }
}

pub fn udatpg_open(
  bundle: Bundle,
  locale: Option(String),
) -> DateTimePatternGenerator {
  case locale {
    None ->
      dtptngen.dtpg_create_instance(bundle, "")
      |> dtptngen.dtpg_prepare_for_runtime
    Some(locale_id) ->
      dtptngen.dtpg_create_instance(bundle, locale_id)
      |> dtptngen.dtpg_prepare_for_runtime
  }
}

pub type BestPatternResult {
  BestPatternResult(dtpg: DateTimePatternGenerator, pattern: String)
}

pub fn udatpg_get_best_pattern_with_options(
  dtpg: DateTimePatternGenerator,
  skeleton: String,
  options: Int,
) -> BestPatternResult {
  let result =
    dtptngen.dtpg_get_best_pattern_with_options(dtpg, skeleton, options)
  BestPatternResult(result.dtpg, result.result)
}

pub fn udatpg_get_skeleton(pattern: String) -> String {
  let fp = dtptngen.create_format_parser()
  let #(_matcher, _fp, skeleton) = dtptngen.date_time_matcher_set(pattern, fp)
  dtptngen.ptn_skeleton_get_skeleton(skeleton)
}

pub type AddPatternResult {
  AddPatternResult(
    dtpg: DateTimePatternGenerator,
    conflicting_status: Int,
    conflicting_pattern: String,
  )
}

pub fn udatpg_get_default_hour_cycle(
  dtpg: DateTimePatternGenerator,
) -> Result(Int, String) {
  dtptngen.dtpg_get_default_hour_cycle(dtpg)
}

pub type RedundantsResult {
  RedundantsResult(
    dtpg: DateTimePatternGenerator,
    redundants: DtRedundantEnumeration,
  )
}
