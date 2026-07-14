import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/uloc
import intldate/internal/math

pub const plural_keyword_other = "other"

pub const uplural_type_cardinal = "cardinal"

pub const uplural_type_ordinal = "ordinal"

pub type PluralOperands {
  PluralOperands(
    n: Option(Float),
    i: Option(Float),
    f: Option(Float),
    t: Option(Float),
    v: Option(Float),
    w: Option(Float),
    e: Option(Float),
    c: Option(Float),
  )
}

fn operand_value(operands: PluralOperands, name: String) -> Float {
  let value = case name {
    "n" -> operands.n
    "i" -> operands.i
    "f" -> operands.f
    "t" -> operands.t
    "v" -> operands.v
    "w" -> operands.w
    "e" -> operands.e
    "c" -> operands.c
    _ -> None
  }
  option.unwrap(value, 0.0)
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

pub type Condition =
  List(List(Constraint))

pub type PluralRule {
  PluralRule(keyword: String, rule: Option(Condition))
}

pub type PluralRules {
  PluralRules(
    bundle: Option(Bundle),
    locale_id: String,
    type_: String,
    rules: List(PluralRule),
  )
}

fn is_alpha(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn is_digit(c: String) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
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

fn digit_value(c: String) -> Int {
  char_code(c) - 48
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
              case is_digit(c) {
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
      case is_digit(c) {
        True -> take_while_digit_loop(rest, acc * 10 + digit_value(c))
        False -> #(acc, chars)
      }
    [] -> #(acc, chars)
  }
}

pub type RuleParser {
  RuleParser(tokens: List(Token))
}

fn create_rule_parser(tokens: List(Token)) -> RuleParser {
  RuleParser(tokens:)
}

fn parser_peek(parser: RuleParser) -> Option(Token) {
  case parser.tokens {
    [token, ..] -> Some(token)
    [] -> None
  }
}

fn parser_next(parser: RuleParser) -> #(Option(Token), RuleParser) {
  case parser.tokens {
    [token, ..rest] -> #(Some(token), RuleParser(rest))
    [] -> #(None, parser)
  }
}

fn parser_peek_word(parser: RuleParser) -> Option(String) {
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
) -> Result(#(Constraint, RuleParser), String) {
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
) -> Result(#(Constraint, RuleParser), String) {
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
) -> Result(#(Constraint, RuleParser), String) {
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
) -> Result(#(Constraint, RuleParser), String) {
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
              Ok(#(Constraint(operand, mod, negated, ranges, True), p2))
          }
        }
        Some(NotEqual) -> {
          let #(_, p1) = parser_next(p)
          case parse_range_list(p1) {
            Error(e) -> Error(e)
            Ok(#(ranges, p2)) ->
              Ok(#(Constraint(operand, mod, !negated, ranges, True), p2))
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
) -> Result(#(Constraint, RuleParser), String) {
  let assert Ok(p1) = parser_consume_word(p, word)
  case parse_range_list(p1) {
    Error(e) -> Error(e)
    Ok(#(ranges, p2)) ->
      Ok(#(Constraint(operand, mod, negated, ranges, integer_only), p2))
  }
}

fn parse_constraint_is_value(
  operand: String,
  mod: Option(Int),
  negated: Bool,
  p: RuleParser,
) -> Result(#(Constraint, RuleParser), String) {
  case parser_consume_num(p) {
    Error(e) -> Error(e)
    Ok(#(v, p1)) ->
      Ok(#(Constraint(operand, mod, negated, [NumRange(v, v)], False), p1))
  }
}

fn parse_and_condition(
  parser: RuleParser,
) -> Result(#(List(Constraint), RuleParser), String) {
  case parse_constraint(parser) {
    Error(e) -> Error(e)
    Ok(#(first, p)) -> parse_and_condition_loop(p, [first])
  }
}

fn parse_and_condition_loop(
  parser: RuleParser,
  acc: List(Constraint),
) -> Result(#(List(Constraint), RuleParser), String) {
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

pub fn parse_condition(rule_data: String) -> Result(Option(Condition), String) {
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
  acc: List(List(Constraint)),
) -> Result(List(List(Constraint)), String) {
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

fn in_any_range(value: Float, ranges: List(NumRange)) -> Bool {
  case ranges {
    [] -> False
    [r, ..rest] ->
      case value >=. int_to_float(r.lo) && value <=. int_to_float(r.hi) {
        True -> True
        False -> in_any_range(value, rest)
      }
  }
}

fn int_to_float(n: Int) -> Float {
  int.to_float(n)
}

fn eval_constraint(relation: Constraint, number: PluralOperands) -> Bool {
  let value = operand_value(number, relation.operand)
  case relation.integer_only && !is_integer_value(value) {
    True -> relation.negated
    False -> {
      let value = case relation.mod {
        Some(m) -> math.float_mod(value, int_to_float(m))
        None -> value
      }
      let in_range = in_any_range(value, relation.ranges)
      case relation.negated {
        True -> !in_range
        False -> in_range
      }
    }
  }
}

fn is_integer_value(value: Float) -> Bool {
  value == int_to_float(float.round(value))
}

fn eval_and_condition(
  and_condition: List(Constraint),
  number: PluralOperands,
) -> Bool {
  case and_condition {
    [] -> True
    [relation, ..rest] ->
      case eval_constraint(relation, number) {
        False -> False
        True -> eval_and_condition(rest, number)
      }
  }
}

pub fn eval_condition(condition: Condition, number: PluralOperands) -> Bool {
  case condition {
    [] -> False
    [and_condition, ..rest] ->
      case eval_and_condition(and_condition, number) {
        True -> True
        False -> eval_condition(rest, number)
      }
  }
}

fn resource_string_text(rd: resource.ResourceData, res: Int) -> String {
  case
    resource.resource_value_get_string(resource.create_resource_value(
      Some(rd),
      res,
    ))
  {
    Some(s) -> s.text
    None -> ""
  }
}

fn table_keys_and_res(
  table: resource.ResourceTableView,
) -> List(#(String, Int)) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      table_keys_and_res_loop(get_key, get_res, 0, table.length)
    _, _ -> []
  }
}

fn table_keys_and_res_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  i: Int,
  length: Int,
) -> List(#(String, Int)) {
  case i >= length {
    True -> []
    False -> [
      #(get_key(i), get_res(i)),
      ..table_keys_and_res_loop(get_key, get_res, i + 1, length)
    ]
  }
}

fn find_key(entries: List(#(String, Int)), key: String) -> Option(Int) {
  case entries {
    [] -> None
    [#(k, res), ..rest] ->
      case k == key {
        True -> Some(res)
        False -> find_key(rest, key)
      }
  }
}

fn find_rule_set_key(
  rd: resource.ResourceData,
  locales_table: resource.ResourceTableView,
  name: Option(String),
) -> Option(String) {
  case name {
    None -> None
    Some(n) ->
      case find_key(table_keys_and_res(locales_table), n) {
        Some(res) -> Some(resource_string_text(rd, res))
        None -> find_rule_set_key(rd, locales_table, resbund.chop_locale(n))
      }
  }
}

pub fn get_rule_from_resource(
  bundle: Bundle,
  locale_id: String,
  type_: String,
) -> List(PluralRule) {
  case resbund.open_direct(bundle, "plurals") {
    None -> []
    Some(rd) -> {
      let root = resource.get_table(rd, rd.root_res)
      let top_entries = table_keys_and_res(root)
      let locales_key = case type_ == uplural_type_ordinal {
        True -> "locales_ordinals"
        False -> "locales"
      }
      case find_key(top_entries, locales_key), find_key(top_entries, "rules") {
        Some(locales_res), Some(rules_res) -> {
          let locales_table = resource.get_table(rd, locales_res)
          let name = case uloc.get_base_name(Some(locale_id)) {
            "" -> Some(resbund.root_locale_name)
            n -> Some(n)
          }
          case find_rule_set_key(rd, locales_table, name) {
            None -> []
            Some(set_key) -> {
              let rules_table = resource.get_table(rd, rules_res)
              case find_key(table_keys_and_res(rules_table), set_key) {
                None -> []
                Some(set_res) -> {
                  let set_table = resource.get_table(rd, set_res)
                  build_rule_list(rd, table_keys_and_res(set_table))
                }
              }
            }
          }
        }
        _, _ -> []
      }
    }
  }
}

fn build_rule_list(
  rd: resource.ResourceData,
  entries: List(#(String, Int)),
) -> List(PluralRule) {
  case entries {
    [] -> []
    [#(keyword, res), ..rest] -> {
      let raw = resource_string_text(rd, res)
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
      [PluralRule(keyword:, rule:), ..build_rule_list(rd, rest)]
    }
  }
}

pub fn create_plural_rules(
  bundle: Bundle,
  locale_id: String,
  type_: String,
) -> PluralRules {
  PluralRules(
    bundle: Some(bundle),
    locale_id:,
    type_:,
    rules: get_rule_from_resource(bundle, locale_id, type_),
  )
}

pub fn plural_rules_select(pr: PluralRules, number: PluralOperands) -> String {
  select_from_rules(pr.rules, number)
}

fn select_from_rules(
  rules: List(PluralRule),
  number: PluralOperands,
) -> String {
  case rules {
    [] -> plural_keyword_other
    [rule, ..rest] ->
      case rule.keyword == plural_keyword_other {
        True -> select_from_rules(rest, number)
        False ->
          case rule.rule {
            Some(cond) ->
              case eval_condition(cond, number) {
                True -> rule.keyword
                False -> select_from_rules(rest, number)
              }
            None -> select_from_rules(rest, number)
          }
      }
  }
}
