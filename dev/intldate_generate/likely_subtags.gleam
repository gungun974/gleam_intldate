import gleam/dynamic/decode
import intldate/internal/icu/icudata/resource.{LikelySubtagsData}
import intldate_generate/icurb
import intldate_generate/save
import simplifile

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/langInfo.txt")

  let assert Ok(data) = parse_likely_subtags(contents)
  save.save_likely_subtags_data(data)
  data
}

fn parse_likely_subtags(contents: String) {
  icurb.parse(contents, {
    use language_aliases <- decode.subfield(
      ["likely", "languageAliases"],
      decode.list(decode.string),
    )
    use lsrnum <- decode.subfield(["likely", "lsrnum"], decode.list(decode.int))
    use m49 <- decode.subfield(["likely", "m49"], decode.list(decode.string))
    use region_aliases <- decode.subfield(
      ["likely", "regionAliases"],
      decode.list(decode.string),
    )
    use trie <- decode.subfield(["likely", "trie"], decode.bit_array)

    use match_distances <- decode.subfield(
      ["match", "distances"],
      decode.list(decode.int),
    )
    use match_paradigmnum <- decode.subfield(
      ["match", "paradigmnum"],
      decode.list(decode.int),
    )
    use match_partitions <- decode.subfield(
      ["match", "partitions"],
      decode.list(decode.string),
    )
    use match_region_to_partitions <- decode.subfield(
      ["match", "regionToPartitions"],
      decode.bit_array,
    )
    use match_trie <- decode.subfield(["match", "trie"], decode.bit_array)

    decode.success(LikelySubtagsData(
      language_aliases:,
      lsrnum:,
      m49:,
      region_aliases:,
      trie:,
      match_distances:,
      match_paradigmnum:,
      match_partitions:,
      match_region_to_partitions:,
      match_trie:,
    ))
  })
}
