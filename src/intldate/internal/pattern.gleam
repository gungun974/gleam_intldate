import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Pattern {
  // G - Era name (e.g. "AD", "Anno Domini", "A")
  Era
  // y - Calendar year (e.g. 2, 20, 2017)
  CalendarYear
  // Y - Week-based year (e.g. 2, 20, 2017)
  WeekYear
  // u - Extended year, encompasses all supra-year fields (e.g. 4601)
  ExtendedYear
  // U - Cyclic year name, used in Chinese/Hindu calendars (e.g. 甲子)
  CyclicYearName
  // r - Related Gregorian year for non-Gregorian calendars (e.g. 2017)
  RelatedGregorianYear
  // Q - Quarter number/name (e.g. 2, Q2, "2nd quarter")
  Quarter
  // q - Stand-alone quarter number/name (e.g. 2, Q2, "2nd quarter")
  StandAloneQuarter
  // M - Format style month number/name (e.g. 9, Sep, September)
  Month
  // L - Stand-alone month number/name, typically nominative form (e.g. 9, Sep, September)
  StandAloneMonth
  // l - Deprecated leap month marker, should be ignored
  LeapMonthMarker
  // w - Week of year (e.g. 8, 27); use Y for year field when combined
  WeekOfYear
  // W - Week of month (e.g. 3)
  WeekOfMonth
  // d - Day of month (e.g. 1, 01)
  DayOfMonth
  // D - Day of year (e.g. 345)
  DayOfYear
  // F - Day of week in month (e.g. 2 for 2nd Wednesday in July)
  DayOfWeekInMonth
  // g - Modified Julian day, local zone midnight-based (e.g. 2451334)
  ModifiedJulianDay
  // E - Day of week name, format style (e.g. "Tue", "Tuesday", "T")
  DayOfWeek
  // e - Local day of week with numeric value depending on locale start day (e.g. 2, "Tue")
  LocalDayOfWeek
  // c - Stand-alone local day of week number/name (e.g. 2, "Tue", "Tuesday")
  StandAloneDayOfWeek
  // a - AM/PM marker (e.g. "am.", "AM")
  AmPm
  // b - AM, PM, noon or midnight marker (e.g. "mid.", "midnight")
  AmPmNoonMidnight
  // B - Flexible day period (e.g. "at night", "in the morning")
  FlexibleDayPeriod
  // h - Hour [1-12], matches locale 12-hour cycle (e.g. 1, 12)
  Hour12
  // H - Hour [0-23], matches locale 24-hour cycle (e.g. 0, 23)
  Hour24
  // K - Hour [0-11] (e.g. 0, 11)
  Hour11
  // k - Hour [1-24] (e.g. 1, 24)
  Hour24From1
  // j - Skeleton only: preferred hour format for locale, with day period (e.g. 8, 8 AM)
  PreferredHour
  // J - Skeleton only: preferred hour format for locale, without day period (e.g. 8, 08)
  PreferredHourNoPeriod
  // C - Skeleton only: preferred hour format allowing flexible day periods (e.g. "8 in the morning")
  FlexibleHour
  // m - Minute, truncated (e.g. 8, 59)
  Minute
  // s - Second, truncated (e.g. 8, 12)
  Second
  // S - Fractional second, truncated to field length (e.g. 3456)
  FractionalSecond
  // A - Milliseconds in day, reflects DST transitions (e.g. 69540000)
  MillisecondsInDay
  // z - Short specific non-location timezone (e.g. "PDT", "Pacific Daylight Time")
  ShortSpecificZone
  // Z - ISO8601 basic timezone format (e.g. "-0800", "GMT-8:00", "-08:00")
  IsoBasicZone
  // O - Short or long localized GMT format (e.g. "GMT-8", "GMT-08:00")
  ShortLocalizedGmt
  // v - Short or long generic non-location timezone (e.g. "PT", "Pacific Time")
  ShortGenericZone
  // V - Timezone ID, exemplar city or generic location (e.g. "uslax", "America/Los_Angeles", "Los Angeles Time")
  TimeZoneId
  // X - ISO8601 timezone with hours/minutes, "Z" for UTC (e.g. "-08", "-0800", "Z")
  IsoBasicZoneX
  // x - ISO8601 timezone with hours/minutes, "+" for UTC (e.g. "-08", "-0800", "+0000")
  IsoBasicZonex
}

pub type Field {
  Field(pattern: Pattern, width: Int)
}

pub type Node {
  NodeField(Field)
  NodeText(String)
}

fn char_to_pattern(ch: String) -> Result(Pattern, Nil) {
  case ch {
    "G" -> Ok(Era)
    "y" -> Ok(CalendarYear)
    "Y" -> Ok(WeekYear)
    "u" -> Ok(ExtendedYear)
    "U" -> Ok(CyclicYearName)
    "r" -> Ok(RelatedGregorianYear)
    "Q" -> Ok(Quarter)
    "q" -> Ok(StandAloneQuarter)
    "M" -> Ok(Month)
    "L" -> Ok(StandAloneMonth)
    "l" -> Ok(LeapMonthMarker)
    "w" -> Ok(WeekOfYear)
    "W" -> Ok(WeekOfMonth)
    "d" -> Ok(DayOfMonth)
    "D" -> Ok(DayOfYear)
    "F" -> Ok(DayOfWeekInMonth)
    "g" -> Ok(ModifiedJulianDay)
    "E" -> Ok(DayOfWeek)
    "e" -> Ok(LocalDayOfWeek)
    "c" -> Ok(StandAloneDayOfWeek)
    "a" -> Ok(AmPm)
    "b" -> Ok(AmPmNoonMidnight)
    "B" -> Ok(FlexibleDayPeriod)
    "h" -> Ok(Hour12)
    "H" -> Ok(Hour24)
    "K" -> Ok(Hour11)
    "k" -> Ok(Hour24From1)
    "j" -> Ok(PreferredHour)
    "J" -> Ok(PreferredHourNoPeriod)
    "C" -> Ok(FlexibleHour)
    "m" -> Ok(Minute)
    "s" -> Ok(Second)
    "S" -> Ok(FractionalSecond)
    "A" -> Ok(MillisecondsInDay)
    "z" -> Ok(ShortSpecificZone)
    "Z" -> Ok(IsoBasicZone)
    "O" -> Ok(ShortLocalizedGmt)
    "v" -> Ok(ShortGenericZone)
    "V" -> Ok(TimeZoneId)
    "X" -> Ok(IsoBasicZoneX)
    "x" -> Ok(IsoBasicZonex)
    _ -> Error(Nil)
  }
}

pub fn parse(raw: String) -> List(Node) {
  raw
  |> string.to_graphemes
  |> parse_loop(None, "", False, [])
  |> list.reverse
}

fn is_field_char(character: String) -> Bool {
  case char_to_pattern(character) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn flush_field(field: Option(#(String, Int)), acc: List(Node)) -> List(Node) {
  case field {
    None -> acc
    Some(#(char, width)) ->
      case char_to_pattern(char) {
        Ok(pattern) -> [NodeField(Field(pattern, width)), ..acc]
        Error(_) -> [NodeText(string.repeat(char, width)), ..acc]
      }
  }
}

fn flush_text(text: String, acc: List(Node)) -> List(Node) {
  case text {
    "" -> acc
    _ -> [NodeText(text), ..acc]
  }
}

fn parse_loop(
  chars: List(String),
  field: Option(#(String, Int)),
  text: String,
  inquote: Bool,
  acc: List(Node),
) -> List(Node) {
  case chars {
    [] -> flush_field(field, flush_text(text, acc))
    [character, ..rest] ->
      case inquote {
        True ->
          case character, rest {
            "'", ["'", ..rest] ->
              parse_loop(rest, field, text <> "'", True, acc)
            "'", _ -> parse_loop(rest, field, text, False, acc)
            _, _ -> parse_loop(rest, field, text <> character, True, acc)
          }
        False ->
          case character, rest {
            "'", ["'", ..rest] ->
              parse_loop(
                rest,
                None,
                text <> "'",
                False,
                flush_field(field, acc),
              )
            "'", _ ->
              parse_loop(rest, None, text, True, flush_field(field, acc))
            _, _ ->
              case is_field_char(character) {
                True ->
                  case field {
                    Some(#(char, width)) if char == character ->
                      parse_loop(
                        rest,
                        Some(#(char, width + 1)),
                        text,
                        False,
                        acc,
                      )
                    _ ->
                      parse_loop(
                        rest,
                        Some(#(character, 1)),
                        "",
                        False,
                        flush_field(field, flush_text(text, acc)),
                      )
                  }
                False ->
                  parse_loop(
                    rest,
                    None,
                    text <> character,
                    False,
                    flush_field(field, acc),
                  )
              }
          }
      }
  }
}
