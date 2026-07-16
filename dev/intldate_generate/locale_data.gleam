import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/icudata/bundle
import intldate/internal/icu/icudata/resource.{LocaleData}
import intldate_generate/save

fn optional_dict_value(
  values: dict.Dict(String, a),
  name: String,
) -> Option(a) {
  case dict.get(values, name) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

pub fn generate(_icu_path: String, generation_bundle: bundle.Bundle) {
  list.each(generation_bundle.locale_parents.installed_locales, fn(name) {
    save.save_locale_data(
      name,
      LocaleData(
        number_elements: optional_dict_value(
          generation_bundle.number_elements_by_locale.locales,
          name,
        ),
        number_system_data: optional_dict_value(
          generation_bundle.number_system_data_by_locale.locales,
          name,
        ),
        zone_strings: optional_dict_value(
          generation_bundle.zone_strings_by_locale.locales,
          name,
        ),
        region_names: optional_dict_value(
          generation_bundle.region_names_by_locale.locales,
          name,
        ),
        calendar_symbols: optional_dict_value(
          generation_bundle.calendar_symbols_by_locale.locales,
          name,
        ),
        date_interval_data: optional_dict_value(
          generation_bundle.date_interval_data_by_locale.locales,
          name,
        ),
        relative_fields: optional_dict_value(
          generation_bundle.relative_fields_by_locale.locales,
          name,
        ),
      ),
    )
  })
}
