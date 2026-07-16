import gleam/dict
import gleam/dynamic/decode
import intldate/internal/icu/icudata/resource.{NumberingSystem, NumberingSystems}
import intldate_generate/icurb
import intldate_generate/save
import simplifile

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/numberingSystems.txt")

  let assert Ok(numbering_systems) = parse_numbering_systems(contents)
  save.save_numbering_systems(numbering_systems)
  numbering_systems
}

fn parse_numbering_systems(contents: String) {
  icurb.parse(contents, {
    use numbering_systems <- decode.field(
      "numberingSystems",
      decode.dict(decode.string, {
        use radix <- decode.field("radix", decode.int)
        use algorithmic <- decode.field("algorithmic", decode.int)
        use desc <- decode.field("desc", decode.string)

        decode.success(NumberingSystem(
          radix:,
          algorithmic: algorithmic == 1,
          desc:,
          name: "",
        ))
      }),
    )

    decode.success(
      NumberingSystems(
        numbering_systems: dict.map_values(numbering_systems, fn(k, v) {
          NumberingSystem(..v, name: k)
        }),
      ),
    )
  })
}
