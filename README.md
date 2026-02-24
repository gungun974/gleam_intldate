# intldate

Date formating for `gleam_time` powered by JavaScript `Intl.DateTimeFormat()`

***Only work for JavaScript runtime***

[![Package Version](https://img.shields.io/hexpm/v/intldate)](https://hex.pm/packages/intldate)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/intldate/)

```sh
gleam add intldate@1
```
```gleam
import gleam/option
import gleam/time/timestamp
import intldate

pub fn main() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")

  let result =
    intldate.format(
      date:,
      time_zone: option.Some("Indian/Reunion"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_weekday(intldate.WeekdayLong)
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric)
        |> intldate.with_hour(intldate.HourNumeric)
        |> intldate.with_minute(intldate.MinuteNumeric),
    )

  // result == "mardi 24 février 2026 à 17:48"
}
```

Further documentation can be found at <https://hexdocs.pm/intldate>.
