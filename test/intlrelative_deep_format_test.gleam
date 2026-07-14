import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/duration
import intldate_test_data.{
  type Expected, type RelativeFormatTestCase, ExpectError, ExpectResult,
}
import intlrelative.{type Unit}
import simplifile

type Failure {
  Failure(
    value: Int,
    unit: Unit,
    locale: String,
    config: intlrelative.RelativeTimeFormatConfig,
    expected: Expected,
    got: String,
  )
}

const timeout = 500

pub type Timeout(a) {
  Timeout(time: Int, function: fn() -> a)
}

pub fn relative_json_cases_test_() {
  use <- Timeout(timeout)
  let assert Ok(content) = simplifile.read("test/relative.json")

  let assert Ok(cases) =
    json.parse(
      content,
      decode.list(intldate_test_data.relative_format_test_case_decoder()),
    )

  let failures = cases |> list.filter_map(run_case)

  case failures {
    [] -> Nil
    failures -> panic as report(failures)
  }
}

@target(javascript)
pub fn relative_json_cases_test() {
  relative_json_cases_test_().function()
}

fn run_case(test_case: RelativeFormatTestCase) -> Result(Failure, Nil) {
  let duration = duration_from_value(test_case.value, test_case.unit)

  case test_case.expected {
    ExpectResult(expected) -> {
      let got =
        intlrelative.format(
          duration:,
          unit: test_case.unit,
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
            value: test_case.value,
            unit: test_case.unit,
            locale: test_case.locale,
            config: test_case.config,
            expected: test_case.expected,
            got:,
          ))
        }
      }
    }

    ExpectError(_) ->
      case
        intlrelative.try_format(
          duration:,
          unit: test_case.unit,
          locale: Some(test_case.locale),
          config: test_case.config,
        )
      {
        Error(_) -> Error(Nil)
        Ok(got) ->
          Ok(Failure(
            value: test_case.value,
            unit: test_case.unit,
            locale: test_case.locale,
            config: test_case.config,
            expected: test_case.expected,
            got:,
          ))
      }
  }
}

fn duration_from_value(value: Int, unit: Unit) -> duration.Duration {
  duration.seconds(value * unit_seconds(unit))
}

fn unit_seconds(unit: Unit) -> Int {
  case unit {
    intlrelative.Second -> 1
    intlrelative.Minute -> 60
    intlrelative.Hour -> 3600
    intlrelative.Day -> 86_400
    intlrelative.Week -> 604_800
    intlrelative.Month -> 2_629_746
    intlrelative.Quarter -> 7_889_238
    intlrelative.Year -> 31_556_952
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
    bold(yellow("\nintlrelative relative.json"))
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
    label(" value") <> int.to_string(failure.value) <> "\n",
    label("  unit") <> string.inspect(failure.unit) <> "\n",
    label("locale") <> failure.locale <> "\n",
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
