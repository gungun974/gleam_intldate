import gleam/option.{type Option, None, Some}
import intldate/internal/icu/dtptngen/dtptngen.{
  type DateTimePatternGenerator, type DtRedundantEnumeration,
}
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resbund.{type Bundle}

pub fn udatpg_match_hour_field_length() -> Int {
  dtptngen.udatpg_match_hour_field_length()
}

pub fn udatpg_open_memo(
  bundle: Bundle,
  locale_id: String,
) -> DateTimePatternGenerator {
  let key = "dtpg\n" <> bundle.data_path <> "\n" <> locale_id
  case cache.get(key) {
    Ok(cached) -> udatpg_attach_chain(cached, bundle)
    Error(_) -> {
      let dtpg = udatpg_open(bundle, Some(locale_id))
      let _ = cache.put(key, udatpg_detach_chain(dtpg))
      dtpg
    }
  }
}

pub fn udatpg_detach_chain(
  dtpg: DateTimePatternGenerator,
) -> DateTimePatternGenerator {
  dtptngen.dtpg_detach_chain(dtpg)
}

pub fn udatpg_attach_chain(
  dtpg: DateTimePatternGenerator,
  bundle: Bundle,
) -> DateTimePatternGenerator {
  dtptngen.dtpg_attach_chain(dtpg, bundle)
}

pub fn udatpg_open(
  bundle: Bundle,
  locale: Option(String),
) -> DateTimePatternGenerator {
  case locale {
    None -> dtptngen.dtpg_create_instance(bundle, "")
    Some(locale_id) -> dtptngen.dtpg_create_instance(bundle, locale_id)
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
