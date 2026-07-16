import argv
import intldate/internal/icu/icudata/bundle
import intldate_generate/calendar_symbols
import intldate_generate/date_interval_data
import intldate_generate/day_period_rules
import intldate_generate/download
import intldate_generate/likely_subtags
import intldate_generate/loc_ext_key_map
import intldate_generate/locale_data
import intldate_generate/locale_parents
import intldate_generate/log
import intldate_generate/meta_zones
import intldate_generate/number_elements
import intldate_generate/number_system_data
import intldate_generate/numbering_systems
import intldate_generate/pattern_generators
import intldate_generate/plurals
import intldate_generate/region_names
import intldate_generate/relative_fields
import intldate_generate/supplemental_data
import intldate_generate/timezone_types
import intldate_generate/zone_strings
import intldate_generate/zoneinfo64
import simplifile

pub fn main() {
  case argv.load().arguments {
    ["clean", ..] -> log.step("Cleanup", clean)
    _ -> log.step("Generation", generate)
  }
}

fn clean() -> Nil {
  let assert Ok(Nil) = simplifile.delete_all(["./.cache", "./priv/generated"])
  Nil
}

fn generate() {
  let icu_path =
    download.download(
      id: "icu",
      version: "release-78.3",
      url: "https://github.com/unicode-org/icu/archive/refs/tags/release-78.3.tar.gz",
      root: "icu-release-78.3",
      sha256: "f06bcab72736ee9d55689033b8198a178562354128cf38edb2afc2e67e3fd931",
    )

  let zone_info =
    log.step("Zone information", fn() { zoneinfo64.generate(icu_path) })
  let supplemental_data =
    log.step("Supplemental data", fn() { supplemental_data.generate(icu_path) })
  let plurals = log.step("Plural rules", fn() { plurals.generate(icu_path) })
  let numbering_systems =
    log.step("Numbering systems", fn() { numbering_systems.generate(icu_path) })
  let timezone_types =
    log.step("Time zone types", fn() {
      timezone_types.generate(icu_path, zone_info)
    })
  let day_period_rules =
    log.step("Day period rules", fn() { day_period_rules.generate(icu_path) })
  let likely_subtags =
    log.step("Likely subtags", fn() { likely_subtags.generate(icu_path) })
  let loc_ext_key_map =
    log.step("Locale extension key map", fn() {
      loc_ext_key_map.generate(icu_path, timezone_types)
    })
  let locale_parents =
    log.step("Locale parents", fn() { locale_parents.generate(icu_path) })
  let number_elements_by_locale =
    log.step("Locale number elements", fn() {
      number_elements.generate(icu_path)
    })
  let number_system_data_by_locale =
    log.step("Locale number system data", fn() {
      number_system_data.generate(icu_path)
    })
  let meta_zones =
    log.step("Meta zones", fn() { meta_zones.generate(icu_path) })
  let zone_strings_by_locale =
    log.step("Locale zone strings", fn() { zone_strings.generate(icu_path) })
  let region_names_by_locale =
    log.step("Locale region names", fn() { region_names.generate(icu_path) })
  let calendar_symbols_by_locale =
    log.step("Locale calendar symbols", fn() {
      calendar_symbols.generate(icu_path)
    })
  let date_interval_data_by_locale =
    log.step("Locale date interval data", fn() {
      date_interval_data.generate(icu_path)
    })
  let relative_fields_by_locale =
    log.step("Locale relative fields", fn() {
      relative_fields.generate(icu_path)
    })
  let generation_bundle =
    bundle.create_generation_bundle(
      zone_info_64: zone_info,
      supplemental_data:,
      plurals:,
      numbering_systems:,
      timezone_types:,
      day_period_rules:,
      likely_subtags:,
      loc_ext_key_map:,
      locale_parents:,
      number_elements_by_locale:,
      number_system_data_by_locale:,
      meta_zones:,
      zone_strings_by_locale:,
      region_names_by_locale:,
      calendar_symbols_by_locale:,
      date_interval_data_by_locale:,
      relative_fields_by_locale:,
    )
  log.step("Pattern generators", fn() {
    pattern_generators.generate(icu_path, generation_bundle)
  })
  log.step("Per-locale bundles", fn() {
    locale_data.generate(icu_path, generation_bundle)
  })
}
