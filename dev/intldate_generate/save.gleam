import intldate/internal/icu/icudata/resource

pub fn encode(value: a) -> BitArray {
  encode_value(value)
}

pub fn save_pattern_generators(generators: resource.PatternGenerators) -> Nil {
  save("patterngenerators", generators)
}

pub fn save_locale_data(locale: String, data: resource.LocaleData) -> Nil {
  save("locales/" <> locale, data)
}

pub fn save_zone_info_64(zone_info: resource.ZoneInfo64) -> Nil {
  save("zoneinfo64", zone_info)
}

pub fn save_supplemental_data(
  supplemental_data: resource.SupplementalData,
) -> Nil {
  save("supplementaldata", supplemental_data)
}

pub fn save_plurals(plurals: resource.Plurals) -> Nil {
  save("plurals", plurals)
}

pub fn save_numbering_systems(
  numbering_systems: resource.NumberingSystems,
) -> Nil {
  save("numberingsystems", numbering_systems)
}

pub fn save_timezone_types(timezone_types: resource.TimezoneTypes) -> Nil {
  save("timezonetypes", timezone_types)
}

pub fn save_day_period_rules_data(data: resource.DayPeriodRulesData) -> Nil {
  save("dayperiodrules", data)
}

pub fn save_likely_subtags_data(data: resource.LikelySubtagsData) -> Nil {
  save("likelysubtags", data)
}

pub fn save_loc_ext_key_map(key_map: resource.LocExtKeyMap) -> Nil {
  save("locextkeymap", key_map)
}

pub fn save_locale_parents(parents: resource.LocaleParents) -> Nil {
  save("localeparents", parents)
}

pub fn save_meta_zones_data(data: resource.MetaZonesData) -> Nil {
  save("metazonesdata", data)
}

fn save(id: String, data: a) -> Nil {
  save_value(id, data)
}

@external(erlang, "save_ffi", "encode")
fn encode_value(_value: a) -> BitArray {
  panic as "unsupported target"
}

@external(erlang, "save_ffi", "save")
fn save_value(_id: String, _data: a) -> Nil {
  panic as "unsupported target"
}
