import gleam/dict
import gleam/list
import gleam/option.{Some}
import intldate/internal/icu/dtptngen/dtptngen
import intldate/internal/icu/icudata/bundle
import intldate/internal/icu/icudata/resource.{PatternGenerators}
import intldate/internal/icu/locale/uloc
import intldate_generate/save

type PatternGeneratorState {
  // DTPGs are kept as compressed ETF binaries so loading the persistent Bundle
  // does not expand every generator. Equal binaries share a numeric id.
  PatternGeneratorState(
    locale_to_generator: dict.Dict(String, Int),
    generators: dict.Dict(Int, BitArray),
    generator_ids: dict.Dict(BitArray, Int),
    next_id: Int,
  )
}

const calendars = [
  "buddhist",
  "chinese",
  "coptic",
  "dangi",
  "ethioaa",
  "ethiopic",
  "gregory",
  "hebrew",
  "indian",
  "islamic",
  "islamic-umalqura",
  "islamic-tbla",
  "islamic-civil",
  "islamic-rgsa",
  "iso8601",
  "japanese",
  "persian",
  "roc",
]

fn add_pattern_generator(
  state: PatternGeneratorState,
  bundle: bundle.Bundle,
  locale_id: String,
) -> PatternGeneratorState {
  let encoded =
    dtptngen.dtpg_create_instance(bundle, locale_id)
    |> dtptngen.dtpg_detach_source_data
    |> save.encode
  case dict.get(state.generator_ids, encoded) {
    Ok(generator_id) ->
      PatternGeneratorState(
        ..state,
        locale_to_generator: dict.insert(
          state.locale_to_generator,
          locale_id,
          generator_id,
        ),
      )
    Error(_) -> {
      let generator_id = state.next_id
      PatternGeneratorState(
        locale_to_generator: dict.insert(
          state.locale_to_generator,
          locale_id,
          generator_id,
        ),
        generators: dict.insert(state.generators, generator_id, encoded),
        generator_ids: dict.insert(state.generator_ids, encoded, generator_id),
        next_id: generator_id + 1,
      )
    }
  }
}

fn add_calendar_pattern_generators(
  state: PatternGeneratorState,
  bundle: bundle.Bundle,
  locale_id: String,
) -> PatternGeneratorState {
  list.fold(calendars, state, fn(state, calendar) {
    let assert Some(legacy) =
      uloc.uloc_to_legacy_type(Some(bundle), "calendar", calendar)
    let assert Ok(calendar_locale_id) =
      uloc.set_keyword_value("calendar", Some(legacy), locale_id)
    add_pattern_generator(state, bundle, calendar_locale_id)
  })
}

pub fn generate(_icu_path: String, generation_bundle: bundle.Bundle) {
  let initial =
    PatternGeneratorState(
      locale_to_generator: dict.new(),
      generators: dict.new(),
      generator_ids: dict.new(),
      next_id: 0,
    )
  let generated =
    list.fold(
      generation_bundle.locale_parents.installed_locales,
      initial,
      fn(state, locale_id) {
        let state = add_pattern_generator(state, generation_bundle, locale_id)
        add_calendar_pattern_generators(state, generation_bundle, locale_id)
      },
    )
  save.save_pattern_generators(PatternGenerators(
    locale_to_generator: generated.locale_to_generator,
    generators: generated.generators,
  ))
}
