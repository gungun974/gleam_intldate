import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import intldate/internal/icu/calendar/gregoimp
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/zonemeta.{type Bundle}
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

fn find_key(
  _rd: resource.ResourceData,
  table: resource.ResourceTableView,
  key: String,
) -> Option(Int) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      find_key_loop(get_key, get_res, table.length, key, 0)
    _, _ -> None
  }
}

fn find_key_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  length: Int,
  key: String,
  i: Int,
) -> Option(Int) {
  case i >= length {
    True -> None
    False ->
      case get_key(i) == key {
        True -> Some(get_res(i))
        False -> find_key_loop(get_key, get_res, length, key, i + 1)
      }
  }
}

fn combine64(hi: Int, lo: Int) -> Int {
  hi * 4_294_967_296 + lo
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

fn int_vector_or_empty(
  rd: resource.ResourceData,
  res: Option(Int),
) -> List(Int) {
  case res {
    None -> []
    Some(r) ->
      case
        resource.resource_value_get_int_vector(resource.create_resource_value(
          Some(rd),
          r,
        ))
      {
        Some(vec) -> vec
        None -> []
      }
  }
}

fn combine_pairs(arr: List(Int)) -> List(Int) {
  case arr {
    [hi, lo, ..rest] -> [combine64(hi, lo), ..combine_pairs(rest)]
    _ -> []
  }
}

fn load_final_rule(
  rd: resource.ResourceData,
  table: resource.ResourceTableView,
  rules_table: Option(resource.ResourceTableView),
) -> Option(FinalRule) {
  case find_key(rd, table, "finalRule") {
    None -> None
    Some(final_rule_res) -> {
      let final_rule_name = case
        resource.resource_value_get_string(resource.create_resource_value(
          Some(rd),
          final_rule_res,
        ))
      {
        Some(s) -> s.text
        None -> ""
      }
      let final_raw = case find_key(rd, table, "finalRaw") {
        None -> 0
        Some(r) ->
          resource.resource_value_get_int(resource.create_resource_value(
            Some(rd),
            r,
          ))
      }
      let final_year = case find_key(rd, table, "finalYear") {
        None -> 0
        Some(r) ->
          resource.resource_value_get_int(resource.create_resource_value(
            Some(rd),
            r,
          ))
      }
      case rules_table {
        None -> None
        Some(rules) ->
          case find_key(rd, rules, final_rule_name) {
            None -> None
            Some(rule_res) ->
              case
                resource.resource_value_get_int_vector(
                  resource.create_resource_value(Some(rd), rule_res),
                )
              {
                None -> None
                Some(rule_data) ->
                  build_final_rule(final_raw, final_year, rule_data)
              }
          }
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
  bundle: Bundle,
  canonical_tzid: String,
) -> Option(ZoneData) {
  let key = "zonedata\n" <> bundle.data_path <> "\n" <> canonical_tzid
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      case uncached_load_zone_data(bundle, canonical_tzid) {
        Some(data) -> cache.put(key, Some(data))
        None -> None
      }
  }
}

fn uncached_load_zone_data(
  bundle: Bundle,
  canonical_tzid: String,
) -> Option(ZoneData) {
  case zonemeta.get_zone_resource_table(bundle, canonical_tzid) {
    None -> None
    Some(found) -> {
      let rd = found.rd
      let table = found.table

      let trans_pre32 =
        int_vector_or_empty(rd, find_key(rd, table, "transPre32"))
      let trans = int_vector_or_empty(rd, find_key(rd, table, "trans"))
      let trans_post32 =
        int_vector_or_empty(rd, find_key(rd, table, "transPost32"))

      let transitions =
        list_append3(
          combine_pairs(trans_pre32),
          trans,
          combine_pairs(trans_post32),
        )
      let transitions_count = list.length(transitions)
      let transitions_index =
        list.index_fold(transitions, dict.new(), fn(acc, transition, index) {
          dict.insert(acc, index, transition)
        })

      let type_offsets = case find_key(rd, table, "typeOffsets") {
        None -> []
        Some(r) ->
          case
            resource.resource_value_get_int_vector(
              resource.create_resource_value(Some(rd), r),
            )
          {
            Some(vec) -> vec
            None -> []
          }
      }

      let type_map_data = case find_key(rd, table, "typeMap") {
        None -> None
        Some(r) ->
          resource.resource_value_get_binary(resource.create_resource_value(
            Some(rd),
            r,
          ))
      }

      let final_rule = load_final_rule(rd, table, found.rules_table)

      Some(ZoneData(
        transitions_count:,
        transitions_index:,
        type_offsets:,
        type_map_data:,
        final_rule:,
      ))
    }
  }
}

fn list_append3(a: List(Int), b: List(Int), c: List(Int)) -> List(Int) {
  case a {
    [] ->
      case b {
        [] -> c
        [head, ..tail] -> [head, ..list_append3([], tail, c)]
      }
    [head, ..tail] -> [head, ..list_append3(tail, b, c)]
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
  case load_zone_data(bundle, canonical_tzid) {
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
  get_offset_local_loop(bundle, canonical_tzid, local_millis, offset, 0)
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
  case load_zone_data(bundle, canonical_tzid) {
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
