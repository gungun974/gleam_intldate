import gleam/list
import gleam/option
import gleam/string
import gleam/time/duration
import intlrelative

pub fn format_past_seconds_fr_test() {
  let result =
    intlrelative.format(
      duration: duration.seconds(-5),
      unit: intlrelative.Second,
      locale: option.Some("fr-FR"),
      config: intlrelative.new(),
    )

  assert result == "il y a 5 secondes"
}

pub fn format_to_parts_reconstructs_format_en_test() {
  let config = intlrelative.new()

  let formatted =
    intlrelative.format(
      duration: duration.hours(3),
      unit: intlrelative.Hour,
      locale: option.Some("en-US"),
      config:,
    )

  let reconstructed =
    intlrelative.format_to_parts(
      duration: duration.hours(3),
      unit: intlrelative.Hour,
      locale: option.Some("en-US"),
      config:,
    )
    |> list.map(fn(part) { part.value })
    |> string.concat

  assert reconstructed == formatted
}

pub fn resolved_options_relative_test() {
  let result =
    intlrelative.resolved_options(
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_style(intlrelative.Short)
        |> intlrelative.with_numeric(intlrelative.Auto),
    )

  let assert Ok(options) = result
  assert options.locale == "en-US"
  assert options.style == "short"
  assert options.numeric == "auto"
}

pub fn format_future_hours_en_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(3),
      unit: intlrelative.Hour,
      locale: option.Some("en-US"),
      config: intlrelative.new(),
    )

  assert result == "in 3 hours"
}

pub fn format_past_day_numeric_auto_fr_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-24),
      unit: intlrelative.Day,
      locale: option.Some("fr-FR"),
      config: intlrelative.new()
        |> intlrelative.with_numeric(intlrelative.Auto),
    )

  assert result == "hier"
}

pub fn format_past_day_numeric_always_fr_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-24),
      unit: intlrelative.Day,
      locale: option.Some("fr-FR"),
      config: intlrelative.new()
        |> intlrelative.with_numeric(intlrelative.Always),
    )

  assert result == "il y a 1 jour"
}

pub fn format_future_day_auto_en_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24),
      unit: intlrelative.Day,
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_numeric(intlrelative.Auto),
    )

  assert result == "tomorrow"
}

pub fn format_short_style_minutes_en_test() {
  let result =
    intlrelative.format(
      duration: duration.minutes(2),
      unit: intlrelative.Minute,
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_style(intlrelative.Short)
        |> intlrelative.with_numeric(intlrelative.Always),
    )

  assert result == "in 2 min."
}

pub fn format_narrow_style_hours_en_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-1),
      unit: intlrelative.Hour,
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_style(intlrelative.Narrow),
    )

  assert result == "1h ago"
}

pub fn format_long_style_weeks_es_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-2 * 7 * 24),
      unit: intlrelative.Week,
      locale: option.Some("es-ES"),
      config: intlrelative.new()
        |> intlrelative.with_style(intlrelative.Long),
    )

  assert result == "hace 2 semanas"
}

pub fn format_future_months_de_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24 * 7 * 13)
        |> duration.add(duration.hours(7))
        |> duration.add(duration.minutes(27))
        |> duration.add(duration.seconds(18)),
      unit: intlrelative.Month,
      locale: option.Some("de-DE"),
      config: intlrelative.new(),
    )

  assert result == "in 3 Monaten"
}

pub fn format_past_quarters_en_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24 * 7 * -26)
        |> duration.add(duration.hours(-14))
        |> duration.add(duration.minutes(-54))
        |> duration.add(duration.seconds(-36)),
      unit: intlrelative.Quarter,
      locale: option.Some("en-US"),
      config: intlrelative.new(),
    )

  assert result == "2 quarters ago"
}

pub fn format_future_years_ja_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24 * 7 * 260)
        |> duration.add(duration.hours(24 * 6))
        |> duration.add(duration.hours(5))
        |> duration.add(duration.minutes(6)),
      unit: intlrelative.Year,
      locale: option.Some("ja-JP"),
      config: intlrelative.new(),
    )

  assert result == "5 年後"
}

pub fn format_past_year_numeric_auto_en_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24 * 7 * -52)
        |> duration.add(duration.hours(24 * -1))
        |> duration.add(duration.hours(-5))
        |> duration.add(duration.minutes(-49))
        |> duration.add(duration.seconds(-12)),
      unit: intlrelative.Year,
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_numeric(intlrelative.Auto),
    )

  assert result == "last year"
}

pub fn format_now_seconds_auto_en_test() {
  let result =
    intlrelative.format(
      duration: duration.seconds(0),
      unit: intlrelative.Second,
      locale: option.Some("en-US"),
      config: intlrelative.new()
        |> intlrelative.with_numeric(intlrelative.Auto),
    )

  assert result == "now"
}

pub fn format_with_none_locale_default_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-1),
      unit: intlrelative.Hour,
      locale: option.None,
      config: intlrelative.new(),
    )

  assert result == "1 hour ago"
}

pub fn format_short_style_quarter_fr_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(24 * 7 * 13)
        |> duration.add(duration.hours(7))
        |> duration.add(duration.minutes(27))
        |> duration.add(duration.seconds(18)),
      unit: intlrelative.Quarter,
      locale: option.Some("fr-FR"),
      config: intlrelative.new()
        |> intlrelative.with_style(intlrelative.Short),
    )

  assert result == "dans 1 trim."
}

pub fn format_with_locale_matcher_lookup_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-2),
      unit: intlrelative.Hour,
      locale: option.Some("fr-CA"),
      config: intlrelative.new()
        |> intlrelative.with_locale_matcher(intlrelative.LocaleMatcherLookup),
    )

  assert result == "il y a 2 heures"
}

pub fn format_with_locale_matcher_best_fit_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(3 * 24),
      unit: intlrelative.Day,
      locale: option.Some("it-IT"),
      config: intlrelative.new()
        |> intlrelative.with_locale_matcher(intlrelative.LocaleMatcherBestFit)
        |> intlrelative.with_style(intlrelative.Long)
        |> intlrelative.with_numeric(intlrelative.Always),
    )

  assert result == "tra 3 giorni"
}

pub fn try_format_returns_error_for_invalid_locale_test() {
  let result =
    intlrelative.try_format(
      duration: duration.hours(-1),
      unit: intlrelative.Hour,
      locale: option.Some("xx-XX"),
      config: intlrelative.new(),
    )

  assert result == Error(intlrelative.FailedToLoadLocale("xx-XX"))
}

pub fn format_returns_error_message_for_invalid_locale_test() {
  let result =
    intlrelative.format(
      duration: duration.hours(-1),
      unit: intlrelative.Hour,
      locale: option.Some("xx-XX"),
      config: intlrelative.new(),
    )

  assert result == "Failed to load locale: xx-XX"
}

pub fn resolved_options_returns_error_for_invalid_locale_test() {
  let result =
    intlrelative.resolved_options(
      locale: option.Some("xx-XX"),
      config: intlrelative.new(),
    )

  assert result == Error(intlrelative.FailedToLoadLocale("xx-XX"))
}

pub fn resolved_options_returns_error_for_malformed_locale_test() {
  let result =
    intlrelative.resolved_options(
      locale: option.Some("en_US"),
      config: intlrelative.new(),
    )

  assert result == Error(intlrelative.FailedToLoadLocale("en_US"))
}

pub fn resolved_options_preserves_numbering_system_extension_test() {
  let assert Ok(options) =
    intlrelative.resolved_options(
      locale: option.Some("en-US-u-nu-arab"),
      config: intlrelative.new(),
    )

  assert options.locale == "en-US-u-nu-arab"
  assert options.numbering_system == "arab"
}

pub fn resolved_options_uses_locale_default_numbering_system_test() {
  let assert Ok(options) =
    intlrelative.resolved_options(
      locale: option.Some("fa-IR"),
      config: intlrelative.new(),
    )

  assert options.locale == "fa-IR"
  assert options.numbering_system == "arabext"
}
