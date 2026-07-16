import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None}
import intldate/internal/icu/icudata/resource.{
  JapaneseEra, SupplementalData, TimeData,
}
import intldate_generate/icurb
import intldate_generate/save
import simplifile

pub fn generate(icu_path: String) {
  let assert Ok(contents) =
    simplifile.read(icu_path <> "/icu4c/source/data/misc/supplementalData.txt")

  let assert Ok(supplemental_data) = parse_supplemental_data(contents)
  save.save_supplemental_data(supplemental_data)
  supplemental_data
}

fn parse_supplemental_data(contents: String) {
  icurb.parse(contents, {
    use time_data <- decode.field(
      "timeData",
      decode.dict(decode.string, {
        use allowed <- decode.field(
          "allowed",
          decode.one_of(decode.list(decode.string), [
            {
              use allowed <- decode.then(decode.string)
              decode.success([allowed])
            },
          ]),
        )
        use preferred <- decode.optional_field(
          "preferred",
          None,
          decode.optional(decode.string),
        )
        decode.success(TimeData(allowed:, preferred:))
      }),
    )

    use week_data <- decode.field(
      "weekData",
      decode.dict(decode.string, {
        use a <- decode.field(0, decode.int)
        use b <- decode.field(1, decode.int)
        use c <- decode.field(2, decode.int)
        use d <- decode.field(3, decode.int)
        use e <- decode.field(4, decode.int)
        use f <- decode.field(5, decode.int)
        decode.success(#(a, b, c, d, e, f))
      }),
    )

    use calendar_preference <- decode.field(
      "calendarPreferenceData",
      decode.dict(decode.string, decode.list(decode.string)),
    )

    use japanese_era_by_index <- decode.subfield(
      ["calendarData", "japanese", "eras"],
      decode.dict(
        {
          use era <- decode.then(decode.string)
          case int.parse(era) {
            Ok(era) -> decode.success(era)
            Error(_) -> decode.failure(0, "")
          }
        },
        {
          use start <- decode.field("start", {
            use a <- decode.field(0, decode.int)
            use b <- decode.field(1, decode.int)
            use c <- decode.field(2, decode.int)
            decode.success(#(a, b, c))
          })
          decode.success(start)
        },
      ),
    )

    let japanese_eras =
      japanese_era_by_index
      |> dict.to_list
      |> list.sort(fn(a, b) { int.compare(b.0, a.0) })
      |> list.map(fn(entry) {
        JapaneseEra(
          index: entry.0,
          year: entry.1.0,
          month: entry.1.1,
          day: entry.1.2,
          named: False,
        )
      })

    decode.success(SupplementalData(
      time_data:,
      week_data:,
      calendar_preference:,
      japanese_eras:,
    ))
  })
}
