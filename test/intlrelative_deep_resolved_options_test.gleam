import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import intldate_test_data.{
  type RelativeResolvedOptionsTestCase, ExpectRelativeOptions,
  ExpectRelativeOptionsError,
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

pub fn relative_resolved_options_json_cases_test() {
  let assert Ok(content) =
    simplifile.read("test/relative_resolved_options.json")
  let assert Ok(cases) =
    json.parse(
      content,
      decode.list(
        intldate_test_data.relative_resolved_options_test_case_decoder(),
      ),
    )

  case list.filter_map(cases, run_options_case) {
    [] -> Nil
    failures ->
      panic as report("intlrelative relative_resolved_options.json", failures)
  }
}

fn run_options_case(
  test_case: RelativeResolvedOptionsTestCase,
) -> Result(Failure, Nil) {
  case test_case.expected {
    ExpectRelativeOptions(expected) -> {
      let got =
        intlrelative.resolved_options(
          locale: Some(test_case.locale),
          config: test_case.config,
        )

      case got == Ok(expected) {
        True -> Error(Nil)
        False ->
          Ok(Failure(
            file: "relative_resolved_options.json",
            locale: test_case.locale,
            config: test_case.config,
            expected: string.inspect(Ok(expected)),
            got: string.inspect(got),
          ))
      }
    }

    ExpectRelativeOptionsError(_) ->
      case
        intlrelative.resolved_options(
          locale: Some(test_case.locale),
          config: test_case.config,
        )
      {
        Error(_) -> Error(Nil)
        Ok(got) ->
          Ok(Failure(
            file: "relative_resolved_options.json",
            locale: test_case.locale,
            config: test_case.config,
            expected: "Error",
            got: string.inspect(got),
          ))
      }
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
