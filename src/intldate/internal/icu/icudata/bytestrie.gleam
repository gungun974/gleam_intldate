import gleam/bit_array
import gleam/int
import gleam/option.{type Option, None, Some}

pub type TrieMatch {
  NoMatch
  NoValue
  IntermediateValue
  FinalValue
}

pub fn has_next(result: TrieMatch) -> Bool {
  result != NoMatch
}

const k_max_branch_linear_sub_node_length = 5

const k_min_linear_match = 0x10

const k_min_value_lead = 32

const k_value_is_final = 1

const k_min_one_byte_value_lead = 16

const k_min_two_byte_value_lead = 81

const k_min_three_byte_value_lead = 108

const k_four_byte_value_lead = 0x7e

const k_min_two_byte_delta_lead = 192

const k_min_three_byte_delta_lead = 0xf0

const k_four_byte_delta_lead = 0xfe

pub type BytesTrieState {
  BytesTrieState(pos: Option(Int), remaining_match_length: Int)
}

pub type BytesTrie {
  BytesTrie(
    bytes: BitArray,
    root: Int,
    pos: Option(Int),
    remaining_match_length: Int,
    owned_array: Option(BitArray),
  )
}

fn byte_at(bytes: BitArray, pos: Int) -> Int {
  case bit_array.slice(bytes, pos, 1) {
    Ok(<<b>>) -> b
    _ -> 0
  }
}

fn value_result(node: Int) -> TrieMatch {
  case int.bitwise_and(node, k_value_is_final) != 0 {
    True -> FinalValue
    False -> IntermediateValue
  }
}

fn read_value(bytes: BitArray, pos: Int, lead_byte: Int) -> Int {
  case lead_byte < k_min_two_byte_value_lead {
    True -> lead_byte - k_min_one_byte_value_lead
    False ->
      case lead_byte < k_min_three_byte_value_lead {
        True ->
          int.bitwise_shift_left(lead_byte - k_min_two_byte_value_lead, 8)
          |> int.bitwise_or(byte_at(bytes, pos))
        False ->
          case lead_byte < k_four_byte_value_lead {
            True ->
              int.bitwise_shift_left(
                lead_byte - k_min_three_byte_value_lead,
                16,
              )
              |> int.bitwise_or(int.bitwise_shift_left(byte_at(bytes, pos), 8))
              |> int.bitwise_or(byte_at(bytes, pos + 1))
            False ->
              case lead_byte == k_four_byte_value_lead {
                True ->
                  int.bitwise_shift_left(byte_at(bytes, pos), 16)
                  |> int.bitwise_or(int.bitwise_shift_left(
                    byte_at(bytes, pos + 1),
                    8,
                  ))
                  |> int.bitwise_or(byte_at(bytes, pos + 2))
                False ->
                  int.bitwise_shift_left(byte_at(bytes, pos), 24)
                  |> int.bitwise_or(int.bitwise_shift_left(
                    byte_at(bytes, pos + 1),
                    16,
                  ))
                  |> int.bitwise_or(int.bitwise_shift_left(
                    byte_at(bytes, pos + 2),
                    8,
                  ))
                  |> int.bitwise_or(byte_at(bytes, pos + 3))
              }
          }
      }
  }
}

fn skip_value_from(bytes: BitArray, pos: Int) -> Int {
  let lead_byte = byte_at(bytes, pos)
  skip_value(bytes, pos + 1, lead_byte)
}

fn skip_value(_bytes: BitArray, pos: Int, lead_byte: Int) -> Int {
  let two_byte_lead = int.bitwise_shift_left(k_min_two_byte_value_lead, 1)
  case lead_byte >= two_byte_lead {
    False -> pos
    True -> {
      let three_byte_lead =
        int.bitwise_shift_left(k_min_three_byte_value_lead, 1)
      case lead_byte < three_byte_lead {
        True -> pos + 1
        False -> {
          let four_byte_lead = int.bitwise_shift_left(k_four_byte_value_lead, 1)
          case lead_byte < four_byte_lead {
            True -> pos + 2
            False ->
              pos
              + 3
              + int.bitwise_and(int.bitwise_shift_right(lead_byte, 1), 1)
          }
        }
      }
    }
  }
}

fn jump_by_delta(bytes: BitArray, pos: Int) -> Int {
  let delta0 = byte_at(bytes, pos)
  case True {
    _ if delta0 < k_min_two_byte_delta_lead -> pos + 1 + delta0
    _ if delta0 < k_min_three_byte_delta_lead -> {
      let delta =
        int.bitwise_shift_left(delta0 - k_min_two_byte_delta_lead, 8)
        |> int.bitwise_or(byte_at(bytes, pos + 1))
      pos + 2 + delta
    }
    _ if delta0 < k_four_byte_delta_lead -> {
      let delta =
        int.bitwise_shift_left(delta0 - k_min_three_byte_delta_lead, 16)
        |> int.bitwise_or(int.bitwise_shift_left(byte_at(bytes, pos + 1), 8))
        |> int.bitwise_or(byte_at(bytes, pos + 2))
      pos + 3 + delta
    }
    _ if delta0 == k_four_byte_delta_lead -> {
      let delta =
        int.bitwise_shift_left(byte_at(bytes, pos + 1), 16)
        |> int.bitwise_or(int.bitwise_shift_left(byte_at(bytes, pos + 2), 8))
        |> int.bitwise_or(byte_at(bytes, pos + 3))
      pos + 4 + delta
    }
    _ -> {
      let delta =
        int.bitwise_shift_left(byte_at(bytes, pos + 1), 24)
        |> int.bitwise_or(int.bitwise_shift_left(byte_at(bytes, pos + 2), 16))
        |> int.bitwise_or(int.bitwise_shift_left(byte_at(bytes, pos + 3), 8))
        |> int.bitwise_or(byte_at(bytes, pos + 4))
      pos + 5 + delta
    }
  }
}

fn skip_delta(bytes: BitArray, pos: Int) -> Int {
  let delta = byte_at(bytes, pos)
  case delta >= k_min_two_byte_delta_lead {
    False -> pos + 1
    True ->
      case True {
        _ if delta < k_min_three_byte_delta_lead -> pos + 2
        _ if delta < k_four_byte_delta_lead -> pos + 3
        _ -> pos + 4 + int.bitwise_and(delta, 1)
      }
  }
}

pub fn create_bytes_trie(bytes: BitArray, offset: Int) -> BytesTrie {
  BytesTrie(
    bytes:,
    root: offset,
    pos: Some(offset),
    remaining_match_length: -1,
    owned_array: None,
  )
}

pub fn stop(trie: BytesTrie) -> BytesTrie {
  BytesTrie(..trie, pos: None)
}

pub fn save_state(trie: BytesTrie) -> BytesTrieState {
  BytesTrieState(
    pos: trie.pos,
    remaining_match_length: trie.remaining_match_length,
  )
}

pub fn restore_state(trie: BytesTrie, state: BytesTrieState) -> BytesTrie {
  BytesTrie(
    ..trie,
    pos: state.pos,
    remaining_match_length: state.remaining_match_length,
  )
}

fn branch_next(
  trie: BytesTrie,
  pos: Int,
  length: Int,
  in_byte: Int,
) -> #(TrieMatch, BytesTrie) {
  let #(pos, length) = case length == 0 {
    True -> #(pos + 1, byte_at(trie.bytes, pos))
    False -> #(pos, length)
  }
  branch_next_shrink(trie, pos, length + 1, in_byte)
}

fn branch_next_shrink(
  trie: BytesTrie,
  pos: Int,
  length: Int,
  in_byte: Int,
) -> #(TrieMatch, BytesTrie) {
  case length > k_max_branch_linear_sub_node_length {
    True -> {
      let probe = byte_at(trie.bytes, pos)
      case in_byte < probe {
        True ->
          branch_next_shrink(
            trie,
            jump_by_delta(trie.bytes, pos + 1),
            length / 2,
            in_byte,
          )
        False ->
          branch_next_shrink(
            trie,
            skip_delta(trie.bytes, pos + 1),
            length - length / 2,
            in_byte,
          )
      }
    }
    False -> branch_next_linear(trie, pos, length, in_byte)
  }
}

fn branch_next_linear(
  trie: BytesTrie,
  pos: Int,
  length: Int,
  in_byte: Int,
) -> #(TrieMatch, BytesTrie) {
  case byte_at(trie.bytes, pos) == in_byte {
    True -> {
      let pos = pos + 1
      let node = byte_at(trie.bytes, pos)
      case int.bitwise_and(node, k_value_is_final) != 0 {
        True -> #(FinalValue, BytesTrie(..trie, pos: Some(pos)))
        False -> {
          let pos = pos + 1
          let node = node / 2
          let #(delta, pos) = case node < k_min_two_byte_value_lead {
            True -> #(node - k_min_one_byte_value_lead, pos)
            False ->
              case node < k_min_three_byte_value_lead {
                True -> #(
                  int.bitwise_shift_left(node - k_min_two_byte_value_lead, 8)
                    |> int.bitwise_or(byte_at(trie.bytes, pos)),
                  pos + 1,
                )
                False ->
                  case node < k_four_byte_value_lead {
                    True -> #(
                      int.bitwise_shift_left(
                        node - k_min_three_byte_value_lead,
                        16,
                      )
                        |> int.bitwise_or(int.bitwise_shift_left(
                          byte_at(trie.bytes, pos),
                          8,
                        ))
                        |> int.bitwise_or(byte_at(trie.bytes, pos + 1)),
                      pos + 2,
                    )
                    False ->
                      case node == k_four_byte_value_lead {
                        True -> #(
                          int.bitwise_shift_left(byte_at(trie.bytes, pos), 16)
                            |> int.bitwise_or(int.bitwise_shift_left(
                              byte_at(trie.bytes, pos + 1),
                              8,
                            ))
                            |> int.bitwise_or(byte_at(trie.bytes, pos + 2)),
                          pos + 3,
                        )
                        False -> #(
                          int.bitwise_shift_left(byte_at(trie.bytes, pos), 24)
                            |> int.bitwise_or(int.bitwise_shift_left(
                              byte_at(trie.bytes, pos + 1),
                              16,
                            ))
                            |> int.bitwise_or(int.bitwise_shift_left(
                              byte_at(trie.bytes, pos + 2),
                              8,
                            ))
                            |> int.bitwise_or(byte_at(trie.bytes, pos + 3)),
                          pos + 4,
                        )
                      }
                  }
              }
          }
          let pos = pos + delta
          let node = byte_at(trie.bytes, pos)
          let result = case node >= k_min_value_lead {
            True -> value_result(node)
            False -> NoValue
          }
          #(result, BytesTrie(..trie, pos: Some(pos)))
        }
      }
    }
    False ->
      case length > 1 {
        True ->
          branch_next_linear(
            trie,
            skip_value_from(trie.bytes, pos + 1),
            length - 1,
            in_byte,
          )
        False ->
          case byte_at(trie.bytes, pos + 1) == in_byte {
            True -> {
              let pos = pos + 2
              let node = byte_at(trie.bytes, pos)
              let result = case node >= k_min_value_lead {
                True -> value_result(node)
                False -> NoValue
              }
              #(result, BytesTrie(..trie, pos: Some(pos)))
            }
            False -> #(NoMatch, stop(trie))
          }
      }
  }
}

fn next_impl(
  trie: BytesTrie,
  pos: Int,
  in_byte: Int,
) -> #(TrieMatch, BytesTrie) {
  let node = byte_at(trie.bytes, pos)
  let pos = pos + 1
  case node < k_min_linear_match {
    True -> branch_next(trie, pos, node, in_byte)
    False ->
      case node < k_min_value_lead {
        True -> {
          let length = node - k_min_linear_match
          case byte_at(trie.bytes, pos) == in_byte {
            True -> {
              let pos = pos + 1
              let length = length - 1
              let node = byte_at(trie.bytes, pos)
              let result = case length < 0 && node >= k_min_value_lead {
                True -> value_result(node)
                False -> NoValue
              }
              #(
                result,
                BytesTrie(
                  ..trie,
                  pos: Some(pos),
                  remaining_match_length: length,
                ),
              )
            }
            False -> #(NoMatch, stop(trie))
          }
        }
        False ->
          case int.bitwise_and(node, k_value_is_final) != 0 {
            True -> #(NoMatch, stop(trie))
            False -> next_impl(trie, skip_value(trie.bytes, pos, node), in_byte)
          }
      }
  }
}

pub fn next(trie: BytesTrie, in_byte: Int) -> #(TrieMatch, BytesTrie) {
  case trie.pos {
    None -> #(NoMatch, trie)
    Some(pos) -> {
      let in_byte = case in_byte < 0 {
        True -> in_byte + 0x100
        False -> in_byte
      }
      let length = trie.remaining_match_length
      case length >= 0 {
        True ->
          case byte_at(trie.bytes, pos) == in_byte {
            True -> {
              let p = pos + 1
              let length = length - 1
              let node = byte_at(trie.bytes, p)
              let result = case length < 0 && node >= k_min_value_lead {
                True -> value_result(node)
                False -> NoValue
              }
              #(
                result,
                BytesTrie(..trie, pos: Some(p), remaining_match_length: length),
              )
            }
            False -> #(NoMatch, stop(trie))
          }
        False -> next_impl(trie, pos, in_byte)
      }
    }
  }
}

pub fn get_value(trie: BytesTrie) -> Int {
  let pos = option.unwrap(trie.pos, -1)
  let lead_byte = byte_at(trie.bytes, pos)
  read_value(trie.bytes, pos + 1, lead_byte / 2)
}
