import gleam/dict
import gleam/option.{type Option}

pub type SupplementalData {
  SupplementalData(
    time_data: dict.Dict(String, TimeData),
    week_data: dict.Dict(String, #(Int, Int, Int, Int, Int, Int)),
    calendar_preference: dict.Dict(String, List(String)),
    japanese_eras: List(JapaneseEra),
  )
}

pub type JapaneseEra {
  JapaneseEra(index: Int, year: Int, month: Int, day: Int, named: Bool)
}

pub type TimeData {
  TimeData(allowed: List(String), preferred: Option(String))
}

pub type ZoneInfo64 {
  ZoneInfo64(
    zones: dict.Dict(String, Zone),
    rules: dict.Dict(String, List(Int)),
    regions: dict.Dict(String, String),
  )
}

pub type Zone {
  Zone(
    transitions_count: Int,
    transitions_index: dict.Dict(Int, Int),
    type_offsets: List(Int),
    type_map: Option(BitArray),
    final_rule: Option(FinalRule),
  )
  ZoneAlias(alias: String)
}

pub type FinalRule {
  FinalRule(rule: String, raw: Int, year: Int)
}

pub type Plurals {
  Plurals(
    locales: dict.Dict(String, String),
    locales_ordinals: dict.Dict(String, String),
    rules: dict.Dict(String, List(PluralRule)),
  )
}

pub type NumRange {
  NumRange(lo: Int, hi: Int)
}

pub type Constraint {
  Constraint(
    operand: String,
    mod: Option(Int),
    negated: Bool,
    ranges: List(NumRange),
    integer_only: Bool,
  )
}

pub type PluralRule {
  PluralRule(keyword: String, rule: Option(List(List(Constraint))))
}

pub type NumberingSystems {
  NumberingSystems(numbering_systems: dict.Dict(String, NumberingSystem))
}

pub type NumberingSystem {
  NumberingSystem(radix: Int, algorithmic: Bool, desc: String, name: String)
}

pub type TimezoneTypes {
  TimezoneTypes(
    type_alias_timezone: dict.Dict(String, String),
    type_map_timezone: dict.Dict(String, String),
    bcp_type_alias_tz: dict.Dict(String, String),
    single_zone_regions: dict.Dict(String, Nil),
  )
}

pub type DayPeriod {
  DayPeriodUnknown
  Midnight
  Noon
  Morning1
  Afternoon1
  Evening1
  Night1
  Morning2
  Afternoon2
  Evening2
  Night2
  Am
  Pm
}

pub type DayPeriodRules {
  DayPeriodRules(
    has_midnight: Bool,
    has_noon: Bool,
    day_period_for_hour: dict.Dict(Int, DayPeriod),
  )
}

pub type DayPeriodRulesData {
  DayPeriodRulesData(
    locales: dict.Dict(String, Int),
    rules: dict.Dict(Int, DayPeriodRules),
  )
}

pub type LocExtType {
  LocExtType(legacy_id: String, bcp_id: String)
}

pub type LocExtKeyData {
  LocExtKeyData(
    legacy_id: String,
    bcp_id: String,
    type_map: dict.Dict(String, LocExtType),
    special_types: Int,
  )
}

pub type LocExtKeyMap =
  dict.Dict(String, LocExtKeyData)

pub type LocaleParents {
  LocaleParents(
    overrides: dict.Dict(String, String),
    aliases: dict.Dict(String, String),
    installed_locales: List(String),
  )
}

pub type PatternGenerators {
  PatternGenerators(
    locale_to_generator: dict.Dict(String, Int),
    generators: dict.Dict(Int, BitArray),
  )
}

pub type NumberElementsByLocale {
  NumberElementsByLocale(locales: dict.Dict(String, dict.Dict(String, String)))
}

pub type NumberSystemSymbols {
  NumberSystemSymbols(
    decimal_separator: Option(String),
    grouping_separator: Option(String),
    minus_sign: Option(String),
    decimal_format_pattern: Option(String),
  )
}

pub type NumberSystemDataByLocale {
  NumberSystemDataByLocale(
    locales: dict.Dict(String, dict.Dict(String, NumberSystemSymbols)),
  )
}

pub type MetazoneMapping {
  MetazoneMapping(name: String, from: Int, to: Int)
}

pub type MetaZonesData {
  MetaZonesData(
    metazone_info: dict.Dict(String, List(MetazoneMapping)),
    map_timezones: dict.Dict(String, dict.Dict(String, String)),
    primary_zones: dict.Dict(String, String),
  )
}

pub type ZoneStringsLocale {
  ZoneStringsLocale(
    zones: dict.Dict(String, dict.Dict(String, String)),
    metazones: dict.Dict(String, dict.Dict(String, String)),
    globals: dict.Dict(String, String),
  )
}

pub type ZoneStringsByLocale {
  ZoneStringsByLocale(locales: dict.Dict(String, ZoneStringsLocale))
}

pub type RegionNamesByLocale {
  RegionNamesByLocale(locales: dict.Dict(String, dict.Dict(String, String)))
}

/// A calendar value can also be an ICU alias at a leaf such as
/// `monthNames/format/abbreviated`. Keep the complete target path so the
/// runtime lookup can restart from the requesting locale's full fallback
/// chain, just like aliases on whole calendar fields.
pub type CalendarLeaf(t) {
  CalendarLeafValue(t)
  CalendarLeafAliasTo(String)
}

pub type WidthNames {
  WidthNames(
    wide: Option(CalendarLeaf(List(String))),
    abbreviated: Option(CalendarLeaf(List(String))),
    narrow: Option(CalendarLeaf(List(String))),
    short: Option(CalendarLeaf(List(String))),
  )
}

pub type ContextNames {
  ContextNames(format: WidthNames, stand_alone: WidthNames)
}

pub type WidthTable {
  WidthTable(
    wide: Option(CalendarLeaf(dict.Dict(String, String))),
    abbreviated: Option(CalendarLeaf(dict.Dict(String, String))),
    narrow: Option(CalendarLeaf(dict.Dict(String, String))),
  )
}

pub type ContextTable {
  ContextTable(format: WidthTable, stand_alone: WidthTable)
}

pub type MonthPatternWidths {
  MonthPatternWidths(
    wide: Option(CalendarLeaf(String)),
    abbreviated: Option(CalendarLeaf(String)),
    narrow: Option(CalendarLeaf(String)),
  )
}

pub type MonthPatternsData {
  MonthPatternsData(
    format: MonthPatternWidths,
    stand_alone: MonthPatternWidths,
    numeric: Option(CalendarLeaf(String)),
  )
}

/// A resource that ICU either defines directly for a (locale, calendar) pair,
/// or defines only as an `:alias` to the same field on a *different*
/// calendar (almost always `gregorian`) within the same locale. Aliases must
/// be followed by re-walking the requesting locale's *entire* chain for the
/// target calendar — not by substituting whatever the alias-defining locale
/// level happens to have — since day/month names are heavily localized and
/// the alias-defining level is very often just `root`.
pub type CalendarField(t) {
  CalendarValue(t)
  CalendarAliasTo(String)
}

pub type CalendarSymbols {
  CalendarSymbols(
    month_names: Option(CalendarField(ContextNames)),
    day_names: Option(CalendarField(ContextNames)),
    quarters: Option(CalendarField(ContextNames)),
    eras: Option(CalendarField(WidthTable)),
    am_pm_markers: Option(CalendarField(List(String))),
    am_pm_markers_abbr: Option(CalendarField(List(String))),
    am_pm_markers_narrow: Option(CalendarField(List(String))),
    day_period: Option(CalendarField(ContextTable)),
    cyclic_years_abbreviated: Option(CalendarField(List(String))),
    month_patterns: Option(CalendarField(MonthPatternsData)),
  )
}

pub type CalendarSymbolsByLocale {
  CalendarSymbolsByLocale(
    locales: dict.Dict(String, dict.Dict(String, CalendarSymbols)),
  )
}

pub type IntervalFormats {
  IntervalFormats(
    patterns: dict.Dict(String, dict.Dict(String, String)),
    fallback: Option(String),
  )
}

pub type DateIntervalCalendarData {
  DateIntervalCalendarData(
    interval_formats: Option(CalendarField(IntervalFormats)),
    date_time_combining_pattern: Option(CalendarField(String)),
    date_time_patterns: Option(CalendarField(List(String))),
    date_time_patterns_at_time: Option(CalendarField(List(String))),
    append_items: Option(CalendarField(dict.Dict(String, String))),
    available_formats: Option(CalendarField(dict.Dict(String, AvailableFormat))),
  )
}

pub type AvailableFormat {
  AvailableFormatPattern(String)
  AvailableFormatUnavailable
}

pub type DateIntervalDataByLocale {
  DateIntervalDataByLocale(
    locales: dict.Dict(String, dict.Dict(String, DateIntervalCalendarData)),
  )
}

pub type RelativeUnitData {
  RelativeUnitData(
    display_name: Option(String),
    relative: dict.Dict(String, String),
    past: dict.Dict(String, String),
    future: dict.Dict(String, String),
  )
}

pub type RelativeField {
  RelativeFieldValue(RelativeUnitData)
  RelativeFieldAliasTo(String)
}

pub type RelativeFieldsByLocale {
  RelativeFieldsByLocale(
    locales: dict.Dict(String, dict.Dict(String, RelativeField)),
  )
}

/// All generated data owned by one exact locale. Missing entries are kept as
/// `None` so lookups can continue through the ICU locale fallback chain.
pub type LocaleData {
  LocaleData(
    number_elements: Option(dict.Dict(String, String)),
    number_system_data: Option(dict.Dict(String, NumberSystemSymbols)),
    zone_strings: Option(ZoneStringsLocale),
    region_names: Option(dict.Dict(String, String)),
    calendar_symbols: Option(dict.Dict(String, CalendarSymbols)),
    date_interval_data: Option(dict.Dict(String, DateIntervalCalendarData)),
    relative_fields: Option(dict.Dict(String, RelativeField)),
  )
}

pub type LikelySubtagsData {
  LikelySubtagsData(
    language_aliases: List(String),
    lsrnum: List(Int),
    m49: List(String),
    region_aliases: List(String),
    trie: BitArray,
    match_distances: List(Int),
    match_paradigmnum: List(Int),
    match_partitions: List(String),
    match_region_to_partitions: BitArray,
    match_trie: BitArray,
  )
}
