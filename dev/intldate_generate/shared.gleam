import gleam/list
import gleam/string
import simplifile

pub fn locales_dir(icu_path: String) -> String {
  icu_path <> "/icu4c/source/data/locales"
}

pub fn locale_names(icu_path: String) -> List(String) {
  let assert Ok(entries) = simplifile.read_directory(locales_dir(icu_path))
  list.filter_map(entries, fn(entry) {
    case string.ends_with(entry, ".txt") {
      True -> Ok(string.drop_end(entry, 4))
      False -> Error(Nil)
    }
  })
}

pub fn list_at(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], n if n > 0 -> list_at(rest, n - 1)
    _, _ -> Error(Nil)
  }
}

pub fn is_digit(character: String) -> Bool {
  let code = character_code(character)
  code >= 48 && code <= 57
}

pub fn digit_value(character: String) -> Int {
  character_code(character) - 48
}

fn character_code(character: String) -> Int {
  case string.to_utf_codepoints(character) {
    [codepoint] -> string.utf_codepoint_to_int(codepoint)
    _ -> -1
  }
}
