import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/etf_source
import intldate/internal/icu/icudata/resource.{type ResourceData}
import intldate/internal/icu/icudata/uresimp

pub const root_locale_name = "root"

const max_alias_level = 8

pub type LocaleChainEntry {
  LocaleChainEntry(name: String, res_data: Option(ResourceData))
}

pub type ResolvedResource {
  ResolvedResource(res_data: ResourceData, res: Int)
}

pub type AliasTarget {
  AliasTarget(target_chain: List(LocaleChainEntry), key_path: Option(String))
}

pub type Bundle {
  Bundle(data_path: String)
}

pub fn create_bundle(data_path: String) -> Bundle {
  Bundle(data_path:)
}

fn load_item_resource_data(
  bundle: Bundle,
  item_name_value: String,
) -> Option(ResourceData) {
  let key = bundle.data_path <> "\n" <> item_name_value
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      cache.put(
        key,
        case etf_source.load_bundle(bundle.data_path, item_name_value) {
          Ok(value) -> Some(resource.from_dynamic(value))
          Error(_) -> None
        },
      )
  }
}

pub fn resolve_bundle_name(bundle: Bundle, item_name_value: String) -> String {
  resolve_bundle_name_loop(bundle, item_name_value, 0)
}

fn resolve_bundle_name_loop(
  bundle: Bundle,
  item_name_value: String,
  depth: Int,
) -> String {
  case depth >= max_alias_level {
    True -> item_name_value
    False ->
      case load_item_resource_data(bundle, item_name_value) {
        None -> item_name_value
        Some(rd) -> {
          let alias_res = resource.get_resource(rd, "%%ALIAS")
          case alias_res != uresimp.res_bogus {
            False -> item_name_value
            True -> {
              let value = resource.create_resource_value(Some(rd), alias_res)
              case resource.resource_value_get_string(value) {
                Some(alias) if alias.text != "" ->
                  resolve_bundle_name_loop(bundle, alias.text, depth + 1)
                _ -> item_name_value
              }
            }
          }
        }
      }
  }
}

pub fn load_resource_data(
  bundle: Bundle,
  item_name_value: String,
) -> Option(ResourceData) {
  let resolved_name = resolve_bundle_name(bundle, item_name_value)
  load_item_resource_data(bundle, resolved_name)
}

pub fn open_direct(bundle: Bundle, name: String) -> Option(ResourceData) {
  let locale_name = case name {
    "" -> root_locale_name
    _ -> name
  }
  load_resource_data(bundle, locale_name)
}

pub fn open_direct_or_panic(bundle: Bundle, name: String) -> ResourceData {
  case open_direct(bundle, name) {
    Some(rd) -> rd
    None -> panic as "resource bundle item not found"
  }
}

fn read_res_index_table_names(bundle: Bundle, key: String) -> List(String) {
  case open_direct(bundle, "res_index") {
    None -> []
    Some(rd) -> {
      let table = resource.get_table(rd, rd.root_res)
      case find_table_entry_by_key(table, key) {
        None -> []
        Some(target_res) -> {
          let target_table = resource.get_table(rd, target_res)
          collect_table_keys(target_table, 0)
        }
      }
    }
  }
}

fn collect_table_keys(
  table: resource.ResourceTableView,
  i: Int,
) -> List(String) {
  case i >= table.length {
    True -> []
    False ->
      case table.get_key {
        None -> []
        Some(get_key) -> [get_key(i), ..collect_table_keys(table, i + 1)]
      }
  }
}

fn find_table_entry_by_key(
  table: resource.ResourceTableView,
  key: String,
) -> Option(Int) {
  case table.get_key, table.get_res {
    Some(get_key), Some(get_res) ->
      find_table_entry_by_key_loop(get_key, get_res, table.length, key, 0)
    _, _ -> None
  }
}

fn find_table_entry_by_key_loop(
  get_key: fn(Int) -> String,
  get_res: fn(Int) -> Int,
  length: Int,
  key: String,
  i: Int,
) -> Option(Int) {
  case i >= length {
    True -> None
    False ->
      case get_key(i) == key {
        True -> Some(get_res(i))
        False ->
          find_table_entry_by_key_loop(get_key, get_res, length, key, i + 1)
      }
  }
}

pub fn get_available_locales_by_type(
  bundle: Bundle,
  type_: Int,
) -> List(String) {
  case type_ {
    1 -> read_res_index_table_names(bundle, "AliasLocales")
    2 ->
      list.append(
        get_available_locales_by_type(bundle, 0),
        get_available_locales_by_type(bundle, 1),
      )
    _ -> read_res_index_table_names(bundle, "InstalledLocales")
  }
}

pub fn chop_locale(name: String) -> Option(String) {
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

fn parent_name(rd: ResourceData, current_name: String) -> Option(String) {
  case rd.no_fallback {
    True -> None
    False -> {
      let parent_is_root_res = resource.get_resource(rd, "%%ParentIsRoot")
      case parent_is_root_res != uresimp.res_bogus {
        True -> Some(root_locale_name)
        False -> {
          let parent_res = resource.get_resource(rd, "%%Parent")
          case parent_res != uresimp.res_bogus {
            True -> {
              let value = resource.create_resource_value(Some(rd), parent_res)
              case resource.resource_value_get_string(value) {
                Some(s) if s.text != "" -> Some(s.text)
                _ -> chop_locale(current_name)
              }
            }
            False -> chop_locale(current_name)
          }
        }
      }
    }
  }
}

pub fn open_locale_chain(
  bundle: Bundle,
  name: String,
) -> List(LocaleChainEntry) {
  let current_name = case name {
    "" -> root_locale_name
    _ -> name
  }
  open_locale_chain_loop(bundle, current_name, [], [])
}

fn resolve_usable(
  bundle: Bundle,
  name: String,
) -> #(String, Option(ResourceData)) {
  let usable_name = resolve_bundle_name(bundle, name)
  case load_resource_data(bundle, usable_name) {
    Some(rd) -> #(usable_name, Some(rd))
    None ->
      case chop_locale(usable_name) {
        None -> #(
          root_locale_name,
          load_resource_data(bundle, root_locale_name),
        )
        Some(parent) -> resolve_usable(bundle, parent)
      }
  }
}

fn open_locale_chain_loop(
  bundle: Bundle,
  current_name: String,
  seen: List(String),
  acc: List(LocaleChainEntry),
) -> List(LocaleChainEntry) {
  let #(usable_name, res_data) = resolve_usable(bundle, current_name)
  case list.contains(seen, usable_name) {
    True -> list.reverse(acc)
    False -> {
      let seen = [usable_name, ..seen]
      let acc = [LocaleChainEntry(usable_name, res_data), ..acc]
      case usable_name == root_locale_name {
        True -> list.reverse(acc)
        False ->
          case res_data {
            None -> list.reverse(acc)
            Some(rd) ->
              case parent_name(rd, usable_name) {
                None ->
                  case usable_name != root_locale_name {
                    True ->
                      list.reverse([
                        LocaleChainEntry(
                          root_locale_name,
                          load_resource_data(bundle, root_locale_name),
                        ),
                        ..acc
                      ])
                    False -> list.reverse(acc)
                  }
                Some(next_parent_name) ->
                  open_locale_chain_loop(bundle, next_parent_name, seen, acc)
              }
          }
      }
    }
  }
}

fn split_first(s: String, sep: String) -> #(String, Option(String)) {
  case string.split_once(s, sep) {
    Ok(#(first, rest)) -> #(first, Some(rest))
    Error(_) -> #(s, None)
  }
}

pub fn parse_alias_target(
  bundle: Bundle,
  ch_alias: String,
  chain: List(LocaleChainEntry),
) -> AliasTarget {
  let #(locale, key_path) = case string.starts_with(ch_alias, "/") {
    True -> {
      let rest = string.drop_start(ch_alias, 1)
      let #(first, after) = split_first(rest, "/")
      case first {
        "LOCALE" -> #(None, after)
        _ ->
          case after {
            None -> #(Some(""), None)
            Some(after_value) -> {
              let #(loc, kp) = split_first(after_value, "/")
              #(Some(loc), kp)
            }
          }
      }
    }
    False -> {
      let #(loc, kp) = split_first(ch_alias, "/")
      #(Some(loc), kp)
    }
  }

  let target_chain = case locale {
    None -> chain
    Some(loc) -> open_locale_chain(bundle, loc)
  }
  AliasTarget(target_chain:, key_path:)
}

pub fn resolve_alias(
  bundle: Bundle,
  res_data: ResourceData,
  res: Int,
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Result(ResolvedResource, String) {
  case uresimp.res_get_type(res) != uresimp.ResAlias {
    True -> Ok(ResolvedResource(res_data, res))
    False ->
      case depth > max_alias_level {
        True -> Error("too many alias levels")
        False -> {
          let value = resource.create_resource_value(Some(res_data), res)
          case resource.resource_value_get_alias_string(value) {
            None -> Error("bad alias")
            Some(alias) if alias.text == "" -> Error("bad alias")
            Some(alias) -> {
              let target = parse_alias_target(bundle, alias.text, chain)
              case target.key_path {
                None ->
                  case target.target_chain {
                    [] -> Error("alias target locale not found: " <> alias.text)
                    [head, ..] ->
                      case head.res_data {
                        None ->
                          Error("alias target locale not found: " <> alias.text)
                        Some(head_rd) ->
                          Ok(ResolvedResource(head_rd, head_rd.root_res))
                      }
                  }
                Some(key_path) ->
                  case
                    get_by_path(
                      bundle,
                      target.target_chain,
                      key_path,
                      depth + 1,
                    )
                  {
                    None -> Error("alias target not found: " <> alias.text)
                    Some(found) -> Ok(found)
                  }
              }
            }
          }
        }
      }
  }
}

fn navigate_path_single(
  bundle: Bundle,
  res_data: ResourceData,
  segments: List(String),
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Option(ResolvedResource) {
  navigate_path_single_loop(
    bundle,
    res_data,
    res_data.root_res,
    segments,
    depth,
    chain,
  )
}

fn navigate_path_single_loop(
  bundle: Bundle,
  cur_res_data: ResourceData,
  cur_res: Int,
  segments: List(String),
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Option(ResolvedResource) {
  case segments {
    [] -> Some(ResolvedResource(cur_res_data, cur_res))
    [seg, ..rest] ->
      case uresimp.ures_is_table(uresimp.res_get_type(cur_res)) {
        False -> None
        True -> {
          let next = resource.get_table_item_by_key(cur_res_data, cur_res, seg)
          case next == uresimp.res_bogus {
            True -> None
            False ->
              case uresimp.res_get_type(next) == uresimp.ResAlias {
                True ->
                  navigate_alias_path(
                    bundle,
                    cur_res_data,
                    next,
                    rest,
                    depth,
                    chain,
                  )
                False ->
                  navigate_path_single_loop(
                    bundle,
                    cur_res_data,
                    next,
                    rest,
                    depth,
                    chain,
                  )
              }
          }
        }
      }
  }
}

fn navigate_alias_path(
  bundle: Bundle,
  cur_res_data: ResourceData,
  next: Int,
  remaining: List(String),
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Option(ResolvedResource) {
  case depth >= max_alias_level {
    True -> None
    False -> {
      let value = resource.create_resource_value(Some(cur_res_data), next)
      case resource.resource_value_get_alias_string(value) {
        None -> None
        Some(alias) if alias.text == "" -> None
        Some(alias) -> {
          let target = parse_alias_target(bundle, alias.text, chain)
          case target.key_path {
            None ->
              case target.target_chain {
                [] -> None
                [head, ..] ->
                  case head.res_data {
                    None -> None
                    Some(head_rd) ->
                      case remaining {
                        [] -> Some(ResolvedResource(head_rd, head_rd.root_res))
                        _ ->
                          navigate_path_single(
                            bundle,
                            head_rd,
                            remaining,
                            depth + 1,
                            target.target_chain,
                          )
                      }
                  }
              }
            Some(key_path) -> {
              let full_path = case remaining {
                [] -> key_path
                _ -> key_path <> "/" <> string.join(remaining, "/")
              }
              get_by_path(bundle, target.target_chain, full_path, depth + 1)
            }
          }
        }
      }
    }
  }
}

fn navigate_path_container(
  bundle: Bundle,
  res_data: ResourceData,
  segments: List(String),
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Option(ResolvedResource) {
  navigate_path_container_loop(
    bundle,
    res_data,
    res_data.root_res,
    segments,
    depth,
    chain,
  )
}

fn navigate_path_container_loop(
  bundle: Bundle,
  cur_res_data: ResourceData,
  cur_res: Int,
  segments: List(String),
  depth: Int,
  chain: List(LocaleChainEntry),
) -> Option(ResolvedResource) {
  case segments {
    [] -> Some(ResolvedResource(cur_res_data, cur_res))
    [seg] ->
      case uresimp.ures_is_table(uresimp.res_get_type(cur_res)) {
        False -> None
        True -> {
          let next = resource.get_table_item_by_key(cur_res_data, cur_res, seg)
          case next == uresimp.res_bogus {
            True -> None
            False -> Some(ResolvedResource(cur_res_data, next))
          }
        }
      }
    [seg, ..rest] ->
      case uresimp.ures_is_table(uresimp.res_get_type(cur_res)) {
        False -> None
        True -> {
          let next = resource.get_table_item_by_key(cur_res_data, cur_res, seg)
          case next == uresimp.res_bogus {
            True -> None
            False ->
              case resolve_alias(bundle, cur_res_data, next, depth, chain) {
                Error(_) -> None
                Ok(resolved) ->
                  navigate_path_container_loop(
                    bundle,
                    resolved.res_data,
                    resolved.res,
                    rest,
                    depth,
                    chain,
                  )
              }
          }
        }
      }
  }
}

fn path_segments(path: String) -> List(String) {
  let key = "path\n" <> path
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) -> cache.put(key, string.split(path, "/"))
  }
}

pub fn get_by_path(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  path: String,
  depth: Int,
) -> Option(ResolvedResource) {
  let segments = path_segments(path)
  get_by_path_loop(bundle, chain, chain, segments, depth)
}

fn get_by_path_loop(
  bundle: Bundle,
  full_chain: List(LocaleChainEntry),
  remaining: List(LocaleChainEntry),
  segments: List(String),
  depth: Int,
) -> Option(ResolvedResource) {
  case remaining {
    [] -> None
    [level, ..rest] ->
      case level.res_data {
        None -> get_by_path_loop(bundle, full_chain, rest, segments, depth)
        Some(rd) ->
          case navigate_path_single(bundle, rd, segments, depth, full_chain) {
            Some(found) -> Some(found)
            None -> get_by_path_loop(bundle, full_chain, rest, segments, depth)
          }
      }
  }
}

fn enumerate_table(
  bundle: Bundle,
  res_data: ResourceData,
  res: Int,
  chain: List(LocaleChainEntry),
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
) -> acc {
  let table = resource.get_table(res_data, res)
  enumerate_table_loop(bundle, res_data, table, chain, acc, visit, 0)
}

fn enumerate_table_loop(
  bundle: Bundle,
  res_data: ResourceData,
  table: resource.ResourceTableView,
  chain: List(LocaleChainEntry),
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
  i: Int,
) -> acc {
  case i >= table.length {
    True -> acc
    False ->
      case table.get_key, table.get_res {
        Some(get_key), Some(get_res) -> {
          let key = get_key(i)
          let item_res = get_res(i)
          let acc = case uresimp.res_get_type(item_res) == uresimp.ResAlias {
            True ->
              case resolve_alias(bundle, res_data, item_res, 0, chain) {
                Error(_) -> acc
                Ok(resolved) -> visit(acc, key, resolved.res_data, resolved.res)
              }
            False -> visit(acc, key, res_data, item_res)
          }
          enumerate_table_loop(
            bundle,
            res_data,
            table,
            chain,
            acc,
            visit,
            i + 1,
          )
        }
        _, _ -> acc
      }
  }
}

pub fn get_all_children_with_fallback(
  bundle: Bundle,
  chain: List(LocaleChainEntry),
  path: String,
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
) -> acc {
  let segments = case path {
    "" -> []
    _ -> path_segments(path)
  }
  get_all_children_with_fallback_loop(
    bundle,
    chain,
    chain,
    segments,
    acc,
    visit,
  )
}

fn get_all_children_with_fallback_loop(
  bundle: Bundle,
  full_chain: List(LocaleChainEntry),
  remaining: List(LocaleChainEntry),
  segments: List(String),
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
) -> acc {
  case remaining {
    [] -> acc
    [level, ..rest] -> {
      let acc =
        visit_level_children(bundle, level, full_chain, segments, acc, visit)
      get_all_children_with_fallback_loop(
        bundle,
        full_chain,
        rest,
        segments,
        acc,
        visit,
      )
    }
  }
}

fn visit_level_children(
  bundle: Bundle,
  level: LocaleChainEntry,
  chain: List(LocaleChainEntry),
  segments: List(String),
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
) -> acc {
  case level.res_data {
    None -> acc
    Some(rd) -> {
      let found = case segments {
        [] -> Some(ResolvedResource(rd, rd.root_res))
        _ -> navigate_path_container(bundle, rd, segments, 0, chain)
      }
      case found {
        None -> acc
        Some(f) ->
          case uresimp.res_get_type(f.res) == uresimp.ResAlias {
            True -> visit_aliased_children(bundle, f, chain, acc, visit)
            False ->
              case uresimp.ures_is_table(uresimp.res_get_type(f.res)) {
                True ->
                  enumerate_table(bundle, f.res_data, f.res, chain, acc, visit)
                False -> acc
              }
          }
      }
    }
  }
}

fn visit_aliased_children(
  bundle: Bundle,
  f: ResolvedResource,
  chain: List(LocaleChainEntry),
  acc: acc,
  visit: fn(acc, String, ResourceData, Int) -> acc,
) -> acc {
  let value = resource.create_resource_value(Some(f.res_data), f.res)
  case resource.resource_value_get_alias_string(value) {
    None -> acc
    Some(alias) if alias.text != "" -> {
      let target = parse_alias_target(bundle, alias.text, chain)
      case target.key_path {
        None ->
          case target.target_chain {
            [] -> acc
            [head, ..] ->
              case head.res_data {
                None -> acc
                Some(head_rd) ->
                  case
                    uresimp.ures_is_table(uresimp.res_get_type(head_rd.root_res))
                  {
                    True ->
                      enumerate_table(
                        bundle,
                        head_rd,
                        head_rd.root_res,
                        chain,
                        acc,
                        visit,
                      )
                    False -> acc
                  }
              }
          }
        Some(key_path) ->
          get_all_children_with_fallback(
            bundle,
            target.target_chain,
            key_path,
            acc,
            visit,
          )
      }
    }
    _ -> acc
  }
}
