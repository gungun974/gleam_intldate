import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import intldate/internal/icu/icudata/resource.{
  FinalRule, Zone, ZoneAlias, ZoneInfo64,
}
import intldate_generate/icurb
import intldate_generate/save
import intldate_generate/shared
import simplifile

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/zoneinfo64.txt")

  let assert Ok(zone_info) = parse_zoneinfo64(contents)
  save.save_zone_info_64(zone_info)
  zone_info
}

fn parse_zoneinfo64(contents: String) {
  icurb.parse(contents, {
    use names <- decode.field("Names", decode.list(decode.string))

    use zones <- decode.field(
      "Zones",
      decode.list(
        decode.one_of(
          {
            use alias_index <- decode.then(decode.int)
            case shared.list_at(names, alias_index) {
              Ok(alias) -> decode.success(ZoneAlias(alias))
              Error(_) -> decode.failure(ZoneAlias(""), "")
            }
          },
          [
            {
              use trans_pre32 <- decode.optional_field(
                "transPre32",
                [],
                decode.list(decode.int),
              )
              use trans <- decode.optional_field(
                "trans",
                [],
                decode.list(decode.int),
              )
              use trans_post32 <- decode.optional_field(
                "transPost32",
                [],
                decode.list(decode.int),
              )
              use type_offsets <- decode.field(
                "typeOffsets",
                decode.list(decode.int),
              )
              use type_map <- decode.optional_field(
                "typeMap",
                None,
                decode.optional(decode.bit_array),
              )
              use final_rule_name <- decode.optional_field(
                "finalRule",
                None,
                decode.optional(decode.string),
              )
              use final_rule <- decode.then(case final_rule_name {
                Some(rule) -> {
                  use raw <- decode.field("finalRaw", decode.int)
                  use year <- decode.field("finalYear", decode.int)
                  decode.success(Some(FinalRule(rule:, raw:, year:)))
                }
                None -> decode.success(None)
              })
              let transitions =
                combine_pairs(trans_pre32)
                |> list.append(trans)
                |> list.append(combine_pairs(trans_post32))
              decode.success(Zone(
                transitions_count: list.length(transitions),
                transitions_index: list.index_fold(
                  transitions,
                  dict.new(),
                  fn(acc, transition, index) {
                    dict.insert(acc, index, transition)
                  },
                ),
                type_offsets:,
                type_map:,
                final_rule:,
              ))
            },
          ],
        ),
      ),
    )

    use regions <- decode.field("Regions", decode.list(decode.string))

    use rules <- decode.field(
      "Rules",
      decode.dict(decode.string, decode.list(decode.int)),
    )

    decode.success(ZoneInfo64(
      zones: list.index_fold(names, dict.new(), fn(acc, name, i) {
        case shared.list_at(zones, i) {
          Ok(zone) -> dict.insert(acc, name, zone)
          Error(_) -> acc
        }
      }),
      rules:,
      regions: list.index_fold(names, dict.new(), fn(acc, name, i) {
        case shared.list_at(regions, i) {
          Ok(region) -> dict.insert(acc, name, region)
          Error(_) -> acc
        }
      }),
    ))
  })
}

fn combine64(hi: Int, lo: Int) -> Int {
  let lo_unsigned = case lo < 0 {
    True -> lo + 4_294_967_296
    False -> lo
  }
  hi * 4_294_967_296 + lo_unsigned
}

fn combine_pairs(arr: List(Int)) -> List(Int) {
  case arr {
    [hi, lo, ..rest] -> [combine64(hi, lo), ..combine_pairs(rest)]
    _ -> []
  }
}
