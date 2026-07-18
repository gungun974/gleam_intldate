import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/bundle.{type Bundle}
import intldate/internal/icu/icudata/resource.{type ZoneInfo64}
import intldate/internal/math

const ucal_january = 0

const millis_per_day = 86_400_000

pub type RuleMode {
  DomMode
  DowInMonthMode
  DowGeDomMode
  DowLeDomMode
}

pub type TimeMode {
  WallTime
  StandardTime
  UtcTime
}

fn time_mode_from_int(value: Int) -> TimeMode {
  case value {
    0 -> WallTime
    2 -> UtcTime
    _ -> StandardTime
  }
}

pub type DecodedRule {
  DecodedRule(mode: RuleMode, month: Int, day: Int, day_of_week: Int)
}

pub type FinalRule {
  FinalRule(
    final_raw: Int,
    final_start_millis: Int,
    use_daylight: Bool,
    start: DecodedRule,
    start_time: Int,
    start_time_mode: TimeMode,
    end: DecodedRule,
    end_time: Int,
    end_time_mode: TimeMode,
    dst_savings: Int,
  )
}

pub type ZoneData {
  ZoneData(
    transitions_count: Int,
    transitions_index: Dict(Int, Int),
    type_offsets: List(Int),
    type_map_data: Option(BitArray),
    final_rule: Option(FinalRule),
  )
}

pub type ZoneOffset {
  ZoneOffset(raw_offset: Int, dst_offset: Int)
}

type TransitionWindow {
  TransitionWindow(previous: Option(#(Int, Int)), next: Option(#(Int, Int)))
}

fn decode_rule(month: Int, day: Int, day_of_week: Int) -> DecodedRule {
  case day == 0 {
    True -> DecodedRule(DomMode, month, day, 0)
    False ->
      case day_of_week == 0 {
        True -> DecodedRule(DomMode, month, day, 0)
        False ->
          case day_of_week > 0 {
            True -> DecodedRule(DowInMonthMode, month, day, day_of_week)
            False -> {
              let day_of_week = -day_of_week
              case day > 0 {
                True -> DecodedRule(DowGeDomMode, month, day, day_of_week)
                False -> DecodedRule(DowLeDomMode, month, -day, day_of_week)
              }
            }
          }
      }
  }
}

fn load_final_rule(
  final_rule: Option(resource.FinalRule),
  rules: dict.Dict(String, List(Int)),
) -> Option(FinalRule) {
  case final_rule {
    None -> None
    Some(final_rule) -> {
      case dict.get(rules, final_rule.rule) {
        Error(_) -> None
        Ok(rule_data) ->
          build_final_rule(final_rule.raw, final_rule.year, rule_data)
      }
    }
  }
}

fn build_final_rule(
  final_raw: Int,
  final_year: Int,
  rule_data: List(Int),
) -> Option(FinalRule) {
  let final_start_millis =
    gregoimp.fields_to_day(final_year, ucal_january, 1) * millis_per_day

  case rule_data {
    [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, ..] -> {
      let use_daylight = r1 != 0 && r6 != 0
      let start = decode_rule(r0, r1, r2)
      let end = decode_rule(r5, r6, r7)

      Some(FinalRule(
        final_raw:,
        final_start_millis:,
        use_daylight:,
        start:,
        start_time: r3,
        start_time_mode: time_mode_from_int(r4),
        end:,
        end_time: r8,
        end_time_mode: time_mode_from_int(r9),
        dst_savings: r10,
      ))
    }
    _ -> None
  }
}

pub fn load_zone_data(
  zone_info: ZoneInfo64,
  canonical_tzid: String,
) -> Option(ZoneData) {
  let zone = dict.get(zone_info.zones, canonical_tzid)

  let zone = case zone {
    Ok(resource.ZoneAlias(alias)) -> dict.get(zone_info.zones, alias)
    _ -> zone
  }

  case zone {
    Ok(resource.Zone(
      transitions_count:,
      transitions_index:,
      type_offsets:,
      type_map:,
      final_rule:,
    )) ->
      Some(ZoneData(
        transitions_count:,
        transitions_index:,
        type_offsets:,
        type_map_data: type_map,
        final_rule: load_final_rule(final_rule, zone_info.rules),
      ))
    _ -> None
  }
}

fn type_map_byte_at(type_map_data: Option(BitArray), index: Int) -> Int {
  case type_map_data {
    None -> 0
    Some(data) ->
      case bit_array_byte_at(data, index) {
        Some(b) -> b
        None -> 0
      }
  }
}

fn bit_array_byte_at(data: BitArray, index: Int) -> Option(Int) {
  bit_array_byte_at_loop(data, index)
}

fn bit_array_byte_at_loop(data: BitArray, index: Int) -> Option(Int) {
  case data {
    <<byte, rest:bytes>> ->
      case index {
        0 -> Some(byte)
        _ -> bit_array_byte_at_loop(rest, index - 1)
      }
    _ -> None
  }
}

fn compare_to_rule(
  month: Int,
  month_length: Int,
  prev_month_length: Int,
  day_of_month: Int,
  day_of_week: Int,
  millis: Int,
  millis_delta: Int,
  rule: DecodedRule,
  rule_time: Int,
) -> Int {
  let millis = millis + millis_delta
  let #(millis, day_of_month, day_of_week, month) =
    normalize_forward(millis, day_of_month, day_of_week, month, month_length)
  let #(millis, day_of_month, day_of_week, month) =
    normalize_backward(
      millis,
      day_of_month,
      day_of_week,
      month,
      prev_month_length,
    )

  case month < rule.month {
    True -> -1
    False ->
      case month > rule.month {
        True -> 1
        False ->
          compare_to_rule_day(
            month_length,
            day_of_month,
            day_of_week,
            millis,
            rule,
            rule_time,
          )
      }
  }
}

fn normalize_forward(
  millis: Int,
  day_of_month: Int,
  day_of_week: Int,
  month: Int,
  month_length: Int,
) -> #(Int, Int, Int, Int) {
  case millis >= millis_per_day {
    False -> #(millis, day_of_month, day_of_week, month)
    True -> {
      let millis = millis - millis_per_day
      let day_of_month = day_of_month + 1
      let day_of_week = 1 + day_of_week % 7
      let #(day_of_month, month) = case day_of_month > month_length {
        True -> #(1, month + 1)
        False -> #(day_of_month, month)
      }
      normalize_forward(millis, day_of_month, day_of_week, month, month_length)
    }
  }
}

fn normalize_backward(
  millis: Int,
  day_of_month: Int,
  day_of_week: Int,
  month: Int,
  prev_month_length: Int,
) -> #(Int, Int, Int, Int) {
  case millis < 0 {
    False -> #(millis, day_of_month, day_of_week, month)
    True -> {
      let millis = millis + millis_per_day
      let day_of_month = day_of_month - 1
      let day_of_week = 1 + { day_of_week + 5 } % 7
      let #(day_of_month, month) = case day_of_month < 1 {
        True -> #(prev_month_length, month - 1)
        False -> #(day_of_month, month)
      }
      normalize_backward(
        millis,
        day_of_month,
        day_of_week,
        month,
        prev_month_length,
      )
    }
  }
}

fn compare_to_rule_day(
  month_length: Int,
  day_of_month: Int,
  day_of_week: Int,
  millis: Int,
  rule: DecodedRule,
  rule_time: Int,
) -> Int {
  let rule_day = case rule.day > month_length {
    True -> month_length
    False -> rule.day
  }

  let rule_day_of_month = case rule.mode {
    DomMode -> rule_day
    DowInMonthMode ->
      case rule_day > 0 {
        True ->
          1
          + { rule_day - 1 }
          * 7
          + {
            { 7 + rule.day_of_week - { day_of_week - day_of_month + 1 } }
            % 7
            + 7
          }
          % 7
        False ->
          month_length
          + { rule_day + 1 }
          * 7
          - {
            {
              7
              + { day_of_week + month_length - day_of_month }
              - rule.day_of_week
            }
            % 7
            + 7
          }
          % 7
      }
    DowGeDomMode ->
      rule_day
      + {
        { 49 + rule.day_of_week - rule_day - day_of_week + day_of_month }
        % 7
        + 7
      }
      % 7
    DowLeDomMode ->
      rule_day
      - {
        { 49 - rule.day_of_week + rule_day + day_of_week - day_of_month }
        % 7
        + 7
      }
      % 7
  }

  case day_of_month < rule_day_of_month {
    True -> -1
    False ->
      case day_of_month > rule_day_of_month {
        True -> 1
        False ->
          case millis < rule_time {
            True -> -1
            False ->
              case millis > rule_time {
                True -> 1
                False -> 0
              }
          }
      }
  }
}

fn simple_time_zone_offset(
  final_rule: FinalRule,
  _year: Int,
  month: Int,
  dom: Int,
  dow: Int,
  millis: Int,
  month_length: Int,
  prev_month_length: Int,
) -> Int {
  let raw_offset = final_rule.final_raw * 1000
  case !final_rule.use_daylight {
    True -> raw_offset
    False -> {
      let southern = final_rule.start.month > final_rule.end.month

      let start_delta = case final_rule.start_time_mode {
        UtcTime -> -raw_offset
        WallTime | StandardTime -> 0
      }
      let start_compare =
        compare_to_rule(
          month,
          month_length,
          prev_month_length,
          dom,
          dow,
          millis,
          start_delta,
          final_rule.start,
          final_rule.start_time * 1000,
        )

      let end_compare = case southern != start_compare >= 0 {
        False -> 0
        True -> {
          let end_delta = case final_rule.end_time_mode {
            WallTime -> final_rule.dst_savings * 1000
            UtcTime -> -raw_offset
            StandardTime -> 0
          }
          compare_to_rule(
            month,
            month_length,
            prev_month_length,
            dom,
            dow,
            millis,
            end_delta,
            final_rule.end,
            final_rule.end_time * 1000,
          )
        }
      }

      let in_dst = case !southern {
        True -> start_compare >= 0 && end_compare < 0
        False -> southern && { start_compare >= 0 || end_compare < 0 }
      }
      case in_dst {
        True -> raw_offset + final_rule.dst_savings * 1000
        False -> raw_offset
      }
    }
  }
}

fn get_final_rule_offset(
  final_rule: FinalRule,
  epoch_millis: Int,
) -> ZoneOffset {
  let raw_offset = final_rule.final_raw * 1000
  let local_millis = epoch_millis + raw_offset
  let fields = gregoimp.time_to_fields(local_millis)
  let month_length = gregoimp.month_length(fields.year, fields.month)
  let prev_month_length =
    gregoimp.previous_month_length(fields.year, fields.month)
  let total =
    simple_time_zone_offset(
      final_rule,
      fields.year,
      fields.month,
      fields.dom,
      fields.dow,
      fields.millis_in_day,
      month_length,
      prev_month_length,
    )
  ZoneOffset(raw_offset:, dst_offset: total - raw_offset)
}

fn offset_pair_at(type_offsets: List(Int), pair_index: Int) -> #(Int, Int) {
  case type_offsets, pair_index {
    [raw, dst, ..], 0 -> #(raw, dst)
    [_, _, ..rest], _ -> offset_pair_at(rest, pair_index - 1)
    _, _ -> #(0, 0)
  }
}

fn base_offset_pair(type_offsets: List(Int)) -> #(Int, Int) {
  offset_pair_at(type_offsets, 0)
}

fn offset_pair_for_transition_type(
  type_offsets: List(Int),
  type_map_data: Option(BitArray),
  transition_index: Int,
) -> #(Int, Int) {
  let pair_index = case transition_index >= 0 {
    True -> type_map_byte_at(type_map_data, transition_index)
    False -> 0
  }
  offset_pair_at(type_offsets, pair_index)
}

fn transition_at(transitions_index: Dict(Int, Int), index: Int) -> Int {
  let assert Ok(transition) = dict.get(transitions_index, index)
  transition
}

fn find_transition_window(
  transitions_index: Dict(Int, Int),
  transitions_count: Int,
  sec: Int,
) -> TransitionWindow {
  let next_idx =
    find_next_transition_idx(transitions_index, sec, 0, transitions_count)
  let previous = case next_idx {
    0 -> None
    _ -> Some(#(next_idx - 1, transition_at(transitions_index, next_idx - 1)))
  }
  let next = case next_idx >= transitions_count {
    True -> None
    False -> Some(#(next_idx, transition_at(transitions_index, next_idx)))
  }
  TransitionWindow(previous:, next:)
}

fn find_next_transition_idx(
  transitions_index: Dict(Int, Int),
  sec: Int,
  low: Int,
  high: Int,
) -> Int {
  case low >= high {
    True -> low
    False -> {
      let mid = low + { high - low } / 2
      case sec < transition_at(transitions_index, mid) {
        True -> find_next_transition_idx(transitions_index, sec, low, mid)
        False -> find_next_transition_idx(transitions_index, sec, mid + 1, high)
      }
    }
  }
}

pub fn get_offset(
  bundle: Bundle,
  canonical_tzid: String,
  epoch_millis: Int,
) -> ZoneOffset {
  let zone_info = bundle.zone_info_64
  case load_zone_data(zone_info, canonical_tzid) {
    None -> ZoneOffset(0, 0)
    Some(zone_data) ->
      case zone_data.final_rule {
        Some(final_rule) if epoch_millis >= final_rule.final_start_millis ->
          get_final_rule_offset(final_rule, epoch_millis)
        _ -> {
          case zone_data.transitions_count {
            0 -> {
              let #(raw, dst) = base_offset_pair(zone_data.type_offsets)
              ZoneOffset(raw * 1000, dst * 1000)
            }
            _ -> {
              let sec = math.floor_div(epoch_millis, 1000)
              let window =
                find_transition_window(
                  zone_data.transitions_index,
                  zone_data.transitions_count,
                  sec,
                )
              case window.previous {
                None -> {
                  let #(raw, dst) = base_offset_pair(zone_data.type_offsets)
                  ZoneOffset(raw * 1000, dst * 1000)
                }
                Some(#(idx, _)) -> {
                  let #(raw, dst) =
                    offset_pair_for_transition_type(
                      zone_data.type_offsets,
                      zone_data.type_map_data,
                      idx,
                    )
                  ZoneOffset(raw * 1000, dst * 1000)
                }
              }
            }
          }
        }
      }
  }
}

pub fn get_offset_local(
  bundle: Bundle,
  canonical_tzid: String,
  local_millis: Int,
) -> ZoneOffset {
  let offset = get_offset(bundle, canonical_tzid, local_millis)
  let resolved =
    get_offset_local_loop(bundle, canonical_tzid, local_millis, offset, 0)
  let resolved_epoch = local_millis - resolved.raw_offset - resolved.dst_offset
  let before =
    get_offset(bundle, canonical_tzid, resolved_epoch - millis_per_day)
  let after =
    get_offset(bundle, canonical_tzid, resolved_epoch + millis_per_day)
  resolved
  |> prefer_later_valid_local_offset(
    bundle,
    canonical_tzid,
    local_millis,
    before,
  )
  |> prefer_later_valid_local_offset(
    bundle,
    canonical_tzid,
    local_millis,
    after,
  )
}

fn prefer_later_valid_local_offset(
  current: ZoneOffset,
  bundle: Bundle,
  canonical_tzid: String,
  local_millis: Int,
  candidate: ZoneOffset,
) -> ZoneOffset {
  let current_epoch = local_millis - current.raw_offset - current.dst_offset
  let candidate_epoch =
    local_millis - candidate.raw_offset - candidate.dst_offset
  let actual = get_offset(bundle, canonical_tzid, candidate_epoch)
  case
    candidate_epoch > current_epoch
    && actual.raw_offset == candidate.raw_offset
    && actual.dst_offset == candidate.dst_offset
  {
    True -> candidate
    False -> current
  }
}

fn get_offset_local_loop(
  bundle: Bundle,
  canonical_tzid: String,
  local_millis: Int,
  offset: ZoneOffset,
  i: Int,
) -> ZoneOffset {
  case i >= 3 {
    True -> offset
    False -> {
      let candidate = local_millis - offset.raw_offset - offset.dst_offset
      let next = get_offset(bundle, canonical_tzid, candidate)
      case
        next.raw_offset == offset.raw_offset
        && next.dst_offset == offset.dst_offset
      {
        True -> next
        False ->
          get_offset_local_loop(
            bundle,
            canonical_tzid,
            local_millis,
            next,
            i + 1,
          )
      }
    }
  }
}

fn dst_after_transition(
  type_offsets: List(Int),
  type_map_data: Option(BitArray),
  transition_index: Int,
) -> Bool {
  let #(_, dst) =
    offset_pair_for_transition_type(
      type_offsets,
      type_map_data,
      transition_index,
    )
  dst != 0
}

pub fn has_dst_transition_nearby(
  bundle: Bundle,
  canonical_tzid: String,
  epoch_millis: Int,
  range_ms: Int,
) -> Bool {
  let zone_info = bundle.zone_info_64
  case load_zone_data(zone_info, canonical_tzid) {
    None -> False
    Some(zone_data) ->
      case zone_data.final_rule {
        Some(final_rule) if epoch_millis >= final_rule.final_start_millis ->
          final_rule.use_daylight
        _ -> {
          case zone_data.transitions_count {
            0 -> False
            _ -> {
              let sec = math.floor_div(epoch_millis, 1000)
              let range_sec = math.floor_div(range_ms, 1000)
              let window =
                find_transition_window(
                  zone_data.transitions_index,
                  zone_data.transitions_count,
                  sec,
                )
              let before = case window.previous {
                Some(#(idx, transition)) ->
                  sec - transition < range_sec
                  && dst_after_transition(
                    zone_data.type_offsets,
                    zone_data.type_map_data,
                    idx - 1,
                  )
                None -> False
              }
              case before {
                True -> True
                False ->
                  case window.next {
                    Some(#(idx, transition)) ->
                      transition - sec < range_sec
                      && dst_after_transition(
                        zone_data.type_offsets,
                        zone_data.type_map_data,
                        idx,
                      )
                    None -> False
                  }
              }
            }
          }
        }
      }
  }
}
