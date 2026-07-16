import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string

pub fn parse(
  from input: String,
  using decoder: decode.Decoder(t),
) -> Result(t, List(decode.DecodeError)) {
  case tokenize(input) {
    Error(message) -> Error([parser_error(message)])

    Ok(tokens) ->
      case parse_bundle(tokens) {
        Error(message) -> Error([parser_error(message)])

        Ok(#(value, [])) -> decode.run(value, decoder)

        Ok(#(_value, rest)) ->
          Error([
            decode.DecodeError(
              expected: "end of ICU resource bundle",
              found: inspect_tokens(rest),
              path: [],
            ),
          ])
      }
  }
}

// =============================================================================
// Tokens
// =============================================================================

type Token {
  Text(String)
  OpenBrace
  CloseBrace
  OpenParen
  CloseParen
  Colon
  Comma
}

// =============================================================================
// Lexer
//
// Important:
//
// ICU's parser ultimately works with TOK_STRING for both:
//
//   foo
//   "foo"
//
// Adjacent quoted strings are one logical string:
//
//   "hello "
//   "world"
//
// => "hello world"
//
// We therefore merge adjacent quoted strings here.
// =============================================================================

fn tokenize(input: String) -> Result(List(Token), String) {
  input
  |> to_codepoint_strings
  |> lex([])
}

// `string.to_graphemes` segments by extended grapheme cluster, which fuses a
// combining mark onto whatever precedes it — including a `"` that opens or
// closes a quoted string (common right after the opening quote in CLDR
// exemplar-character data for scripts with standalone combining vowel
// signs, e.g. Devanagari). That silently merges structural characters into
// content and breaks the lexer. Splitting by codepoint instead keeps every
// character, combining or not, as its own token.
fn to_codepoint_strings(input: String) -> List(String) {
  input
  |> string.to_utf_codepoints
  |> list.map(fn(cp) { string.from_utf_codepoints([cp]) })
}

fn lex(input: List(String), acc: List(Token)) -> Result(List(Token), String) {
  let input = skip_ignored(input)

  case input {
    [] -> Ok(list.reverse(acc))

    ["{", ..rest] -> lex(rest, [OpenBrace, ..acc])

    ["}", ..rest] -> lex(rest, [CloseBrace, ..acc])

    ["(", ..rest] -> lex(rest, [OpenParen, ..acc])

    [")", ..rest] -> lex(rest, [CloseParen, ..acc])

    [":", ..rest] -> lex(rest, [Colon, ..acc])

    [",", ..rest] -> lex(rest, [Comma, ..acc])

    ["\"", ..rest] ->
      case read_quoted(rest, []) {
        Error(message) -> Error(message)

        Ok(#(value, rest)) ->
          case read_adjacent_quoted_strings(rest, [value]) {
            Error(message) -> Error(message)

            Ok(#(values, rest)) -> {
              let value =
                values
                |> list.reverse
                |> string.join("")

              lex(rest, [Text(value), ..acc])
            }
          }
      }

    _ -> {
      let #(value, rest) = read_unquoted(input, [])

      case value {
        "" -> Error("unexpected character near " <> inspect_graphemes(input))

        _ -> lex(rest, [Text(value), ..acc])
      }
    }
  }
}

// =============================================================================
// Ignored input
// =============================================================================

fn skip_ignored(input: List(String)) -> List(String) {
  case input {
    [] -> []

    // UTF-8 BOM / U+FEFF
    ["﻿", ..rest] -> skip_ignored(rest)

    [g, ..rest] if g == " " || g == "\t" || g == "\n" || g == "\r" ->
      skip_ignored(rest)

    ["/", "/", ..rest] ->
      rest
      |> drop_line_comment
      |> skip_ignored

    ["/", "*", ..rest] ->
      case drop_block_comment(rest) {
        Ok(rest) -> skip_ignored(rest)

        Error(_) -> ["/", "*"]
      }

    _ -> input
  }
}

fn drop_line_comment(input: List(String)) -> List(String) {
  case input {
    [] -> []

    ["\n", ..rest] -> rest

    [_, ..rest] -> drop_line_comment(rest)
  }
}

fn drop_block_comment(input: List(String)) -> Result(List(String), String) {
  case input {
    [] -> Error("unterminated block comment")

    ["*", "/", ..rest] -> Ok(rest)

    [_, ..rest] -> drop_block_comment(rest)
  }
}

// =============================================================================
// Quoted strings
// =============================================================================

fn read_quoted(
  input: List(String),
  acc: List(String),
) -> Result(#(String, List(String)), String) {
  case input {
    [] -> Error("unterminated quoted string")

    ["\"", ..rest] ->
      Ok(#(
        acc
          |> list.reverse
          |> string.join(""),
        rest,
      ))

    // Common ICU/C/Java escapes.
    ["\\", "\"", ..rest] -> read_quoted(rest, ["\"", ..acc])

    ["\\", "\\", ..rest] -> read_quoted(rest, ["\\", ..acc])

    ["\\", "n", ..rest] -> read_quoted(rest, ["\n", ..acc])

    ["\\", "r", ..rest] -> read_quoted(rest, ["\r", ..acc])

    ["\\", "t", ..rest] -> read_quoted(rest, ["\t", ..acc])

    ["\\", "b", ..rest] -> read_quoted(rest, ["\u{0008}", ..acc])

    ["\\", "f", ..rest] -> read_quoted(rest, ["\f", ..acc])

    // Keep other escapes intact for now.
    //
    // This preserves:
    //
    //   \xFF
    //   \u1234
    //   \U0001F600
    //
    // A fully semantic ICU implementation should decode these according to
    // u_unescape().
    ["\\", escaped, ..rest] -> read_quoted(rest, [escaped, "\\", ..acc])

    [g, ..rest] -> read_quoted(rest, [g, ..acc])
  }
}

fn read_adjacent_quoted_strings(
  input: List(String),
  acc: List(String),
) -> Result(#(List(String), List(String)), String) {
  let input = skip_ignored(input)

  case input {
    ["\"", ..rest] ->
      case read_quoted(rest, []) {
        Error(message) -> Error(message)

        Ok(#(value, rest)) -> read_adjacent_quoted_strings(rest, [value, ..acc])
      }

    _ -> Ok(#(acc, input))
  }
}

// =============================================================================
// Unquoted strings
// =============================================================================

fn read_unquoted(
  input: List(String),
  acc: List(String),
) -> #(String, List(String)) {
  case input {
    [] -> #(
      acc
        |> list.reverse
        |> string.join(""),
      [],
    )

    // Whitespace ends an unquoted token.
    [g, ..] if g == " " || g == "\t" || g == "\n" || g == "\r" ->
      finish_text(acc, input)

    // Structural characters end the token.
    [g, ..]
      if g == "{"
      || g == "}"
      || g == "("
      || g == ")"
      || g == ":"
      || g == ","
      || g == "\""
    -> finish_text(acc, input)

    // Comments also end the current token.
    ["/", "/", ..] -> finish_text(acc, input)

    ["/", "*", ..] -> finish_text(acc, input)

    [g, ..rest] -> read_unquoted(rest, [g, ..acc])
  }
}

fn finish_text(
  acc: List(String),
  input: List(String),
) -> #(String, List(String)) {
  #(
    acc
      |> list.reverse
      |> string.join(""),
    input,
  )
}

// =============================================================================
// Bundle
// =============================================================================

fn parse_bundle(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [Text(bundle_name), ..rest] -> parse_bundle_after_name(bundle_name, rest)

    _ -> Error("expected ICU bundle name, found " <> inspect_tokens(tokens))
  }
}

fn parse_bundle_after_name(
  bundle_name: String,
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    // supplementalData {
    [OpenBrace, ..rest] -> parse_table_body(rest)

    // supplementalData:...
    [Colon, ..rest] -> parse_root_type(bundle_name, rest)

    _ ->
      Error(
        "expected `{` or `:` after bundle name `"
        <> bundle_name
        <> "`, found "
        <> inspect_tokens(tokens),
      )
  }
}

fn parse_root_type(
  bundle_name: String,
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [Text("table"), ..rest] -> parse_root_table_options(bundle_name, rest)

    [Text(resource_type), ..] ->
      Error(
        "ICU bundle root `"
        <> bundle_name
        <> "` must be a table, found `:"
        <> resource_type
        <> "`",
      )

    _ ->
      Error(
        "expected `table` after `"
        <> bundle_name
        <> ":`, found "
        <> inspect_tokens(tokens),
      )
  }
}

fn parse_root_table_options(
  bundle_name: String,
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    // supplementalData:table {
    [OpenBrace, ..rest] -> parse_table_body(rest)

    // supplementalData:table(nofallback) {
    [OpenParen, ..rest] -> parse_root_table_option(bundle_name, rest)

    _ ->
      Error(
        "expected `{` or `(nofallback)` after `"
        <> bundle_name
        <> ":table`, found "
        <> inspect_tokens(tokens),
      )
  }
}

fn parse_root_table_option(
  bundle_name: String,
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [Text("nofallback"), CloseParen, OpenBrace, ..rest] ->
      parse_table_body(rest)

    [Text(option), ..] ->
      Error(
        "unsupported root table option `"
        <> option
        <> "` in bundle `"
        <> bundle_name
        <> "`",
      )

    _ ->
      Error(
        "expected `nofallback) {` in bundle `"
        <> bundle_name
        <> "`, found "
        <> inspect_tokens(tokens),
      )
  }
}

// =============================================================================
// Generic resource
// =============================================================================

fn parse_named_resource(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    // Explicit type:
    //
    // key:type { ... }
    [Colon, Text(resource_type), ..rest] ->
      parse_explicit_type(resource_type, rest)

    // Untyped:
    //
    // key { ... }
    [OpenBrace, ..rest] -> parse_inferred_resource(rest)

    _ -> Error("expected `:` or `{` after resource name")
  }
}

// =============================================================================
// Explicit resource types
// =============================================================================

fn parse_explicit_type(
  resource_type: String,
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case resource_type {
    "table" -> parse_explicit_table(tokens)

    "array" -> parse_explicit_array(tokens)

    "string" -> parse_explicit_string(tokens)

    "int" -> parse_integer(tokens)

    "integer" -> parse_integer(tokens)

    "intvector" -> parse_intvector(tokens)

    "bin" -> parse_binary(tokens)

    "binary" -> parse_binary(tokens)

    "alias" -> parse_alias(tokens)

    "import" -> parse_import(tokens)

    _ -> Error("unknown ICU resource type `" <> resource_type <> "`")
  }
}

// =============================================================================
// Type inference
//
// Mirrors the important logic from ICU genrb:
//
//   { {       => array
//   { :       => array
//   { }       => array
//   { string, => array
//   { string{ => table
//   { string: => table
//   { string} => string
// =============================================================================

fn parse_inferred_resource(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    // { }
    //
    // genrb infers an empty array for a non-root untyped resource.
    [CloseBrace, ..rest] -> Ok(#(dynamic.list([]), rest))

    // { {
    //
    // Anonymous resource inside an array.
    [OpenBrace, ..] -> parse_array_body(tokens)

    // { :type
    //
    // Anonymous explicitly typed resource inside an array.
    [Colon, ..] -> parse_array_body(tokens)

    // { string ,
    [Text(_), Comma, ..] -> parse_array_body(tokens)

    // { string {
    [Text(_), OpenBrace, ..] -> parse_table_body(tokens)

    // { string :
    [Text(_), Colon, ..] -> parse_table_body(tokens)

    // { string }
    [Text(value), CloseBrace, ..rest] -> Ok(#(dynamic.string(value), rest))

    [Text(_), ..] ->
      Error(
        "unexpected token after string; " <> "expected `,`, `{`, `:`, or `}`",
      )

    _ -> Error("unexpected token after `{`")
  }
}

// =============================================================================
// Tables
// =============================================================================

fn parse_explicit_table(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, ..rest] -> parse_table_body(rest)

    _ -> Error("expected `{` after `:table`")
  }
}

fn parse_table_body(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  parse_table_entries(tokens, [])
}

fn parse_table_entries(
  tokens: List(Token),
  acc: List(#(dynamic.Dynamic, dynamic.Dynamic)),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [] -> Error("unterminated table")

    [CloseBrace, ..rest] -> Ok(#(dynamic.properties(list.reverse(acc)), rest))

    [Text(key), ..rest] ->
      case parse_named_resource(rest) {
        Error(message) ->
          Error("while parsing resource `" <> key <> "`: " <> message)

        Ok(#(value, rest)) ->
          parse_table_entries(rest, [#(dynamic.string(key), value), ..acc])
      }

    _ -> Error("expected a resource name or `}` in table")
  }
}

// =============================================================================
// Arrays
//
// genrb permits an optional comma after each array member.
// Therefore both are accepted:
//
//   { "a", "b", "c" }
//
// and:
//
//   { "a" "b" "c" }
//
// Note: Adjacent *quoted literal segments* have already been merged by the
// lexer before we get here.
// =============================================================================

fn parse_explicit_array(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, ..rest] -> parse_array_body(rest)

    _ -> Error("expected `{` after `:array`")
  }
}

fn parse_array_body(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  parse_array_entries(tokens, [])
}

fn parse_array_entries(
  tokens: List(Token),
  acc: List(dynamic.Dynamic),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [] -> Error("unterminated array")

    [CloseBrace, ..rest] -> Ok(#(dynamic.list(list.reverse(acc)), rest))

    // ICU permits commas between resources.
    [Comma, ..rest] -> parse_array_entries(rest, acc)

    _ ->
      case parse_anonymous_resource(tokens) {
        Error(message) -> Error("invalid array element: " <> message)

        Ok(#(value, rest)) -> {
          let rest = case rest {
            [Comma, ..rest] -> rest
            _ -> rest
          }

          parse_array_entries(rest, [value, ..acc])
        }
      }
  }
}

fn parse_anonymous_resource(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    // A bare TOK_STRING in an array is directly a string resource.
    [Text(value), ..rest] -> Ok(#(dynamic.string(value), rest))

    // :type { ... }
    [Colon, Text(resource_type), ..rest] ->
      parse_explicit_type(resource_type, rest)

    // { ... }
    [OpenBrace, ..rest] -> parse_inferred_resource(rest)

    _ -> Error("expected string, anonymous resource, or typed resource")
  }
}

// =============================================================================
// Strings
// =============================================================================

fn parse_explicit_string(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, Text(value), CloseBrace, ..rest] ->
      Ok(#(dynamic.string(value), rest))

    [OpenBrace, CloseBrace, ..rest] -> Ok(#(dynamic.string(""), rest))

    _ -> Error("expected `{ string }` after `:string`")
  }
}

// =============================================================================
// Alias
//
// Dynamic has no ICU alias type, so the alias path is represented as a
// string carrying a sentinel prefix that cannot occur in real ICU resource
// bundle data (a NUL byte, which ICU string values never contain). This
// lets `resolvable` distinguish a genuine alias from a literal string
// without changing how plain strings/lists/dicts decode elsewhere.
// =============================================================================

const alias_marker = "\u{0}icurb-alias\u{0}"

fn parse_alias(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, Text(value), CloseBrace, ..rest] ->
      Ok(#(dynamic.string(alias_marker <> value), rest))

    [OpenBrace, CloseBrace, ..rest] -> Ok(#(dynamic.string(alias_marker), rest))

    _ -> Error("expected `{ alias-path }` after `:alias`")
  }
}

// =============================================================================
// Resolvable values
//
// Any resource (string, array, table, ...) can turn out to be an `:alias`
// pointing elsewhere instead of the literal value a caller expects. Wrap a
// decoder with `resolvable` to get either the decoded value or the alias
// target path, instead of a hard decode failure or (worse) silently
// decoding the alias path string as if it were real data.
// =============================================================================

pub type Resolved(t) {
  Value(t)
  AliasTo(String)
}

pub fn resolvable(inner: decode.Decoder(t)) -> decode.Decoder(Resolved(t)) {
  // The alias check must run before `inner`: when `inner` is itself a
  // string decoder, it would otherwise happily decode an alias marker's
  // sentinel-prefixed string as if it were the literal value.
  decode.one_of(
    {
      use raw <- decode.then(decode.string)
      case string.starts_with(raw, alias_marker) {
        True ->
          decode.success(
            AliasTo(string.drop_start(raw, string.length(alias_marker))),
          )
        False -> decode.failure(AliasTo(""), "not an alias")
      }
    },
    [decode.map(inner, Value)],
  )
}

// =============================================================================
// Import
//
// genrb's :import reads an external file and stores its bytes.
// This parser has only a String input and no filesystem callback, so it
// represents the imported filename as a string.
//
// This makes the SOURCE SYNTAX parseable, but does not perform genrb's I/O.
// =============================================================================

fn parse_import(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, Text(filename), CloseBrace, ..rest] ->
      Ok(#(dynamic.string(filename), rest))

    _ -> Error("expected `{ filename }` after `:import`")
  }
}

// =============================================================================
// Integer
// =============================================================================

fn parse_integer(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, Text(value), CloseBrace, ..rest] ->
      case parse_icu_int(value) {
        Ok(value) -> Ok(#(dynamic.int(value), rest))

        Error(message) -> Error(message)
      }

    _ -> Error("expected `{ integer }` after integer type")
  }
}

fn parse_icu_int(value: String) -> Result(Int, String) {
  // Decimal form.
  //
  // Hexadecimal parsing can be added here depending on the Gleam stdlib
  // version used by the project.

  case int.parse(value) {
    Ok(value) -> Ok(value)

    Error(_) -> Error("invalid ICU integer `" <> value <> "`")
  }
}

// =============================================================================
// Integer vector
// =============================================================================

fn parse_intvector(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, ..rest] -> parse_intvector_entries(rest, [])

    _ -> Error("expected `{` after `:intvector`")
  }
}

fn parse_intvector_entries(
  tokens: List(Token),
  acc: List(dynamic.Dynamic),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [] -> Error("unterminated intvector")

    [CloseBrace, ..rest] -> Ok(#(dynamic.list(list.reverse(acc)), rest))

    [Comma, ..rest] -> parse_intvector_entries(rest, acc)

    [Text(value), ..rest] ->
      case parse_icu_int(value) {
        Error(message) -> Error(message)

        Ok(value) -> {
          let rest = case rest {
            [Comma, ..rest] -> rest
            _ -> rest
          }

          parse_intvector_entries(rest, [dynamic.int(value), ..acc])
        }
      }

    _ -> Error("expected integer, `,`, or `}` in intvector")
  }
}

// =============================================================================
// Binary
//
// ICU binary source values are hexadecimal.
//
// Dynamic has no byte-array primitive guaranteed by this API, so the source
// hexadecimal value is represented as a String.
// =============================================================================

fn parse_binary(
  tokens: List(Token),
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [OpenBrace, CloseBrace, ..rest] -> Ok(#(dynamic.bit_array(<<>>), rest))

    // ICU also emits binary data as several bare hexadecimal chunks, one per
    // line, with no separator between them:
    //
    //   trie:bin{
    //   001a6df03b5474d99477cec377a88878
    //   aee579b8407a00186fc19d75957a647a
    //   }
    [OpenBrace, ..rest] -> parse_binary_chunks(rest, "")

    _ -> Error("expected `{ hexadecimal-data }` after binary type")
  }
}

fn parse_binary_chunks(
  tokens: List(Token),
  acc: String,
) -> Result(#(dynamic.Dynamic, List(Token)), String) {
  case tokens {
    [Text(value), ..rest] -> parse_binary_chunks(rest, acc <> value)

    [CloseBrace, ..rest] ->
      case parse_hex_bit_array(acc) {
        Ok(value) -> Ok(#(dynamic.bit_array(value), rest))

        Error(message) -> Error(message)
      }

    _ -> Error("expected `{ hexadecimal-data }` after binary type")
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn parser_error(message: String) -> decode.DecodeError {
  decode.DecodeError(
    expected: "valid ICU resource bundle",
    found: message,
    path: [],
  )
}

fn inspect_tokens(tokens: List(Token)) -> String {
  case tokens {
    [] -> "end of input"

    [Text(value), ..] -> value

    [OpenBrace, ..] -> "{"

    [CloseBrace, ..] -> "}"

    [OpenParen, ..] -> "("

    [CloseParen, ..] -> ")"

    [Colon, ..] -> ":"

    [Comma, ..] -> ","
  }
}

fn inspect_graphemes(input: List(String)) -> String {
  input
  |> list.take(16)
  |> string.join("")
}

fn parse_hex_bit_array(value: String) -> Result(BitArray, String) {
  let graphemes = string.to_graphemes(value)

  case graphemes {
    [] -> Ok(<<>>)

    _ -> parse_hex_bytes(graphemes, <<>>)
  }
}

fn parse_hex_bytes(
  input: List(String),
  acc: BitArray,
) -> Result(BitArray, String) {
  case input {
    [] -> Ok(acc)

    [high, low, ..rest] ->
      case parse_hex_digit(high), parse_hex_digit(low) {
        Ok(high), Ok(low) -> {
          let byte = high * 16 + low

          parse_hex_bytes(rest, <<acc:bits, byte:8>>)
        }

        _, _ -> Error("invalid hexadecimal binary data")
      }

    [_] ->
      Error("binary hexadecimal data must contain an even number of digits")
  }
}

fn parse_hex_digit(value: String) -> Result(Int, Nil) {
  case value {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)

    "a" | "A" -> Ok(10)
    "b" | "B" -> Ok(11)
    "c" | "C" -> Ok(12)
    "d" | "D" -> Ok(13)
    "e" | "E" -> Ok(14)
    "f" | "F" -> Ok(15)

    _ -> Error(Nil)
  }
}
