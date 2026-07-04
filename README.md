# intldate

Date formatting for `gleam_time` following the JavaScript `Intl.DateTimeFormat()` API

***Works on both the JavaScript and Erlang runtimes***

On JavaScript it delegates to the native `Intl.DateTimeFormat()`, while on Erlang
it relies on a pure Gleam reimplementation that mirrors the same behaviour, so you
get consistent results whichever target you compile to.

[![Package Version](https://img.shields.io/hexpm/v/intldate)](https://hex.pm/packages/intldate)
[![JavaScript Compatible](https://img.shields.io/badge/target-javascript-f3e155)](https://en.wikipedia.org/wiki/JavaScript)
[![Erlang Compatible](https://img.shields.io/badge/target-erlang-a90533)](https://www.erlang.org/)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/intldate/)

```sh
gleam add intldate@2
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

## Error handling

`intldate.format` never fails: if the time zone, locale, or calendar cannot be
resolved, it returns a human-readable, English-only message describing the error
(via `intldate.describe_error`), regardless of the requested locale.

If you'd rather handle the error yourself, use `intldate.try_format`, which
returns a `Result(String, intldate.IntlError)`:

```gleam
import gleam/option
import gleam/time/timestamp
import intldate

pub fn main() {
  let assert Ok(date) = timestamp.parse_rfc3339("2026-02-24T17:48:22+04:00")

  let result =
    intldate.try_format(
      date:,
      time_zone: option.Some("Invalid/TimeZone"),
      locale: option.Some("fr-FR"),
      config: intldate.new()
        |> intldate.with_year(intldate.YearNumeric)
        |> intldate.with_month(intldate.MonthLong)
        |> intldate.with_day(intldate.DayNumeric),
    )

  // result == Error(intldate.FailedToLoadTimeZone("Invalid/TimeZone"))
}
```

## Time zone database on Erlang

On Erlang, resolving a time zone requires an IANA `TzDatabase`. By default, `intldate`
tries to load one from the operating system (typically `/usr/share/zoneinfo`). If the
OS has no such data, formatting fails with `FailedToLoadTimeZone`.

To avoid depending on what is installed on the host machine, call
`intldate.set_time_zone_database` once at startup with a database of your choice, for
example the one bundled by the [`zones`](https://hex.pm/packages/zones) package, which
ships a full copy of the IANA time zone database:

```sh
gleam add zones
```
```gleam
import intldate
import zones

pub fn main() {
  intldate.set_time_zone_database(zones.database())

  // ... the rest of your application
}
```

This has no effect on JavaScript, where time zones are resolved by the native
`Intl.DateTimeFormat()`.

Further documentation can be found at <https://hexdocs.pm/intldate>.

## Development

The locale data under `priv/` is generated from the CLDR packages and is not
committed, so you need to build it before running the tests:

```sh
git clone https://github.com/gungun974/gleam_intldate.git
cd gleam_intldate

pnpm install
pnpm run generate

gleam test
```
