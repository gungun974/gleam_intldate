import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/timestamp
import intldate
import intldate_test_data.{
  type Expected, type FormatTestCase, ExpectError, ExpectResult,
}
import simplifile

type Failure {
  Failure(
    date: String,
    locale: String,
    time_zone: String,
    config: intldate.DateTimeFormatConfig,
    expected: Expected,
    got: String,
  )
}

const timeout = 500

pub type Timeout(a) {
  Timeout(time: Int, function: fn() -> a)
}

pub fn format_json_cases_test_() {
  use <- Timeout(timeout)
  let assert Ok(content) = simplifile.read("test/format.json")

  let assert Ok(cases) =
    json.parse(
      content,
      decode.list(intldate_test_data.format_test_case_decoder()),
    )

  let failures = cases |> list.filter_map(run_case)

  case failures {
    [] -> Nil
    failures -> panic as report(failures)
  }
}

@target(javascript)
pub fn format_json_cases_test() {
  format_json_cases_test_().function()
}

fn run_case(test_case: FormatTestCase) -> Result(Failure, Nil) {
  case timestamp.parse_rfc3339(test_case.date) {
    Error(_) ->
      Ok(Failure(
        date: test_case.date,
        locale: test_case.locale,
        time_zone: test_case.time_zone,
        config: test_case.config,
        expected: test_case.expected,
        got: "invalid date",
      ))

    Ok(date) ->
      case test_case.expected {
        ExpectResult(expected) -> {
          let got =
            intldate.format(
              date:,
              time_zone: Some(test_case.time_zone),
              locale: Some(test_case.locale),
              config: test_case.config,
            )

          case got == expected {
            True -> {
              // io.print_error(".")
              Error(Nil)
            }

            False -> {
              // io.print_error("x")
              Ok(Failure(
                date: test_case.date,
                locale: test_case.locale,
                time_zone: test_case.time_zone,
                config: test_case.config,
                expected: test_case.expected,
                got:,
              ))
            }
          }
        }

        ExpectError(_) ->
          case
            intldate.try_format(
              date:,
              time_zone: Some(test_case.time_zone),
              locale: Some(test_case.locale),
              config: test_case.config,
            )
          {
            Error(_) -> Error(Nil)
            Ok(got) ->
              Ok(Failure(
                date: test_case.date,
                locale: test_case.locale,
                time_zone: test_case.time_zone,
                config: test_case.config,
                expected: test_case.expected,
                got:,
              ))
          }
      }
  }
}

const preview = 20

fn report(failures: List(Failure)) -> String {
  let total = list.length(failures)

  let shown =
    failures
    |> list.take(preview)
    |> list.index_map(format_failure)
    |> string.concat

  let remaining = total - preview

  let footer = case remaining > 0 {
    True -> grey("\n... and " <> int.to_string(remaining) <> " more\n")
    False -> ""
  }

  string.concat([
    bold(yellow("\nintldate format.json"))
      <> " "
      <> int.to_string(total)
      <> " failing case(s)\n",
    shown,
    footer,
  ])
}

fn format_failure(failure: Failure, index: Int) -> String {
  let expected = case failure.expected {
    ExpectResult(value) -> "Ok " <> string.inspect(value)
    ExpectError(_) -> "Error"
  }

  string.concat([
    bold(yellow("\ncase")) <> " " <> grey("#" <> int.to_string(index)) <> "\n",
    label("  date") <> failure.date <> "\n",
    label("locale") <> failure.locale <> "\n",
    label("  zone") <> failure.time_zone <> "\n",
    label("config") <> string.inspect(failure.config) <> "\n",
    label("   exp") <> expected <> "\n",
    label("   got") <> string.inspect(failure.got) <> "\n",
  ])
}

fn label(name: String) -> String {
  cyan(name) <> ": "
}

fn bold(text: String) -> String {
  "\u{001b}[1m" <> text <> "\u{001b}[22m"
}

fn cyan(text: String) -> String {
  "\u{001b}[36m" <> text <> "\u{001b}[39m"
}

fn yellow(text: String) -> String {
  "\u{001b}[33m" <> text <> "\u{001b}[39m"
}

fn grey(text: String) -> String {
  "\u{001b}[90m" <> text <> "\u{001b}[39m"
}
