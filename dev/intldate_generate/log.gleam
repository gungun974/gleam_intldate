import gleam/int
import gleam/io
import gleam/list
import gleam/string
import pocket_watch

const prefix = "[intldate_generate] "

pub fn step(label: String, run body: fn() -> value) -> value {
  io.println(prefix <> label <> ": starting")
  pocket_watch.callback(
    fn(elapsed) { io.println(prefix <> label <> ": completed in " <> elapsed) },
    body,
  )
}

pub fn skipped(label: String, reason: String) -> Nil {
  io.println(prefix <> label <> ": skipped (" <> reason <> ")")
}

pub fn parse_failures(label: String, failures: List(String)) -> Nil {
  case failures {
    [] -> Nil
    _ -> {
      let count = list.length(failures)
      let noun = case count {
        1 -> "failure"
        _ -> "failures"
      }
      io.println(
        prefix
        <> label
        <> ": warning: "
        <> int.to_string(count)
        <> " "
        <> noun
        <> " ("
        <> string.join(list.reverse(failures), ", ")
        <> ")",
      )
    }
  }
}
