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

## Relative time formatting

The `intlrelative` module formats durations as human-readable relative times
following the JavaScript `Intl.RelativeTimeFormat()` API. On JavaScript it delegates
to the native `Intl.RelativeTimeFormat()`, while on Erlang it relies on the same pure
Gleam reimplementation, so the output stays consistent whichever target you compile to.

A negative duration is formatted as a time in the past and a positive duration as a
time in the future. The `unit` you pass selects which unit the duration is expressed in.

```gleam
import gleam/option
import gleam/time/duration
import intlrelative

pub fn main() {
  let result =
    intlrelative.format(
      duration: duration.seconds(-5),
      unit: intlrelative.Second,
      locale: option.Some("fr-FR"),
      config: intlrelative.new(),
    )

  // result == "il y a 5 secondes"
}
```

## Error handling

`intldate.format` never fails: if the time zone, locale, or calendar cannot be
resolved, it returns a human-readable, English-only message describing the error
(via `intldate.describe_error`), regardless of the requested locale. The same holds
for `intlrelative.format`, which returns such a message if the locale cannot be
resolved.

If you'd rather handle the error yourself, use `intldate.try_format` (or
`intlrelative.try_format`), which returns a `Result(String, intldate.IntlError)`:

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

## More than just `format`

Both modules mirror more of their `Intl` counterparts than the basic example above:

- `intldate.format_to_parts` / `intlrelative.format_to_parts` — structured parts,
  like `Intl.DateTimeFormat.prototype.formatToParts` / `formatToParts`.
- `intldate.format_range` / `intldate.format_range_to_parts` — format a date range
  together, collapsing the parts the two dates share, like
  `Intl.DateTimeFormat.prototype.formatRange` / `formatRangeToParts`.
- `intldate.resolved_options` / `intlrelative.resolved_options` — the options
  actually resolved for a given locale/config, like
  `Intl.DateTimeFormat.prototype.resolvedOptions` / `resolvedOptions`.

Each has a `try_*` variant returning a `Result` instead of an error message, same as
`try_format`.

Further documentation can be found at <https://hexdocs.pm/intldate>.

## Development

The locale data under `priv/` is generated from ICU's own data (downloaded from
a pinned ICU release) and is not committed, so you need to build it before
running the tests:

```sh
git clone https://github.com/gungun974/gleam_intldate.git
cd gleam_intldate

gleam run -m intldate_generate

gleam run --target javascript -m intldate_test_data 
gleam test
```

`gleam run --target javascript -m intldate_test_data` generates the test data from
Node's built-in `Intl`, so it requires a Node version bundling ICU 78.3 to match the
pinned ICU release used elsewhere.
