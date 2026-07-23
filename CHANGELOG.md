# Changelog

## Unreleased

## [2.0.0] - 23/07/2026

- Full Erlang target support alongside JavaScript, backed by a native Gleam
  recreation of ICU 78.3's own algorithms and data
- Add proper optional error handling API with `try_*` variants (`try_format`,
  `try_format_to_parts`, `try_format_range`, `try_format_range_to_parts`) returning
  a `Result` instead of an error message
- Add `intlrelative` to format duration like `Intl.RelativeTimeFormat`
- Add `format_to_parts` to `intldate` and `intlrelative` to format into structured
  parts like `Intl.DateTimeFormat.prototype.formatToParts` and
  `Intl.RelativeTimeFormat.prototype.formatToParts`
- Add `format_range` and `format_range_to_parts` to `intldate` to format a date
  range like `Intl.DateTimeFormat.prototype.formatRange` and `formatRangeToParts`
- Add `resolved_options` to `intldate` and `intlrelative` like
  `Intl.DateTimeFormat.prototype.resolvedOptions` and
  `Intl.RelativeTimeFormat.prototype.resolvedOptions`

## [1.0.0] - 25/02/2026

- 🎉 First release!

