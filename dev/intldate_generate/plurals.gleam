import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resource.{
  type NumRange, NumRange, PluralRule, Plurals,
}
import intldate_generate/icurb
import intldate_generate/save
import intldate_generate/shared
import simplifile

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/plurals.txt")

  let assert Ok(plurals) = parse_plurals(contents)
  save.save_plurals(plurals)
  plurals
}

fn parse_plurals(contents: String) {
  icurb.parse(contents, {
    use locales <- decode.field(
      "locales",
      decode.dict(decode.string, decode.string),
    )

    use locales_ordinals <- decode.field(
      "locales_ordinals",
      decode.dict(decode.string, decode.string),
    )

    use rules <- decode.field(
      "rules",
      decode.dict(decode.string, decode.dict(decode.string, decode.string)),
    )

    decode.success(Plurals(
      locales:,
      locales_ordinals:,
      rules: dict.map_values(rules, fn(_, rules) {
        build_rule_list(dict.to_list(rules))
      }),
    ))
  })
}

fn build_rule_list(
  entries: List(#(String, String)),
) -> List(resource.PluralRule) {
  case entries {
    [] -> []
    [#(keyword, raw), ..rest] -> {
      let rule_data = case string.split_once(raw, "@") {
        Ok(#(before, _)) -> string.trim(before)
        Error(_) -> raw
      }
      let rule = case rule_data == "" {
        True -> None
        False ->
          case parse_condition(rule_data) {
            Ok(cond) -> cond
            Error(_) -> None
          }
      }
      [PluralRule(keyword:, rule:), ..build_rule_list(rest)]
    }
  }
}

pub type Token {
  WordToken(value: String)
  NumToken(value: Int)
  DotDot
  NotEqual
  Equal
  Percent
  Comma
}

pub fn tokenize(rule_data: String) -> List(Token) {
  tokenize_loop(string.to_graphemes(rule_data), [])
}

fn tokenize_loop(chars: List(String), acc: List(Token)) -> List(Token) {
  case chars {
    [] -> list.reverse(acc)
    [c, ..rest] ->
      case is_space(c) {
        True -> tokenize_loop(rest, acc)
        False ->
          case is_alpha(c) {
            True -> {
              let #(word, rest2) = take_while_alpha([c, ..rest])
              tokenize_loop(rest2, [WordToken(word), ..acc])
            }
            False ->
              case shared.is_digit(c) {
                True -> {
                  let #(num, rest2) = take_while_digit([c, ..rest])
                  tokenize_loop(rest2, [NumToken(num), ..acc])
                }
                False ->
                  case c, rest {
                    ".", [".", ..rest2] -> tokenize_loop(rest2, [DotDot, ..acc])
                    "!", ["=", ..rest2] ->
                      tokenize_loop(rest2, [NotEqual, ..acc])
                    "=", _ -> tokenize_loop(rest, [Equal, ..acc])
                    "%", _ -> tokenize_loop(rest, [Percent, ..acc])
                    ",", _ -> tokenize_loop(rest, [Comma, ..acc])
                    _, _ -> tokenize_loop(rest, acc)
                  }
              }
          }
      }
  }
}

fn take_while_alpha(chars: List(String)) -> #(String, List(String)) {
  take_while_alpha_loop(chars, "")
}

fn take_while_alpha_loop(
  chars: List(String),
  acc: String,
) -> #(String, List(String)) {
  case chars {
    [c, ..rest] ->
      case is_alpha(c) {
        True -> take_while_alpha_loop(rest, acc <> c)
        False -> #(acc, chars)
      }
    [] -> #(acc, chars)
  }
}

fn take_while_digit(chars: List(String)) -> #(Int, List(String)) {
  take_while_digit_loop(chars, 0)
}

fn take_while_digit_loop(
  chars: List(String),
  acc: Int,
) -> #(Int, List(String)) {
  case chars {
    [c, ..rest] ->
      case shared.is_digit(c) {
        True -> take_while_digit_loop(rest, acc * 10 + shared.digit_value(c))
        False -> #(acc, chars)
      }
    [] -> #(acc, chars)
  }
}

fn is_alpha(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn is_space(c: String) -> Bool {
  c == " " || c == "\t" || c == "\n" || c == "\r"
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

pub type RuleParser {
  RuleParser(tokens: List(Token))
}

fn create_rule_parser(tokens: List(Token)) -> RuleParser {
  RuleParser(tokens:)
}

fn parser_peek(parser: RuleParser) -> option.Option(Token) {
  case parser.tokens {
    [token, ..] -> Some(token)
    [] -> None
  }
}

fn parser_next(parser: RuleParser) -> #(option.Option(Token), RuleParser) {
  case parser.tokens {
    [token, ..rest] -> #(Some(token), RuleParser(rest))
    [] -> #(None, parser)
  }
}

fn parser_peek_word(parser: RuleParser) -> option.Option(String) {
  case parser_peek(parser) {
    Some(WordToken(w)) -> Some(w)
    _ -> None
  }
}

fn parser_consume_word(
  parser: RuleParser,
  word: String,
) -> Result(RuleParser, String) {
  let #(token, next) = parser_next(parser)
  case token {
    Some(WordToken(w)) if w == word -> Ok(next)
    _ -> Error("plural rule parse error: expected '" <> word <> "'")
  }
}

fn parser_consume_num(
  parser: RuleParser,
) -> Result(#(Int, RuleParser), String) {
  let #(token, next) = parser_next(parser)
  case token {
    Some(NumToken(v)) -> Ok(#(v, next))
    _ -> Error("plural rule parse error: expected number")
  }
}

fn parse_range(parser: RuleParser) -> Result(#(NumRange, RuleParser), String) {
  case parser_consume_num(parser) {
    Error(e) -> Error(e)
    Ok(#(lo, p1)) ->
      case parser_peek(p1) {
        Some(DotDot) -> {
          let #(_, p2) = parser_next(p1)
          case parser_consume_num(p2) {
            Error(e) -> Error(e)
            Ok(#(hi, p3)) -> Ok(#(NumRange(lo, hi), p3))
          }
        }
        _ -> Ok(#(NumRange(lo, lo), p1))
      }
  }
}

fn parse_range_list(
  parser: RuleParser,
) -> Result(#(List(NumRange), RuleParser), String) {
  case parse_range(parser) {
    Error(e) -> Error(e)
    Ok(#(first, p)) -> parse_range_list_loop(p, [first])
  }
}

fn parse_range_list_loop(
  parser: RuleParser,
  acc: List(NumRange),
) -> Result(#(List(NumRange), RuleParser), String) {
  case parser_peek(parser) {
    Some(Comma) -> {
      let #(_, p2) = parser_next(parser)
      case parse_range(p2) {
        Error(e) -> Error(e)
        Ok(#(next, p3)) -> parse_range_list_loop(p3, list.append(acc, [next]))
      }
    }
    _ -> Ok(#(acc, parser))
  }
}

fn parse_constraint(
  parser: RuleParser,
) -> Result(#(resource.Constraint, RuleParser), String) {
  let #(operand_token, p0) = parser_next(parser)
  case operand_token {
    None -> Error("plural rule parse error: expected operand")
    Some(NumToken(_)) -> Error("plural rule parse error: expected operand")
    Some(token) ->
      case token {
        WordToken(operand) -> parse_constraint_mod(operand, p0)
        _ -> Error("plural rule parse error: expected operand")
      }
  }
}

fn parse_constraint_mod(
  operand: String,
  p: RuleParser,
) -> Result(#(resource.Constraint, RuleParser), String) {
  let is_mod_word = parser_peek_word(p) == Some("mod")
  let is_percent = parser_peek(p) == Some(Percent)
  case is_mod_word || is_percent {
    True -> {
      let #(_, p1) = parser_next(p)
      case parser_consume_num(p1) {
        Error(e) -> Error(e)
        Ok(#(mod, p2)) -> parse_constraint_negation(operand, Some(mod), p2)
      }
    }
    False -> parse_constraint_negation(operand, None, p)
  }
}

fn parse_constraint_negation(
  operand: String,
  mod: Option(Int),
  p: RuleParser,
) -> Result(#(resource.Constraint, RuleParser), String) {
  case parser_peek_word(p) == Some("not") {
    True -> {
      let assert Ok(p1) = parser_consume_word(p, "not")
      parse_constraint_relation(operand, mod, True, p1)
    }
    False -> parse_constraint_relation(operand, mod, False, p)
  }
}

fn parse_constraint_relation(
  operand: String,
  mod: Option(Int),
  negated: Bool,
  p: RuleParser,
) -> Result(#(resource.Constraint, RuleParser), String) {
  case parser_peek_word(p) {
    Some("is") -> {
      let assert Ok(p1) = parser_consume_word(p, "is")
      case parser_peek_word(p1) == Some("not") {
        True -> {
          let assert Ok(p2) = parser_consume_word(p1, "not")
          parse_constraint_is_value(operand, mod, True, p2)
        }
        False -> parse_constraint_is_value(operand, mod, negated, p1)
      }
    }
    Some("in") ->
      parse_constraint_range_relation(operand, mod, negated, True, p, "in")
    Some("within") ->
      parse_constraint_range_relation(operand, mod, negated, False, p, "within")
    _ ->
      case parser_peek(p) {
        Some(Equal) -> {
          let #(_, p1) = parser_next(p)
          case parse_range_list(p1) {
            Error(e) -> Error(e)
            Ok(#(ranges, p2)) ->
              Ok(#(resource.Constraint(operand, mod, negated, ranges, True), p2))
          }
        }
        Some(NotEqual) -> {
          let #(_, p1) = parser_next(p)
          case parse_range_list(p1) {
            Error(e) -> Error(e)
            Ok(#(ranges, p2)) ->
              Ok(#(
                resource.Constraint(operand, mod, !negated, ranges, True),
                p2,
              ))
          }
        }
        _ -> Error("plural rule parse error: expected relational operator")
      }
  }
}

fn parse_constraint_range_relation(
  operand: String,
  mod: Option(Int),
  negated: Bool,
  integer_only: Bool,
  p: RuleParser,
  word: String,
) -> Result(#(resource.Constraint, RuleParser), String) {
  let assert Ok(p1) = parser_consume_word(p, word)
  case parse_range_list(p1) {
    Error(e) -> Error(e)
    Ok(#(ranges, p2)) ->
      Ok(#(resource.Constraint(operand, mod, negated, ranges, integer_only), p2))
  }
}

fn parse_constraint_is_value(
  operand: String,
  mod: Option(Int),
  negated: Bool,
  p: RuleParser,
) -> Result(#(resource.Constraint, RuleParser), String) {
  case parser_consume_num(p) {
    Error(e) -> Error(e)
    Ok(#(v, p1)) ->
      Ok(#(
        resource.Constraint(operand, mod, negated, [NumRange(v, v)], False),
        p1,
      ))
  }
}

fn parse_and_condition(
  parser: RuleParser,
) -> Result(#(List(resource.Constraint), RuleParser), String) {
  case parse_constraint(parser) {
    Error(e) -> Error(e)
    Ok(#(first, p)) -> parse_and_condition_loop(p, [first])
  }
}

fn parse_and_condition_loop(
  parser: RuleParser,
  acc: List(resource.Constraint),
) -> Result(#(List(resource.Constraint), RuleParser), String) {
  case parser_peek_word(parser) == Some("and") {
    True -> {
      let assert Ok(p1) = parser_consume_word(parser, "and")
      case parse_constraint(p1) {
        Error(e) -> Error(e)
        Ok(#(next, p2)) ->
          parse_and_condition_loop(p2, list.append(acc, [next]))
      }
    }
    False -> Ok(#(acc, parser))
  }
}

pub fn parse_condition(
  rule_data: String,
) -> Result(option.Option(List(List(resource.Constraint))), String) {
  let tokens = tokenize(rule_data)
  case tokens {
    [] -> Ok(None)
    _ -> {
      let parser = create_rule_parser(tokens)
      case parse_and_condition(parser) {
        Error(e) -> Error(e)
        Ok(#(first, p)) ->
          case parse_condition_loop(p, [first]) {
            Error(e) -> Error(e)
            Ok(and_conditions) -> Ok(Some(and_conditions))
          }
      }
    }
  }
}

fn parse_condition_loop(
  parser: RuleParser,
  acc: List(List(resource.Constraint)),
) -> Result(List(List(resource.Constraint)), String) {
  case parser_peek_word(parser) == Some("or") {
    True -> {
      let assert Ok(p1) = parser_consume_word(parser, "or")
      case parse_and_condition(p1) {
        Error(e) -> Error(e)
        Ok(#(next, p2)) -> parse_condition_loop(p2, list.append(acc, [next]))
      }
    }
    False -> Ok(acc)
  }
}
