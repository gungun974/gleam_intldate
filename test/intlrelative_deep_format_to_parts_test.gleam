import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/time/duration
import intldate_test_data.{
  type RelativePartsTestCase, ExpectRelativeParts, ExpectRelativePartsError,
}
import intlrelative
import simplifile

type Failure {
  Failure(
    file: String,
    locale: String,
    config: intlrelative.RelativeTimeFormatConfig,
    expected: String,
    got: String,
  )
}

pub fn relative_parts_json_cases_test() {
  let assert Ok(content) = simplifile.read("test/relative_parts.json")
  let assert Ok(cases) =
    json.parse(
      content,
      decode.list(intldate_test_data.relative_parts_test_case_decoder()),
    )

  case list.filter_map(cases, run_parts_case) {
    [] -> Nil
    failures -> panic as report("intlrelative relative_parts.json", failures)
  }
}

fn run_parts_case(test_case: RelativePartsTestCase) -> Result(Failure, Nil) {
  let duration = duration_from_value(test_case.value, test_case.unit)

  case test_case.expected {
    ExpectRelativeParts(expected) -> {
      let got =
        intlrelative.format_to_parts(
          duration:,
          unit: test_case.unit,
          locale: Some(test_case.locale),
          config: test_case.config,
        )

      case got == expected {
        True -> Error(Nil)
        False ->
          Ok(Failure(
            file: "relative_parts.json",
            locale: test_case.locale,
            config: test_case.config,
            expected: string.inspect(expected),
            got: string.inspect(got),
          ))
      }
    }

    ExpectRelativePartsError(_) ->
      case
        intlrelative.try_format_to_parts(
          duration:,
          unit: test_case.unit,
          locale: Some(test_case.locale),
          config: test_case.config,
        )
      {
        Error(_) -> Error(Nil)
        Ok(got) ->
          Ok(Failure(
            file: "relative_parts.json",
            locale: test_case.locale,
            config: test_case.config,
            expected: "Error",
            got: string.inspect(got),
          ))
      }
  }
}

fn duration_from_value(
  value: Int,
  unit: intlrelative.Unit,
) -> duration.Duration {
  duration.seconds(value * unit_seconds(unit))
}

fn unit_seconds(unit: intlrelative.Unit) -> Int {
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

fn report(name: String, failures: List(Failure)) -> String {
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
    bold(yellow("\n" <> name))
      <> " "
      <> int.to_string(total)
      <> " failing case(s)\n",
    shown,
    footer,
  ])
}

fn format_failure(failure: Failure, index: Int) -> String {
  string.concat([
    bold(yellow("\ncase")) <> " " <> grey("#" <> int.to_string(index)) <> "\n",
    label("  file") <> failure.file <> "\n",
    label("locale") <> failure.locale <> "\n",
    label("config") <> string.inspect(failure.config) <> "\n",
    label("   exp") <> failure.expected <> "\n",
    label("   got") <> failure.got <> "\n",
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
