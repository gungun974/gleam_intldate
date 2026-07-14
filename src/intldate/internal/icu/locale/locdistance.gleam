import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/bytestrie.{
  type BytesTrie, type BytesTrieState,
}
import intldate/internal/icu/locale/lsr.{type LSR}

pub const distance_shift = 3

pub const distance_fraction_mask = 7

pub const index_shift = 13

pub const distance_mask = 0x3ff

pub const index_neg_1 = -1024

pub const ulocmatch_favor_language = 0

pub const ulocmatch_favor_script = 1

pub const ulocmatch_direction_with_one_way = 0

pub const ulocmatch_direction_only_two_way = 1

const end_of_subtag = 0x80

const distance_is_final = 0x100

const distance_is_final_or_skip_script = 0x180

const above_threshold = 100

pub type EncodedLSR {
  EncodedLSR(language: String, script: String, region: String)
}

pub type DistanceData {
  DistanceData(
    distance_trie_bytes: Option(BitArray),
    region_to_partitions: Option(BitArray),
    partitions: List(String),
    paradigms: List(EncodedLSR),
    paradigms_length: Int,
    distances: List(Int),
  )
}

pub type LikelySubtags {
  LikelySubtags(
    get_distance_data: fn() -> DistanceData,
    compare_likely: fn(LSR, LSR, Int) -> Int,
  )
}

pub type LocaleDistanceState {
  LocaleDistanceState(
    likely_subtags: LikelySubtags,
    trie: Option(BitArray),
    region_to_partitions_index: Option(BitArray),
    partition_arrays: Dict(Int, String),
    paradigm_lsrs: List(EncodedLSR),
    paradigm_lsrs_length: Int,
    default_language_distance: Int,
    default_script_distance: Int,
    default_region_distance: Int,
    min_region_distance: Int,
  )
}

pub type LocaleDistance {
  LocaleDistance(
    likely_subtags: LikelySubtags,
    default_script_distance: Int,
    default_demotion_per_desired_locale: Int,
    state: LocaleDistanceState,
  )
}

fn lsr_at(entries: Dict(Int, LSR), index: Int) -> Result(LSR, Nil) {
  dict.get(entries, index)
}

pub fn shift_distance(distance: Int) -> Int {
  int.bitwise_shift_left(distance, distance_shift)
}

pub fn get_distance_floor(index_and_distance: Int) -> Int {
  int.bitwise_shift_right(
    int.bitwise_and(index_and_distance, distance_mask),
    distance_shift,
  )
}

pub fn get_index(index_and_distance: Int) -> Int {
  int.bitwise_shift_right(index_and_distance, index_shift)
}

pub fn partitions_for_region(state: LocaleDistanceState, lsr: LSR) -> String {
  case state.region_to_partitions_index {
    None -> "."
    Some(index_buf) -> {
      let idx = region_to_partitions_byte(index_buf, lsr.region_index)
      case dict.get(state.partition_arrays, idx) {
        Ok("") | Error(_) -> "."
        Ok(arr) -> arr
      }
    }
  }
}

fn region_to_partitions_byte(buf: BitArray, index: Int) -> Int {
  case bit_array_slice_byte(buf, index) {
    Ok(byte) -> byte
    Error(_) -> 0
  }
}

fn bit_array_slice_byte(buf: BitArray, index: Int) -> Result(Int, Nil) {
  case buf {
    <<_skip:bytes-size(index), byte, _rest:bytes>> -> Ok(byte)
    _ -> Error(Nil)
  }
}

pub fn is_match(
  state: LocaleDistanceState,
  desired: LSR,
  supported: LSR,
  shifted_threshold: Int,
  favor_subtag: Int,
) -> Bool {
  get_best_index_and_distance(
    state,
    desired,
    dict.from_list([#(0, supported)]),
    1,
    shifted_threshold,
    favor_subtag,
    ulocmatch_direction_with_one_way,
  )
  >= 0
}

fn trie_or_empty(state: LocaleDistanceState) -> BytesTrie {
  case state.trie {
    None -> bytestrie.create_bytes_trie(<<>>, 0)
    Some(bytes) -> bytestrie.create_bytes_trie(bytes, 0)
  }
}

pub fn get_best_index_and_distance(
  state: LocaleDistanceState,
  desired: LSR,
  supported_lsrs: Dict(Int, LSR),
  supported_lsrs_length: Int,
  shifted_threshold: Int,
  favor_subtag: Int,
  direction: Int,
) -> Int {
  let iter = trie_or_empty(state)
  let #(des_lang_distance, iter) = trie_next(iter, desired.language, False)
  let des_lang_state = case
    des_lang_distance >= 0 && supported_lsrs_length > 1
  {
    True -> Some(bytestrie.save_state(iter))
    False -> None
  }
  loop_supported(
    state,
    desired,
    supported_lsrs,
    supported_lsrs_length,
    shifted_threshold,
    favor_subtag,
    direction,
    iter,
    des_lang_distance,
    des_lang_state,
    0,
    -1,
    -1,
  )
}

fn loop_supported(
  state: LocaleDistanceState,
  desired: LSR,
  supported_lsrs: Dict(Int, LSR),
  supported_lsrs_length: Int,
  shifted_threshold: Int,
  favor_subtag: Int,
  direction: Int,
  iter: BytesTrie,
  des_lang_distance: Int,
  des_lang_state: Option(BytesTrieState),
  sl_index: Int,
  best_index: Int,
  best_likely_info: Int,
) -> Int {
  case sl_index >= supported_lsrs_length {
    False -> {
      let assert Ok(supported) = lsr_at(supported_lsrs, sl_index)

      let #(distance0, iter) = case des_lang_distance >= 0 {
        True -> {
          let iter = case sl_index != 0 {
            True -> {
              let assert Some(saved) = des_lang_state
              bytestrie.restore_state(iter, saved)
            }
            False -> iter
          }
          trie_next(iter, supported.language, True)
        }
        False -> #(des_lang_distance, iter)
      }

      let #(distance, flags, star) = case distance0 >= 0 {
        True -> #(
          int.bitwise_and(
            distance0,
            int.bitwise_exclusive_or(-1, distance_is_final_or_skip_script),
          ),
          int.bitwise_and(distance0, distance_is_final_or_skip_script),
          False,
        )
        False -> #(
          case desired.language == supported.language {
            True -> 0
            False -> state.default_language_distance
          },
          0,
          True,
        )
      }

      let rounded_threshold =
        int.bitwise_shift_right(
          shifted_threshold + distance_fraction_mask,
          distance_shift,
        )
      let distance = case favor_subtag == ulocmatch_favor_script {
        True -> int.bitwise_shift_right(distance, 2)
        False -> distance
      }

      case distance > rounded_threshold {
        True ->
          loop_supported(
            state,
            desired,
            supported_lsrs,
            supported_lsrs_length,
            shifted_threshold,
            favor_subtag,
            direction,
            iter,
            des_lang_distance,
            des_lang_state,
            sl_index + 1,
            best_index,
            best_likely_info,
          )
        False -> {
          let #(script_distance, flags, iter) = case star || flags != 0 {
            True -> #(
              case desired.script == supported.script {
                True -> 0
                False -> state.default_script_distance
              },
              flags,
              iter,
            )
            False -> {
              let saved = bytestrie.save_state(iter)
              let #(raw, iter) =
                get_des_supp_script_distance(
                  iter,
                  saved,
                  desired.script,
                  supported.script,
                )
              let new_flags = int.bitwise_and(raw, distance_is_final)
              #(
                int.bitwise_and(
                  raw,
                  int.bitwise_exclusive_or(-1, distance_is_final),
                ),
                new_flags,
                iter,
              )
            }
          }

          let distance = distance + script_distance

          case distance > rounded_threshold {
            True ->
              loop_supported(
                state,
                desired,
                supported_lsrs,
                supported_lsrs_length,
                shifted_threshold,
                favor_subtag,
                direction,
                iter,
                des_lang_distance,
                des_lang_state,
                sl_index + 1,
                best_index,
                best_likely_info,
              )
            False -> {
              let #(distance, iter) = case desired.region == supported.region {
                True -> #(distance, iter)
                False ->
                  case star || int.bitwise_and(flags, distance_is_final) != 0 {
                    True -> #(distance + state.default_region_distance, iter)
                    False -> {
                      let remaining_threshold = rounded_threshold - distance
                      case state.min_region_distance > remaining_threshold {
                        True -> #(above_threshold + distance, iter)
                        False -> {
                          let saved = bytestrie.save_state(iter)
                          let #(region_distance, iter) =
                            get_region_partitions_distance(
                              iter,
                              saved,
                              partitions_for_region(state, desired),
                              partitions_for_region(state, supported),
                              remaining_threshold,
                            )
                          #(distance + region_distance, iter)
                        }
                      }
                    }
                  }
              }

              case distance > rounded_threshold {
                True ->
                  loop_supported(
                    state,
                    desired,
                    supported_lsrs,
                    supported_lsrs_length,
                    shifted_threshold,
                    favor_subtag,
                    direction,
                    iter,
                    des_lang_distance,
                    des_lang_state,
                    sl_index + 1,
                    best_index,
                    best_likely_info,
                  )
                False -> {
                  let shifted_distance = shift_distance(distance)
                  case shifted_distance == 0 {
                    True -> {
                      let shifted_distance =
                        int.bitwise_or(
                          shifted_distance,
                          int.bitwise_exclusive_or(
                            desired.flags,
                            supported.flags,
                          ),
                        )
                      case shifted_distance < shifted_threshold {
                        True -> {
                          let two_way_ok = case
                            direction != ulocmatch_direction_only_two_way
                          {
                            True -> True
                            False ->
                              is_match(
                                state,
                                supported,
                                desired,
                                shifted_threshold,
                                favor_subtag,
                              )
                          }
                          case two_way_ok {
                            True ->
                              case shifted_distance == 0 {
                                True ->
                                  int.bitwise_shift_left(sl_index, index_shift)
                                False ->
                                  loop_supported(
                                    state,
                                    desired,
                                    supported_lsrs,
                                    supported_lsrs_length,
                                    shifted_distance,
                                    favor_subtag,
                                    direction,
                                    iter,
                                    des_lang_distance,
                                    des_lang_state,
                                    sl_index + 1,
                                    sl_index,
                                    -1,
                                  )
                              }
                            False ->
                              loop_supported(
                                state,
                                desired,
                                supported_lsrs,
                                supported_lsrs_length,
                                shifted_threshold,
                                favor_subtag,
                                direction,
                                iter,
                                des_lang_distance,
                                des_lang_state,
                                sl_index + 1,
                                best_index,
                                best_likely_info,
                              )
                          }
                        }
                        False ->
                          loop_supported(
                            state,
                            desired,
                            supported_lsrs,
                            supported_lsrs_length,
                            shifted_threshold,
                            favor_subtag,
                            direction,
                            iter,
                            des_lang_distance,
                            des_lang_state,
                            sl_index + 1,
                            best_index,
                            best_likely_info,
                          )
                      }
                    }
                    False ->
                      case shifted_distance < shifted_threshold {
                        True -> {
                          let two_way_ok = case
                            direction != ulocmatch_direction_only_two_way
                          {
                            True -> True
                            False ->
                              is_match(
                                state,
                                supported,
                                desired,
                                shifted_threshold,
                                favor_subtag,
                              )
                          }
                          case two_way_ok {
                            True ->
                              loop_supported(
                                state,
                                desired,
                                supported_lsrs,
                                supported_lsrs_length,
                                shifted_distance,
                                favor_subtag,
                                direction,
                                iter,
                                des_lang_distance,
                                des_lang_state,
                                sl_index + 1,
                                sl_index,
                                -1,
                              )
                            False ->
                              loop_supported(
                                state,
                                desired,
                                supported_lsrs,
                                supported_lsrs_length,
                                shifted_threshold,
                                favor_subtag,
                                direction,
                                iter,
                                des_lang_distance,
                                des_lang_state,
                                sl_index + 1,
                                best_index,
                                best_likely_info,
                              )
                          }
                        }
                        False ->
                          case
                            shifted_distance == shifted_threshold
                            && best_index >= 0
                          {
                            True -> {
                              let two_way_ok = case
                                direction != ulocmatch_direction_only_two_way
                              {
                                True -> True
                                False ->
                                  is_match(
                                    state,
                                    supported,
                                    desired,
                                    shifted_threshold,
                                    favor_subtag,
                                  )
                              }
                              case two_way_ok {
                                True -> {
                                  let assert Ok(best_supported) =
                                    lsr_at(supported_lsrs, best_index)
                                  let new_likely_info =
                                    state.likely_subtags.compare_likely(
                                      supported,
                                      best_supported,
                                      best_likely_info,
                                    )
                                  case
                                    int.bitwise_and(new_likely_info, 1) != 0
                                  {
                                    True ->
                                      loop_supported(
                                        state,
                                        desired,
                                        supported_lsrs,
                                        supported_lsrs_length,
                                        shifted_threshold,
                                        favor_subtag,
                                        direction,
                                        iter,
                                        des_lang_distance,
                                        des_lang_state,
                                        sl_index + 1,
                                        sl_index,
                                        new_likely_info,
                                      )
                                    False ->
                                      loop_supported(
                                        state,
                                        desired,
                                        supported_lsrs,
                                        supported_lsrs_length,
                                        shifted_threshold,
                                        favor_subtag,
                                        direction,
                                        iter,
                                        des_lang_distance,
                                        des_lang_state,
                                        sl_index + 1,
                                        best_index,
                                        new_likely_info,
                                      )
                                  }
                                }
                                False ->
                                  loop_supported(
                                    state,
                                    desired,
                                    supported_lsrs,
                                    supported_lsrs_length,
                                    shifted_threshold,
                                    favor_subtag,
                                    direction,
                                    iter,
                                    des_lang_distance,
                                    des_lang_state,
                                    sl_index + 1,
                                    best_index,
                                    best_likely_info,
                                  )
                              }
                            }
                            False ->
                              loop_supported(
                                state,
                                desired,
                                supported_lsrs,
                                supported_lsrs_length,
                                shifted_threshold,
                                favor_subtag,
                                direction,
                                iter,
                                des_lang_distance,
                                des_lang_state,
                                sl_index + 1,
                                best_index,
                                best_likely_info,
                              )
                          }
                      }
                  }
                }
              }
            }
          }
        }
      }
    }
    True ->
      case best_index >= 0 {
        True ->
          int.bitwise_or(
            int.bitwise_shift_left(best_index, index_shift),
            shifted_threshold,
          )
        False -> int.bitwise_or(index_neg_1, shift_distance(above_threshold))
      }
  }
}

fn get_des_supp_script_distance(
  iter: BytesTrie,
  start_state: BytesTrieState,
  desired: String,
  supported: String,
) -> #(Int, BytesTrie) {
  let #(distance, iter) = trie_next(iter, desired, False)
  let #(distance, iter) = case distance >= 0 {
    True -> trie_next(iter, supported, True)
    False -> #(distance, iter)
  }
  case distance < 0 {
    True -> {
      let iter = bytestrie.restore_state(iter, start_state)
      let #(result, iter) = bytestrie.next(iter, 0x2a)
      let distance = case desired == supported {
        True -> 0
        False -> bytestrie.get_value(iter)
      }
      let distance = case result == bytestrie.FinalValue {
        True -> int.bitwise_or(distance, distance_is_final)
        False -> distance
      }
      #(distance, iter)
    }
    False -> #(distance, iter)
  }
}

fn first_char_code(s: String) -> Int {
  case string.to_utf_codepoints(s) {
    [cp, ..] -> string.utf_codepoint_to_int(cp)
    [] -> -1
  }
}

fn get_region_partitions_distance(
  iter: BytesTrie,
  start_state: BytesTrieState,
  desired_partitions: String,
  supported_partitions: String,
  threshold: Int,
) -> #(Int, BytesTrie) {
  let desired_parts = string.split(desired_partitions, "")
  let supported_parts = string.split(supported_partitions, "")
  case desired_parts, supported_parts {
    [], _ | _, [] -> #(0, iter)
    [d0, ..d_rest], [s0, ..s_rest] -> {
      let supp_length_gt1 = case s_rest {
        [] -> False
        _ -> True
      }
      case d_rest, supp_length_gt1 {
        [], False -> {
          let #(result, iter) =
            bytestrie.next(
              iter,
              int.bitwise_or(first_char_code(d0), end_of_subtag),
            )
          case bytestrie.has_next(result) {
            True -> {
              let #(result2, iter) =
                bytestrie.next(
                  iter,
                  int.bitwise_or(first_char_code(s0), end_of_subtag),
                )
              case
                result2 == bytestrie.IntermediateValue
                || result2 == bytestrie.FinalValue
              {
                True -> #(bytestrie.get_value(iter), iter)
                False -> get_fallback_region_distance(iter, start_state)
              }
            }
            False -> get_fallback_region_distance(iter, start_state)
          }
        }
        _, _ ->
          region_partitions_outer(
            iter,
            start_state,
            d0,
            d_rest,
            s0,
            s_rest,
            supp_length_gt1,
            threshold,
            0,
            False,
          )
      }
    }
  }
}

fn region_partitions_outer(
  iter: BytesTrie,
  start_state: BytesTrieState,
  desired: String,
  desired_rest: List(String),
  supported0: String,
  supported_rest0: List(String),
  supp_length_gt1: Bool,
  threshold: Int,
  region_distance: Int,
  star: Bool,
) -> #(Int, BytesTrie) {
  let #(result, iter) =
    bytestrie.next(
      iter,
      int.bitwise_or(first_char_code(desired), end_of_subtag),
    )
  case bytestrie.has_next(result) {
    True -> {
      let des_state = case supp_length_gt1 {
        True -> Some(bytestrie.save_state(iter))
        False -> None
      }
      let #(region_distance, star, iter) =
        region_partitions_inner(
          iter,
          des_state,
          supported0,
          supported_rest0,
          threshold,
          region_distance,
          star,
        )
      case region_distance > threshold {
        True -> #(region_distance, iter)
        False ->
          case desired_rest {
            [] -> #(region_distance, iter)
            [next_desired, ..next_rest] -> {
              let iter = bytestrie.restore_state(iter, start_state)
              region_partitions_outer(
                iter,
                start_state,
                next_desired,
                next_rest,
                supported0,
                supported_rest0,
                supp_length_gt1,
                threshold,
                region_distance,
                star,
              )
            }
          }
      }
    }
    False -> {
      case star {
        True ->
          case desired_rest {
            [] -> #(region_distance, iter)
            [next_desired, ..next_rest] -> {
              let iter = bytestrie.restore_state(iter, start_state)
              region_partitions_outer(
                iter,
                start_state,
                next_desired,
                next_rest,
                supported0,
                supported_rest0,
                supp_length_gt1,
                threshold,
                region_distance,
                star,
              )
            }
          }
        False -> {
          let #(d, iter) = get_fallback_region_distance(iter, start_state)
          case d > threshold {
            True -> #(d, iter)
            False -> {
              let region_distance = case region_distance < d {
                True -> d
                False -> region_distance
              }
              case desired_rest {
                [] -> #(region_distance, iter)
                [next_desired, ..next_rest] -> {
                  let iter = bytestrie.restore_state(iter, start_state)
                  region_partitions_outer(
                    iter,
                    start_state,
                    next_desired,
                    next_rest,
                    supported0,
                    supported_rest0,
                    supp_length_gt1,
                    threshold,
                    region_distance,
                    True,
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

fn region_partitions_inner(
  iter: BytesTrie,
  des_state: Option(BytesTrieState),
  supported: String,
  supported_rest: List(String),
  threshold: Int,
  region_distance: Int,
  star: Bool,
) -> #(Int, Bool, BytesTrie) {
  let #(result2, iter) =
    bytestrie.next(
      iter,
      int.bitwise_or(first_char_code(supported), end_of_subtag),
    )
  let #(d, star, iter) = case
    result2 == bytestrie.IntermediateValue || result2 == bytestrie.FinalValue
  {
    True -> #(bytestrie.get_value(iter), star, iter)
    False ->
      case star {
        True -> #(0, star, iter)
        False -> {
          let assert Some(saved) = des_state
          let #(fd, iter) = get_fallback_region_distance(iter, saved)
          #(fd, True, iter)
        }
      }
  }
  case d > threshold {
    True -> #(d, star, iter)
    False -> {
      let region_distance = case region_distance < d {
        True -> d
        False -> region_distance
      }
      case supported_rest {
        [] -> #(region_distance, star, iter)
        [next_supported, ..next_rest] -> {
          let assert Some(saved) = des_state
          let iter = bytestrie.restore_state(iter, saved)
          region_partitions_inner(
            iter,
            des_state,
            next_supported,
            next_rest,
            threshold,
            region_distance,
            star,
          )
        }
      }
    }
  }
}

fn get_fallback_region_distance(
  iter: BytesTrie,
  start_state: BytesTrieState,
) -> #(Int, BytesTrie) {
  let iter = bytestrie.restore_state(iter, start_state)
  let #(_result, iter) = bytestrie.next(iter, 0x2a)
  #(bytestrie.get_value(iter), iter)
}

fn trie_next(
  iter: BytesTrie,
  s: String,
  want_value: Bool,
) -> #(Int, BytesTrie) {
  case s == "" {
    True -> #(-1, iter)
    False -> trie_next_loop(iter, string_to_code_units(s), want_value)
  }
}

fn string_to_code_units(s: String) -> List(Int) {
  string.to_utf_codepoints(s) |> list.map(string.utf_codepoint_to_int)
}

fn trie_next_loop(
  iter: BytesTrie,
  units: List(Int),
  want_value: Bool,
) -> #(Int, BytesTrie) {
  case units {
    [] -> #(-1, iter)
    [c] -> {
      let #(result, iter) =
        bytestrie.next(iter, int.bitwise_or(c, end_of_subtag))
      case want_value {
        True ->
          case
            result == bytestrie.IntermediateValue
            || result == bytestrie.FinalValue
          {
            True -> {
              let value = bytestrie.get_value(iter)
              let value = case result == bytestrie.FinalValue {
                True -> int.bitwise_or(value, distance_is_final)
                False -> value
              }
              #(value, iter)
            }
            False -> #(-1, iter)
          }
        False ->
          case bytestrie.has_next(result) {
            True -> #(0, iter)
            False -> #(-1, iter)
          }
      }
    }
    [c, ..rest] -> {
      let #(result, iter) = bytestrie.next(iter, c)
      case bytestrie.has_next(result) {
        True -> trie_next_loop(iter, rest, want_value)
        False -> #(-1, iter)
      }
    }
  }
}

pub fn is_paradigm_lsr(state: LocaleDistanceState, target: LSR) -> Bool {
  is_paradigm_lsr_loop(state.paradigm_lsrs, state.paradigm_lsrs_length, target)
}

fn is_paradigm_lsr_loop(
  paradigms: List(EncodedLSR),
  remaining: Int,
  target: LSR,
) -> Bool {
  case paradigms {
    [] -> False
    [paradigm, ..rest] ->
      case remaining <= 0 {
        True -> False
        False ->
          case
            target.language == paradigm.language
            && target.script == paradigm.script
            && target.region == paradigm.region
          {
            True -> True
            False -> is_paradigm_lsr_loop(rest, remaining - 1, target)
          }
      }
  }
}

pub fn create_locale_distance_from_data(
  data: DistanceData,
  likely: LikelySubtags,
) -> LocaleDistance {
  let #(language_distance, script_distance, region_distance, min_distance) = case
    data.distances
  {
    [language, script, region, min, ..] -> #(language, script, region, min)
    [language, script, region] -> #(language, script, region, 0)
    [language, script] -> #(language, script, 0, 0)
    [language] -> #(language, 0, 0, 0)
    [] -> #(0, 0, 0, 0)
  }

  let state =
    LocaleDistanceState(
      likely_subtags: likely,
      trie: data.distance_trie_bytes,
      region_to_partitions_index: data.region_to_partitions,
      partition_arrays: data.partitions
        |> list.index_map(fn(value, i) { #(i, value) })
        |> dict.from_list,
      paradigm_lsrs: data.paradigms,
      paradigm_lsrs_length: data.paradigms_length,
      default_language_distance: language_distance,
      default_script_distance: script_distance,
      default_region_distance: region_distance,
      min_region_distance: min_distance,
    )

  let en = lsr.create_lsr("en", "Latn", "US", lsr.explicit_lsr)
  let en_gb = lsr.create_lsr("en", "Latn", "GB", lsr.explicit_lsr)
  let index_and_distance =
    get_best_index_and_distance(
      state,
      en,
      dict.from_list([#(0, en_gb)]),
      1,
      shift_distance(50),
      ulocmatch_favor_language,
      ulocmatch_direction_with_one_way,
    )
  let default_demotion_per_desired_locale =
    get_distance_floor(index_and_distance)

  LocaleDistance(
    likely_subtags: state.likely_subtags,
    default_script_distance: state.default_script_distance,
    default_demotion_per_desired_locale:,
    state:,
  )
}

pub fn create_locale_distance(likely: LikelySubtags) -> LocaleDistance {
  create_locale_distance_from_data(likely.get_distance_data(), likely)
}
