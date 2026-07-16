import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import intldate/internal/icu/icudata/resource

pub type LoadError {
  FileError(id: String, reason: String)
  InvalidData(id: String, errors: List(decode.DecodeError))
}

pub fn describe_error(error: LoadError) -> String {
  case error {
    FileError(id, reason) -> "Could not load " <> id <> ".etf: " <> reason
    InvalidData(id, errors) ->
      "Invalid data in " <> id <> ".etf: " <> describe_decode_errors(errors)
  }
}

pub fn load_pattern_generators() -> Result(
  resource.PatternGenerators,
  LoadError,
) {
  load("patterngenerators", pattern_generators_decoder())
}

pub fn load_locale_data(
  locale: String,
) -> Result(resource.LocaleData, LoadError) {
  load("locales/" <> locale, locale_data_decoder())
}

pub fn load_zone_info_64() -> Result(resource.ZoneInfo64, LoadError) {
  load("zoneinfo64", zone_info64_decoder())
}

pub fn load_supplemental_data() -> Result(resource.SupplementalData, LoadError) {
  load("supplementaldata", supplemental_data_decoder())
}

pub fn load_plurals() -> Result(resource.Plurals, LoadError) {
  load("plurals", plurals_decoder())
}

pub fn load_numbering_systems() -> Result(resource.NumberingSystems, LoadError) {
  load("numberingsystems", numbering_systems_decoder())
}

pub fn load_timezone_types() -> Result(resource.TimezoneTypes, LoadError) {
  load("timezonetypes", timezone_types_decoder())
}

pub fn load_day_period_rules_data() -> Result(
  resource.DayPeriodRulesData,
  LoadError,
) {
  load("dayperiodrules", day_period_rules_data_decoder())
}

pub fn load_likely_subtags_data() -> Result(
  resource.LikelySubtagsData,
  LoadError,
) {
  load("likelysubtags", likely_subtags_data_decoder())
}

pub fn load_loc_ext_key_map() -> Result(resource.LocExtKeyMap, LoadError) {
  load("locextkeymap", decode.dict(decode.string, loc_ext_key_data_decoder()))
}

pub fn load_locale_parents() -> Result(resource.LocaleParents, LoadError) {
  load("localeparents", locale_parents_decoder())
}

pub fn load_meta_zones_data() -> Result(resource.MetaZonesData, LoadError) {
  load("metazonesdata", meta_zones_data_decoder())
}

fn load(id: String, decoder: decode.Decoder(a)) -> Result(a, LoadError) {
  use data <- result.try(
    load_uncached(id)
    |> result.map_error(fn(reason) { FileError(id:, reason:) }),
  )
  decode.run(data, decoder)
  |> result.map_error(fn(errors) { InvalidData(id:, errors:) })
}

@external(erlang, "intldate_loader_ffi", "load")
fn load_uncached(_id: String) -> Result(dynamic.Dynamic, String) {
  panic as "unsupported Target"
}

@external(erlang, "intldate_loader_ffi", "constructor_name")
fn constructor_name(_value: dynamic.Dynamic) -> Result(String, Nil) {
  panic as "unsupported Target"
}

fn describe_decode_errors(errors: List(decode.DecodeError)) -> String {
  case errors {
    [] -> "unknown decoding error"
    [error, ..] -> {
      let location = case error.path {
        [] -> ""
        path -> " at " <> string.join(path, ".")
      }
      "expected " <> error.expected <> ", found " <> error.found <> location
    }
  }
}

fn decode_error_name_at(names: List(String), index: Int) -> Option(String) {
  case names, index {
    [], _ -> None
    [name, ..], 0 -> Some(name)
    [_, ..rest], index if index > 0 -> decode_error_name_at(rest, index - 1)
    _, _ -> None
  }
}

fn rename_decode_error_path(
  path: List(String),
  names: List(String),
) -> List(String) {
  case path {
    [] -> []
    [segment, ..rest] ->
      case int.parse(segment) {
        Ok(index) ->
          case decode_error_name_at(names, index) {
            Some(name) -> [name, ..rest]
            None -> path
          }
        Error(_) -> path
      }
  }
}

fn option_decoder(inner: decode.Decoder(a)) -> decode.Decoder(Option(a)) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("none") -> decode.success(None)
    Ok("some") -> {
      use value <- decode.field(1, inner)
      decode.success(Some(value))
      |> decode.map_errors(fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "value"]),
          )
        })
      })
    }
    _ -> decode.failure(None, "Option")
  }
}

fn supplemental_data_decoder() -> decode.Decoder(resource.SupplementalData) {
  let fallback =
    resource.SupplementalData(
      time_data: dict_empty(),
      week_data: dict_empty(),
      calendar_preference: dict_empty(),
      japanese_eras: [],
    )
  let decoder = {
    use time_data <- decode.field(
      1,
      decode.dict(decode.string, time_data_decoder()),
    )
    use week_data <- decode.field(
      2,
      decode.dict(decode.string, week_data_decoder()),
    )
    use calendar_preference <- decode.field(
      3,
      decode.dict(decode.string, decode.list(decode.string)),
    )
    use japanese_eras <- decode.field(4, decode.list(japanese_era_decoder()))
    decode.success(resource.SupplementalData(
      time_data:,
      week_data:,
      calendar_preference:,
      japanese_eras:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "supplemental_data" -> decoder
      _ -> decode.failure(fallback, "supplemental_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "time_data",
          "week_data",
          "calendar_preference",
          "japanese_eras",
        ]),
      )
    })
  })
}

fn japanese_era_decoder() -> decode.Decoder(resource.JapaneseEra) {
  let fallback = resource.JapaneseEra(0, 0, 0, 0, False)
  let decoder = {
    use index <- decode.field(1, decode.int)
    use year <- decode.field(2, decode.int)
    use month <- decode.field(3, decode.int)
    use day <- decode.field(4, decode.int)
    use named <- decode.field(5, decode.bool)
    decode.success(resource.JapaneseEra(index:, year:, month:, day:, named:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "japanese_era" -> decoder
      _ -> decode.failure(fallback, "japanese_era")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "index",
          "year",
          "month",
          "day",
          "named",
        ]),
      )
    })
  })
}

fn time_data_decoder() -> decode.Decoder(resource.TimeData) {
  let fallback = resource.TimeData([], None)
  let decoder = {
    use allowed <- decode.field(1, decode.list(decode.string))
    use preferred <- decode.field(2, option_decoder(decode.string))
    decode.success(resource.TimeData(allowed:, preferred:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "time_data" -> decoder
      _ -> decode.failure(fallback, "time_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "allowed",
          "preferred",
        ]),
      )
    })
  })
}

fn week_data_decoder() -> decode.Decoder(#(Int, Int, Int, Int, Int, Int)) {
  {
    use a <- decode.field(0, decode.int)
    use b <- decode.field(1, decode.int)
    use c <- decode.field(2, decode.int)
    use d <- decode.field(3, decode.int)
    use e <- decode.field(4, decode.int)
    use f <- decode.field(5, decode.int)
    decode.success(#(a, b, c, d, e, f))
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "first_day",
          "minimal_days",
          "weekend_start",
          "weekend_start_millis",
          "weekend_end",
          "weekend_end_millis",
        ]),
      )
    })
  })
}

fn zone_info64_decoder() -> decode.Decoder(resource.ZoneInfo64) {
  let fallback = resource.ZoneInfo64(dict_empty(), dict_empty(), dict_empty())
  let decoder = {
    use zones <- decode.field(1, decode.dict(decode.string, zone_decoder()))
    use rules <- decode.field(
      2,
      decode.dict(decode.string, decode.list(decode.int)),
    )
    use regions <- decode.field(3, decode.dict(decode.string, decode.string))
    decode.success(resource.ZoneInfo64(zones:, rules:, regions:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "zone_info64" -> decoder
      _ -> decode.failure(fallback, "zone_info64")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "zones",
          "rules",
          "regions",
        ]),
      )
    })
  })
}

fn zone_decoder() -> decode.Decoder(resource.Zone) {
  let fallback = resource.Zone(0, dict_empty(), [], None, None)
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("zone") -> {
      let decoder = {
        use transitions_count <- decode.field(1, decode.int)
        use transitions_index <- decode.field(
          2,
          decode.dict(decode.int, decode.int),
        )
        use type_offsets <- decode.field(3, decode.list(decode.int))
        use type_map <- decode.field(4, option_decoder(decode.bit_array))
        use final_rule <- decode.field(5, option_decoder(final_rule_decoder()))
        decode.success(resource.Zone(
          transitions_count:,
          transitions_index:,
          type_offsets:,
          type_map:,
          final_rule:,
        ))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, [
              "type",
              "transitions_count",
              "transitions_index",
              "type_offsets",
              "type_map",
              "final_rule",
            ]),
          )
        })
      })
    }
    Ok("zone_alias") -> {
      let decoder = {
        use alias <- decode.field(1, decode.string)
        decode.success(resource.ZoneAlias(alias:))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "alias"]),
          )
        })
      })
    }
    _ -> decode.failure(fallback, "Zone")
  }
}

fn final_rule_decoder() -> decode.Decoder(resource.FinalRule) {
  let fallback = resource.FinalRule("", 0, 0)
  let decoder = {
    use rule <- decode.field(1, decode.string)
    use raw <- decode.field(2, decode.int)
    use year <- decode.field(3, decode.int)
    decode.success(resource.FinalRule(rule:, raw:, year:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "final_rule" -> decoder
      _ -> decode.failure(fallback, "final_rule")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "rule",
          "raw",
          "year",
        ]),
      )
    })
  })
}

fn plurals_decoder() -> decode.Decoder(resource.Plurals) {
  let fallback = resource.Plurals(dict_empty(), dict_empty(), dict_empty())
  let decoder = {
    use locales <- decode.field(1, decode.dict(decode.string, decode.string))
    use locales_ordinals <- decode.field(
      2,
      decode.dict(decode.string, decode.string),
    )
    use rules <- decode.field(
      3,
      decode.dict(decode.string, decode.list(plural_rule_decoder())),
    )
    decode.success(resource.Plurals(locales:, locales_ordinals:, rules:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "plurals" -> decoder
      _ -> decode.failure(fallback, "plurals")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "locales",
          "locales_ordinals",
          "rules",
        ]),
      )
    })
  })
}

fn num_range_decoder() -> decode.Decoder(resource.NumRange) {
  let fallback = resource.NumRange(0, 0)
  let decoder = {
    use lo <- decode.field(1, decode.int)
    use hi <- decode.field(2, decode.int)
    decode.success(resource.NumRange(lo:, hi:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "num_range" -> decoder
      _ -> decode.failure(fallback, "num_range")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, ["type", "lo", "hi"]),
      )
    })
  })
}

fn constraint_decoder() -> decode.Decoder(resource.Constraint) {
  let fallback = resource.Constraint("", None, False, [], False)
  let decoder = {
    use operand <- decode.field(1, decode.string)
    use mod <- decode.field(2, option_decoder(decode.int))
    use negated <- decode.field(3, decode.bool)
    use ranges <- decode.field(4, decode.list(num_range_decoder()))
    use integer_only <- decode.field(5, decode.bool)
    decode.success(resource.Constraint(
      operand:,
      mod:,
      negated:,
      ranges:,
      integer_only:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "constraint" -> decoder
      _ -> decode.failure(fallback, "constraint")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "operand",
          "mod",
          "negated",
          "ranges",
          "integer_only",
        ]),
      )
    })
  })
}

fn plural_rule_decoder() -> decode.Decoder(resource.PluralRule) {
  let fallback = resource.PluralRule("", None)
  let decoder = {
    use keyword <- decode.field(1, decode.string)
    use rule <- decode.field(
      2,
      option_decoder(decode.list(decode.list(constraint_decoder()))),
    )
    decode.success(resource.PluralRule(keyword:, rule:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "plural_rule" -> decoder
      _ -> decode.failure(fallback, "plural_rule")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, ["type", "keyword", "rule"]),
      )
    })
  })
}

fn numbering_systems_decoder() -> decode.Decoder(resource.NumberingSystems) {
  let fallback = resource.NumberingSystems(dict_empty())
  let decoder = {
    use numbering_systems <- decode.field(
      1,
      decode.dict(decode.string, numbering_system_decoder()),
    )
    decode.success(resource.NumberingSystems(numbering_systems:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "numbering_systems" -> decoder
      _ -> decode.failure(fallback, "numbering_systems")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, ["type", "numbering_systems"]),
      )
    })
  })
}

fn numbering_system_decoder() -> decode.Decoder(resource.NumberingSystem) {
  let fallback = resource.NumberingSystem(0, False, "", "")
  let decoder = {
    use radix <- decode.field(1, decode.int)
    use algorithmic <- decode.field(2, decode.bool)
    use desc <- decode.field(3, decode.string)
    use name <- decode.field(4, decode.string)
    decode.success(resource.NumberingSystem(radix:, algorithmic:, desc:, name:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "numbering_system" -> decoder
      _ -> decode.failure(fallback, "numbering_system")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "radix",
          "algorithmic",
          "desc",
          "name",
        ]),
      )
    })
  })
}

fn timezone_types_decoder() -> decode.Decoder(resource.TimezoneTypes) {
  let fallback =
    resource.TimezoneTypes(
      dict_empty(),
      dict_empty(),
      dict_empty(),
      dict_empty(),
    )
  let decoder = {
    use type_alias_timezone <- decode.field(
      1,
      decode.dict(decode.string, decode.string),
    )
    use type_map_timezone <- decode.field(
      2,
      decode.dict(decode.string, decode.string),
    )
    use bcp_type_alias_tz <- decode.field(
      3,
      decode.dict(decode.string, decode.string),
    )
    use single_zone_regions <- decode.field(
      4,
      decode.dict(decode.string, nil_decoder()),
    )
    decode.success(resource.TimezoneTypes(
      type_alias_timezone:,
      type_map_timezone:,
      bcp_type_alias_tz:,
      single_zone_regions:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "timezone_types" -> decoder
      _ -> decode.failure(fallback, "timezone_types")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "type_alias_timezone",
          "type_map_timezone",
          "bcp_type_alias_tz",
          "single_zone_regions",
        ]),
      )
    })
  })
}

fn nil_decoder() -> decode.Decoder(Nil) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("nil") -> decode.success(Nil)
    _ -> decode.failure(Nil, "Nil")
  }
}

fn day_period_decoder() -> decode.Decoder(resource.DayPeriod) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("day_period_unknown") -> decode.success(resource.DayPeriodUnknown)
    Ok("midnight") -> decode.success(resource.Midnight)
    Ok("noon") -> decode.success(resource.Noon)
    Ok("morning1") -> decode.success(resource.Morning1)
    Ok("afternoon1") -> decode.success(resource.Afternoon1)
    Ok("evening1") -> decode.success(resource.Evening1)
    Ok("night1") -> decode.success(resource.Night1)
    Ok("morning2") -> decode.success(resource.Morning2)
    Ok("afternoon2") -> decode.success(resource.Afternoon2)
    Ok("evening2") -> decode.success(resource.Evening2)
    Ok("night2") -> decode.success(resource.Night2)
    Ok("am") -> decode.success(resource.Am)
    Ok("pm") -> decode.success(resource.Pm)
    _ -> decode.failure(resource.DayPeriodUnknown, "DayPeriod")
  }
}

fn day_period_rules_decoder() -> decode.Decoder(resource.DayPeriodRules) {
  let fallback = resource.DayPeriodRules(False, False, dict_empty())
  let decoder = {
    use has_midnight <- decode.field(1, decode.bool)
    use has_noon <- decode.field(2, decode.bool)
    use day_period_for_hour <- decode.field(
      3,
      decode.dict(decode.int, day_period_decoder()),
    )
    decode.success(resource.DayPeriodRules(
      has_midnight:,
      has_noon:,
      day_period_for_hour:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "day_period_rules" -> decoder
      _ -> decode.failure(fallback, "day_period_rules")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "has_midnight",
          "has_noon",
          "day_period_for_hour",
        ]),
      )
    })
  })
}

fn day_period_rules_data_decoder() -> decode.Decoder(
  resource.DayPeriodRulesData,
) {
  let fallback = resource.DayPeriodRulesData(dict_empty(), dict_empty())
  let decoder = {
    use locales <- decode.field(1, decode.dict(decode.string, decode.int))
    use rules <- decode.field(
      2,
      decode.dict(decode.int, day_period_rules_decoder()),
    )
    decode.success(resource.DayPeriodRulesData(locales:, rules:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "day_period_rules_data" -> decoder
      _ -> decode.failure(fallback, "day_period_rules_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, ["type", "locales", "rules"]),
      )
    })
  })
}

fn loc_ext_type_decoder() -> decode.Decoder(resource.LocExtType) {
  let fallback = resource.LocExtType("", "")
  let decoder = {
    use legacy_id <- decode.field(1, decode.string)
    use bcp_id <- decode.field(2, decode.string)
    decode.success(resource.LocExtType(legacy_id:, bcp_id:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "loc_ext_type" -> decoder
      _ -> decode.failure(fallback, "loc_ext_type")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "legacy_id",
          "bcp_id",
        ]),
      )
    })
  })
}

fn loc_ext_key_data_decoder() -> decode.Decoder(resource.LocExtKeyData) {
  let fallback = resource.LocExtKeyData("", "", dict_empty(), 0)
  let decoder = {
    use legacy_id <- decode.field(1, decode.string)
    use bcp_id <- decode.field(2, decode.string)
    use type_map <- decode.field(
      3,
      decode.dict(decode.string, loc_ext_type_decoder()),
    )
    use special_types <- decode.field(4, decode.int)
    decode.success(resource.LocExtKeyData(
      legacy_id:,
      bcp_id:,
      type_map:,
      special_types:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "loc_ext_key_data" -> decoder
      _ -> decode.failure(fallback, "loc_ext_key_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "legacy_id",
          "bcp_id",
          "type_map",
          "special_types",
        ]),
      )
    })
  })
}

fn locale_parents_decoder() -> decode.Decoder(resource.LocaleParents) {
  let fallback = resource.LocaleParents(dict_empty(), dict_empty(), [])
  let decoder = {
    use overrides <- decode.field(1, decode.dict(decode.string, decode.string))
    use aliases <- decode.field(2, decode.dict(decode.string, decode.string))
    use installed_locales <- decode.field(3, decode.list(decode.string))
    decode.success(resource.LocaleParents(
      overrides:,
      aliases:,
      installed_locales:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "locale_parents" -> decoder
      _ -> decode.failure(fallback, "locale_parents")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "overrides",
          "aliases",
          "installed_locales",
        ]),
      )
    })
  })
}

fn pattern_generators_decoder() -> decode.Decoder(resource.PatternGenerators) {
  let fallback = resource.PatternGenerators(dict_empty(), dict_empty())
  let decoder = {
    use locale_to_generator <- decode.field(
      1,
      decode.dict(decode.string, decode.int),
    )
    use generators <- decode.field(2, decode.dict(decode.int, decode.bit_array))
    decode.success(resource.PatternGenerators(locale_to_generator:, generators:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "pattern_generators" -> decoder
      _ -> decode.failure(fallback, "pattern_generators")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "locale_to_generator",
          "generators",
        ]),
      )
    })
  })
}

fn number_system_symbols_decoder() -> decode.Decoder(
  resource.NumberSystemSymbols,
) {
  let fallback = resource.NumberSystemSymbols(None, None, None, None)
  let decoder = {
    use decimal_separator <- decode.field(1, option_decoder(decode.string))
    use grouping_separator <- decode.field(2, option_decoder(decode.string))
    use minus_sign <- decode.field(3, option_decoder(decode.string))
    use decimal_format_pattern <- decode.field(4, option_decoder(decode.string))
    decode.success(resource.NumberSystemSymbols(
      decimal_separator:,
      grouping_separator:,
      minus_sign:,
      decimal_format_pattern:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "number_system_symbols" -> decoder
      _ -> decode.failure(fallback, "number_system_symbols")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "decimal_separator",
          "grouping_separator",
          "minus_sign",
          "decimal_format_pattern",
        ]),
      )
    })
  })
}

fn metazone_mapping_decoder() -> decode.Decoder(resource.MetazoneMapping) {
  let fallback = resource.MetazoneMapping("", 0, 0)
  let decoder = {
    use name <- decode.field(1, decode.string)
    use from <- decode.field(2, decode.int)
    use to <- decode.field(3, decode.int)
    decode.success(resource.MetazoneMapping(name:, from:, to:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "metazone_mapping" -> decoder
      _ -> decode.failure(fallback, "metazone_mapping")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "name",
          "from",
          "to",
        ]),
      )
    })
  })
}

fn meta_zones_data_decoder() -> decode.Decoder(resource.MetaZonesData) {
  let fallback =
    resource.MetaZonesData(dict_empty(), dict_empty(), dict_empty())
  let decoder = {
    use metazone_info <- decode.field(
      1,
      decode.dict(decode.string, decode.list(metazone_mapping_decoder())),
    )
    use map_timezones <- decode.field(
      2,
      decode.dict(decode.string, decode.dict(decode.string, decode.string)),
    )
    use primary_zones <- decode.field(
      3,
      decode.dict(decode.string, decode.string),
    )
    decode.success(resource.MetaZonesData(
      metazone_info:,
      map_timezones:,
      primary_zones:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "meta_zones_data" -> decoder
      _ -> decode.failure(fallback, "meta_zones_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "metazone_info",
          "map_timezones",
          "primary_zones",
        ]),
      )
    })
  })
}

fn zone_strings_locale_decoder() -> decode.Decoder(resource.ZoneStringsLocale) {
  let fallback =
    resource.ZoneStringsLocale(dict_empty(), dict_empty(), dict_empty())
  let string_table =
    decode.dict(decode.string, decode.dict(decode.string, decode.string))
  let decoder = {
    use zones <- decode.field(1, string_table)
    use metazones <- decode.field(2, string_table)
    use globals <- decode.field(3, decode.dict(decode.string, decode.string))
    decode.success(resource.ZoneStringsLocale(zones:, metazones:, globals:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "zone_strings_locale" -> decoder
      _ -> decode.failure(fallback, "zone_strings_locale")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "zones",
          "metazones",
          "globals",
        ]),
      )
    })
  })
}

fn calendar_leaf_decoder(
  inner: decode.Decoder(a),
  fallback: a,
) -> decode.Decoder(resource.CalendarLeaf(a)) {
  let fallback_leaf = resource.CalendarLeafValue(fallback)
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("calendar_leaf_value") -> {
      let decoder = {
        use value <- decode.field(1, inner)
        decode.success(resource.CalendarLeafValue(value))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "value"]),
          )
        })
      })
    }
    Ok("calendar_leaf_alias_to") -> {
      let decoder = {
        use target <- decode.field(1, decode.string)
        decode.success(resource.CalendarLeafAliasTo(target))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "target"]),
          )
        })
      })
    }
    _ -> decode.failure(fallback_leaf, "CalendarLeaf")
  }
}

fn width_names_decoder() -> decode.Decoder(resource.WidthNames) {
  let fallback = resource.WidthNames(None, None, None, None)
  let leaf = calendar_leaf_decoder(decode.list(decode.string), [])
  let decoder = {
    use wide <- decode.field(1, option_decoder(leaf))
    use abbreviated <- decode.field(2, option_decoder(leaf))
    use narrow <- decode.field(3, option_decoder(leaf))
    use short <- decode.field(4, option_decoder(leaf))
    decode.success(resource.WidthNames(wide:, abbreviated:, narrow:, short:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "width_names" -> decoder
      _ -> decode.failure(fallback, "width_names")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "wide",
          "abbreviated",
          "narrow",
          "short",
        ]),
      )
    })
  })
}

fn context_names_decoder() -> decode.Decoder(resource.ContextNames) {
  let empty = resource.WidthNames(None, None, None, None)
  let fallback = resource.ContextNames(empty, empty)
  let decoder = {
    use format <- decode.field(1, width_names_decoder())
    use stand_alone <- decode.field(2, width_names_decoder())
    decode.success(resource.ContextNames(format:, stand_alone:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "context_names" -> decoder
      _ -> decode.failure(fallback, "context_names")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "format",
          "stand_alone",
        ]),
      )
    })
  })
}

fn width_table_decoder() -> decode.Decoder(resource.WidthTable) {
  let fallback = resource.WidthTable(None, None, None)
  let leaf =
    calendar_leaf_decoder(
      decode.dict(decode.string, decode.string),
      dict_empty(),
    )
  let decoder = {
    use wide <- decode.field(1, option_decoder(leaf))
    use abbreviated <- decode.field(2, option_decoder(leaf))
    use narrow <- decode.field(3, option_decoder(leaf))
    decode.success(resource.WidthTable(wide:, abbreviated:, narrow:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "width_table" -> decoder
      _ -> decode.failure(fallback, "width_table")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "wide",
          "abbreviated",
          "narrow",
        ]),
      )
    })
  })
}

fn context_table_decoder() -> decode.Decoder(resource.ContextTable) {
  let empty = resource.WidthTable(None, None, None)
  let fallback = resource.ContextTable(empty, empty)
  let decoder = {
    use format <- decode.field(1, width_table_decoder())
    use stand_alone <- decode.field(2, width_table_decoder())
    decode.success(resource.ContextTable(format:, stand_alone:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "context_table" -> decoder
      _ -> decode.failure(fallback, "context_table")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "format",
          "stand_alone",
        ]),
      )
    })
  })
}

fn month_pattern_widths_decoder() -> decode.Decoder(resource.MonthPatternWidths) {
  let fallback = resource.MonthPatternWidths(None, None, None)
  let leaf = calendar_leaf_decoder(decode.string, "")
  let decoder = {
    use wide <- decode.field(1, option_decoder(leaf))
    use abbreviated <- decode.field(2, option_decoder(leaf))
    use narrow <- decode.field(3, option_decoder(leaf))
    decode.success(resource.MonthPatternWidths(wide:, abbreviated:, narrow:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "month_pattern_widths" -> decoder
      _ -> decode.failure(fallback, "month_pattern_widths")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "wide",
          "abbreviated",
          "narrow",
        ]),
      )
    })
  })
}

fn month_patterns_data_decoder() -> decode.Decoder(resource.MonthPatternsData) {
  let empty = resource.MonthPatternWidths(None, None, None)
  let fallback = resource.MonthPatternsData(empty, empty, None)
  let decoder = {
    use format <- decode.field(1, month_pattern_widths_decoder())
    use stand_alone <- decode.field(2, month_pattern_widths_decoder())
    use numeric <- decode.field(
      3,
      option_decoder(calendar_leaf_decoder(decode.string, "")),
    )
    decode.success(resource.MonthPatternsData(format:, stand_alone:, numeric:))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "month_patterns_data" -> decoder
      _ -> decode.failure(fallback, "month_patterns_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "format",
          "stand_alone",
          "numeric",
        ]),
      )
    })
  })
}

fn calendar_field_decoder(
  inner: decode.Decoder(a),
  fallback: a,
) -> decode.Decoder(resource.CalendarField(a)) {
  let fallback_field = resource.CalendarValue(fallback)
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("calendar_value") -> {
      let decoder = {
        use value <- decode.field(1, inner)
        decode.success(resource.CalendarValue(value))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "value"]),
          )
        })
      })
    }
    Ok("calendar_alias_to") -> {
      let decoder = {
        use target <- decode.field(1, decode.string)
        decode.success(resource.CalendarAliasTo(target))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "target"]),
          )
        })
      })
    }
    _ -> decode.failure(fallback_field, "CalendarField")
  }
}

fn calendar_symbols_decoder() -> decode.Decoder(resource.CalendarSymbols) {
  let fallback =
    resource.CalendarSymbols(
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
    )
  let context_names =
    resource.ContextNames(
      resource.WidthNames(None, None, None, None),
      resource.WidthNames(None, None, None, None),
    )
  let width_table = resource.WidthTable(None, None, None)
  let context_table = resource.ContextTable(width_table, width_table)
  let month_patterns =
    resource.MonthPatternsData(
      resource.MonthPatternWidths(None, None, None),
      resource.MonthPatternWidths(None, None, None),
      None,
    )
  let decoder = {
    use month_names <- decode.field(
      1,
      option_decoder(calendar_field_decoder(
        context_names_decoder(),
        context_names,
      )),
    )
    use day_names <- decode.field(
      2,
      option_decoder(calendar_field_decoder(
        context_names_decoder(),
        context_names,
      )),
    )
    use quarters <- decode.field(
      3,
      option_decoder(calendar_field_decoder(
        context_names_decoder(),
        context_names,
      )),
    )
    use eras <- decode.field(
      4,
      option_decoder(calendar_field_decoder(width_table_decoder(), width_table)),
    )
    use am_pm_markers <- decode.field(
      5,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use am_pm_markers_abbr <- decode.field(
      6,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use am_pm_markers_narrow <- decode.field(
      7,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use day_period <- decode.field(
      8,
      option_decoder(calendar_field_decoder(
        context_table_decoder(),
        context_table,
      )),
    )
    use cyclic_years_abbreviated <- decode.field(
      9,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use month_patterns <- decode.field(
      10,
      option_decoder(calendar_field_decoder(
        month_patterns_data_decoder(),
        month_patterns,
      )),
    )
    decode.success(resource.CalendarSymbols(
      month_names:,
      day_names:,
      quarters:,
      eras:,
      am_pm_markers:,
      am_pm_markers_abbr:,
      am_pm_markers_narrow:,
      day_period:,
      cyclic_years_abbreviated:,
      month_patterns:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "calendar_symbols" -> decoder
      _ -> decode.failure(fallback, "calendar_symbols")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "month_names",
          "day_names",
          "quarters",
          "eras",
          "am_pm_markers",
          "am_pm_markers_abbr",
          "am_pm_markers_narrow",
          "day_period",
          "cyclic_years_abbreviated",
          "month_patterns",
        ]),
      )
    })
  })
}

fn interval_formats_decoder() -> decode.Decoder(resource.IntervalFormats) {
  let fallback = resource.IntervalFormats(dict_empty(), None)
  let decoder = {
    use patterns <- decode.field(
      1,
      decode.dict(decode.string, decode.dict(decode.string, decode.string)),
    )
    use fallback_pattern <- decode.field(2, option_decoder(decode.string))
    decode.success(resource.IntervalFormats(
      patterns:,
      fallback: fallback_pattern,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "interval_formats" -> decoder
      _ -> decode.failure(fallback, "interval_formats")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "patterns",
          "fallback",
        ]),
      )
    })
  })
}

fn available_format_decoder() -> decode.Decoder(resource.AvailableFormat) {
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("available_format_pattern") -> {
      let decoder = {
        use pattern <- decode.field(1, decode.string)
        decode.success(resource.AvailableFormatPattern(pattern))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "pattern"]),
          )
        })
      })
    }
    Ok("available_format_unavailable") ->
      decode.success(resource.AvailableFormatUnavailable)
    _ -> decode.failure(resource.AvailableFormatUnavailable, "AvailableFormat")
  }
}

fn date_interval_calendar_data_decoder() -> decode.Decoder(
  resource.DateIntervalCalendarData,
) {
  let fallback =
    resource.DateIntervalCalendarData(None, None, None, None, None, None)
  let interval_formats = resource.IntervalFormats(dict_empty(), None)
  let decoder = {
    use interval_formats <- decode.field(
      1,
      option_decoder(calendar_field_decoder(
        interval_formats_decoder(),
        interval_formats,
      )),
    )
    use date_time_combining_pattern <- decode.field(
      2,
      option_decoder(calendar_field_decoder(decode.string, "")),
    )
    use date_time_patterns <- decode.field(
      3,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use date_time_patterns_at_time <- decode.field(
      4,
      option_decoder(calendar_field_decoder(decode.list(decode.string), [])),
    )
    use append_items <- decode.field(
      5,
      option_decoder(calendar_field_decoder(
        decode.dict(decode.string, decode.string),
        dict_empty(),
      )),
    )
    use available_formats <- decode.field(
      6,
      option_decoder(calendar_field_decoder(
        decode.dict(decode.string, available_format_decoder()),
        dict_empty(),
      )),
    )
    decode.success(resource.DateIntervalCalendarData(
      interval_formats:,
      date_time_combining_pattern:,
      date_time_patterns:,
      date_time_patterns_at_time:,
      append_items:,
      available_formats:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "date_interval_calendar_data" -> decoder
      _ -> decode.failure(fallback, "date_interval_calendar_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "interval_formats",
          "date_time_combining_pattern",
          "date_time_patterns",
          "date_time_patterns_at_time",
          "append_items",
          "available_formats",
        ]),
      )
    })
  })
}

fn relative_unit_data_decoder() -> decode.Decoder(resource.RelativeUnitData) {
  let fallback =
    resource.RelativeUnitData(None, dict_empty(), dict_empty(), dict_empty())
  let decoder = {
    use display_name <- decode.field(1, option_decoder(decode.string))
    use relative <- decode.field(2, decode.dict(decode.string, decode.string))
    use past <- decode.field(3, decode.dict(decode.string, decode.string))
    use future <- decode.field(4, decode.dict(decode.string, decode.string))
    decode.success(resource.RelativeUnitData(
      display_name:,
      relative:,
      past:,
      future:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "relative_unit_data" -> decoder
      _ -> decode.failure(fallback, "relative_unit_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "display_name",
          "relative",
          "past",
          "future",
        ]),
      )
    })
  })
}

fn relative_field_decoder() -> decode.Decoder(resource.RelativeField) {
  let empty =
    resource.RelativeUnitData(None, dict_empty(), dict_empty(), dict_empty())
  let fallback = resource.RelativeFieldValue(empty)
  use value <- decode.then(decode.dynamic)
  case constructor_name(value) {
    Ok("relative_field_value") -> {
      let decoder = {
        use data <- decode.field(1, relative_unit_data_decoder())
        decode.success(resource.RelativeFieldValue(data))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "value"]),
          )
        })
      })
    }
    Ok("relative_field_alias_to") -> {
      let decoder = {
        use target <- decode.field(1, decode.string)
        decode.success(resource.RelativeFieldAliasTo(target))
      }
      decode.map_errors(decoder, fn(errors) {
        list.map(errors, fn(error) {
          decode.DecodeError(
            ..error,
            path: rename_decode_error_path(error.path, ["type", "target"]),
          )
        })
      })
    }
    _ -> decode.failure(fallback, "RelativeField")
  }
}

fn locale_data_decoder() -> decode.Decoder(resource.LocaleData) {
  let fallback = resource.LocaleData(None, None, None, None, None, None, None)
  let decoder = {
    use number_elements <- decode.field(
      1,
      option_decoder(decode.dict(decode.string, decode.string)),
    )
    use number_system_data <- decode.field(
      2,
      option_decoder(decode.dict(decode.string, number_system_symbols_decoder())),
    )
    use zone_strings <- decode.field(
      3,
      option_decoder(zone_strings_locale_decoder()),
    )
    use region_names <- decode.field(
      4,
      option_decoder(decode.dict(decode.string, decode.string)),
    )
    use calendar_symbols <- decode.field(
      5,
      option_decoder(decode.dict(decode.string, calendar_symbols_decoder())),
    )
    use date_interval_data <- decode.field(
      6,
      option_decoder(decode.dict(
        decode.string,
        date_interval_calendar_data_decoder(),
      )),
    )
    use relative_fields <- decode.field(
      7,
      option_decoder(decode.dict(decode.string, relative_field_decoder())),
    )
    decode.success(resource.LocaleData(
      number_elements:,
      number_system_data:,
      zone_strings:,
      region_names:,
      calendar_symbols:,
      date_interval_data:,
      relative_fields:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "locale_data" -> decoder
      _ -> decode.failure(fallback, "locale_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "number_elements",
          "number_system_data",
          "zone_strings",
          "region_names",
          "calendar_symbols",
          "date_interval_data",
          "relative_fields",
        ]),
      )
    })
  })
}

fn likely_subtags_data_decoder() -> decode.Decoder(resource.LikelySubtagsData) {
  let fallback =
    resource.LikelySubtagsData([], [], [], [], <<>>, [], [], [], <<>>, <<>>)
  let decoder = {
    use language_aliases <- decode.field(1, decode.list(decode.string))
    use lsrnum <- decode.field(2, decode.list(decode.int))
    use m49 <- decode.field(3, decode.list(decode.string))
    use region_aliases <- decode.field(4, decode.list(decode.string))
    use trie <- decode.field(5, decode.bit_array)
    use match_distances <- decode.field(6, decode.list(decode.int))
    use match_paradigmnum <- decode.field(7, decode.list(decode.int))
    use match_partitions <- decode.field(8, decode.list(decode.string))
    use match_region_to_partitions <- decode.field(9, decode.bit_array)
    use match_trie <- decode.field(10, decode.bit_array)
    decode.success(resource.LikelySubtagsData(
      language_aliases:,
      lsrnum:,
      m49:,
      region_aliases:,
      trie:,
      match_distances:,
      match_paradigmnum:,
      match_partitions:,
      match_region_to_partitions:,
      match_trie:,
    ))
  }
  {
    use value <- decode.then(decode.dynamic)
    case constructor_name(value) {
      Ok(found) if found == "likely_subtags_data" -> decoder
      _ -> decode.failure(fallback, "likely_subtags_data")
    }
  }
  |> decode.map_errors(fn(errors) {
    list.map(errors, fn(error) {
      decode.DecodeError(
        ..error,
        path: rename_decode_error_path(error.path, [
          "type",
          "language_aliases",
          "lsrnum",
          "m49",
          "region_aliases",
          "trie",
          "match_distances",
          "match_paradigmnum",
          "match_partitions",
          "match_region_to_partitions",
          "match_trie",
        ]),
      )
    })
  })
}

fn dict_empty() {
  dict.new()
}
