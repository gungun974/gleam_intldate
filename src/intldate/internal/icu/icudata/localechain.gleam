import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/resource

pub const root_locale_name = "root"

const max_alias_depth = 8

fn chop_locale(name: String) -> Option(String) {
  case string.contains(name, "_") {
    False ->
      case name == root_locale_name {
        True -> None
        False -> Some(root_locale_name)
      }
    True -> {
      let parts = string.split(name, "_")
      case list.reverse(parts) {
        [_last, ..rest] -> Some(string.join(list.reverse(rest), "_"))
        [] -> None
      }
    }
  }
}

fn resolve_alias(
  aliases: dict.Dict(String, String),
  name: String,
  depth: Int,
) -> String {
  case depth >= max_alias_depth {
    True -> name
    False ->
      case dict.get(aliases, name) {
        Ok(target) -> resolve_alias(aliases, target, depth + 1)
        Error(_) -> name
      }
  }
}

fn parent_of(parents: resource.LocaleParents, name: String) -> Option(String) {
  let resolved = resolve_alias(parents.aliases, name, 0)
  case dict.get(parents.overrides, resolved) {
    Ok(parent) -> Some(parent)
    Error(_) -> chop_locale(resolved)
  }
}

pub fn parent_locale_name(
  parents: resource.LocaleParents,
  name: String,
) -> Option(String) {
  parent_of(parents, name)
}

pub fn locale_chain(
  parents: resource.LocaleParents,
  name: String,
) -> List(String) {
  locale_chain_loop(parents, Some(name), [])
}

fn locale_chain_loop(
  parents: resource.LocaleParents,
  name: Option(String),
  acc: List(String),
) -> List(String) {
  case name {
    None -> list.reverse(acc)
    Some(n) -> {
      let resolved = resolve_alias(parents.aliases, n, 0)
      locale_chain_loop(parents, parent_of(parents, resolved), [resolved, ..acc])
    }
  }
}
