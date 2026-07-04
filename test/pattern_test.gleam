import intldate/internal/pattern.{
  AmPm, CalendarYear, DayOfMonth, Field, Hour12, Hour24, Minute, Month,
  NodeField, NodeText, Second,
}

pub fn parse_empty_string_test() {
  assert pattern.parse("") == []
}

pub fn parse_text_only_test() {
  assert pattern.parse("/") == [NodeText("/")]
}

pub fn parse_single_pattern_char_test() {
  assert pattern.parse("y") == [NodeField(Field(CalendarYear, 1))]
}

pub fn parse_repeated_pattern_chars_test() {
  assert pattern.parse("yyyy") == [NodeField(Field(CalendarYear, 4))]
}

pub fn parse_pattern_then_text_test() {
  assert pattern.parse("y/")
    == [NodeField(Field(CalendarYear, 1)), NodeText("/")]
}

pub fn parse_text_then_pattern_test() {
  assert pattern.parse("/y")
    == [NodeText("/"), NodeField(Field(CalendarYear, 1))]
}

pub fn parse_pattern_text_pattern_test() {
  assert pattern.parse("y/M")
    == [
      NodeField(Field(CalendarYear, 1)),
      NodeText("/"),
      NodeField(Field(Month, 1)),
    ]
}

pub fn parse_date_format_test() {
  assert pattern.parse("yyyy-MM-dd")
    == [
      NodeField(Field(CalendarYear, 4)),
      NodeText("-"),
      NodeField(Field(Month, 2)),
      NodeText("-"),
      NodeField(Field(DayOfMonth, 2)),
    ]
}

pub fn parse_adjacent_different_patterns_test() {
  assert pattern.parse("HHmm")
    == [
      NodeField(Field(Hour24, 2)),
      NodeField(Field(Minute, 2)),
    ]
}

pub fn parse_time_format_test() {
  assert pattern.parse("HH:mm:ss")
    == [
      NodeField(Field(Hour24, 2)),
      NodeText(":"),
      NodeField(Field(Minute, 2)),
      NodeText(":"),
      NodeField(Field(Second, 2)),
    ]
}

pub fn parse_12h_with_am_pm_test() {
  assert pattern.parse("hh:mm a")
    == [
      NodeField(Field(Hour12, 2)),
      NodeText(":"),
      NodeField(Field(Minute, 2)),
      NodeText(" "),
      NodeField(Field(AmPm, 1)),
    ]
}

pub fn parse_quoted_text_becomes_text_node_test() {
  assert pattern.parse("'hello'") == [NodeText("hello")]
}

pub fn parse_quoted_pattern_chars_are_literal_test() {
  assert pattern.parse("'yyyy-MM-dd'") == [NodeText("yyyy-MM-dd")]
}

pub fn parse_pattern_quoted_text_pattern_test() {
  assert pattern.parse("HH'h'mm")
    == [
      NodeField(Field(Hour24, 2)),
      NodeText("h"),
      NodeField(Field(Minute, 2)),
    ]
}

pub fn parse_multiple_text_segments_test() {
  assert pattern.parse("--/--") == [NodeText("--/--")]
}

pub fn parse_width_one_pattern_test() {
  assert pattern.parse("M/d/y")
    == [
      NodeField(Field(Month, 1)),
      NodeText("/"),
      NodeField(Field(DayOfMonth, 1)),
      NodeText("/"),
      NodeField(Field(CalendarYear, 1)),
    ]
}
