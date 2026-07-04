import { Option$isSome, Option$Some$0 } from "../gleam_stdlib/gleam/option.mjs";
import * as $timestamp from "../gleam_time/gleam/time/timestamp.mjs";
import {
  LocaleMatcher$isLocaleMatcherBestFit,
  LocaleMatcher$isLocaleMatcherLookup,
  Calendar$isCalendarBuddhist,
  Calendar$isCalendarChinese,
  Calendar$isCalendarCoptic,
  Calendar$isCalendarDangi,
  Calendar$isCalendarEthioaa,
  Calendar$isCalendarEthiopic,
  Calendar$isCalendarGregory,
  Calendar$isCalendarHebrew,
  Calendar$isCalendarIndian,
  Calendar$isCalendarIslamic,
  Calendar$isCalendarIslamicUmalqura,
  Calendar$isCalendarIslamicTbla,
  Calendar$isCalendarIslamicCivil,
  Calendar$isCalendarIslamicRgsa,
  Calendar$isCalendarIso8601,
  Calendar$isCalendarJapanese,
  Calendar$isCalendarPersian,
  Calendar$isCalendarRoc,
  Weekday$isWeekdayLong,
  Weekday$isWeekdayShort,
  Weekday$isWeekdayNarrow,
  Era$isEraLong,
  Era$isEraShort,
  Era$isEraNarrow,
  Year$isYearNumeric,
  Year$isYear2Digit,
  Month$isMonthNumeric,
  Month$isMonth2Digit,
  Month$isMonthLong,
  Month$isMonthShort,
  Month$isMonthNarrow,
  Day$isDayNumeric,
  Day$isDay2Digit,
  Hour$isHourNumeric,
  Hour$isHour2Digit,
  Minute$isMinuteNumeric,
  Minute$isMinute2Digit,
  Second$isSecondNumeric,
  Second$isSecond2Digit,
  TimeZoneName$isTimeZoneNameShort,
  TimeZoneName$isTimeZoneNameLong,
  TimeZoneName$isTimeZoneNameShortOffset,
  TimeZoneName$isTimeZoneNameLongOffset,
  TimeZoneName$isTimeZoneNameShortGeneric,
  TimeZoneName$isTimeZoneNameLongGeneric,
  FormatMatcher$isFormatMatcherBestFit,
  FormatMatcher$isFormatMatcherBasic,
  DateTimeFormatConfig$DateTimeFormatConfig$locale_matcher,
  DateTimeFormatConfig$DateTimeFormatConfig$calendar,
  DateTimeFormatConfig$DateTimeFormatConfig$weekday,
  DateTimeFormatConfig$DateTimeFormatConfig$era,
  DateTimeFormatConfig$DateTimeFormatConfig$year,
  DateTimeFormatConfig$DateTimeFormatConfig$month,
  DateTimeFormatConfig$DateTimeFormatConfig$day,
  DateTimeFormatConfig$DateTimeFormatConfig$hour,
  DateTimeFormatConfig$DateTimeFormatConfig$minute,
  DateTimeFormatConfig$DateTimeFormatConfig$second,
  DateTimeFormatConfig$DateTimeFormatConfig$time_zone_name,
  DateTimeFormatConfig$DateTimeFormatConfig$format_matcher,
  DateTimeFormatConfig$DateTimeFormatConfig$hour12,
} from "./intldate.mjs";

export function formatTimestamp(timestamp, timeZone, locale, config) {
  const locale_matcher =
    DateTimeFormatConfig$DateTimeFormatConfig$locale_matcher(config);
  const calendar = DateTimeFormatConfig$DateTimeFormatConfig$calendar(config);
  const weekday = DateTimeFormatConfig$DateTimeFormatConfig$weekday(config);
  const era = DateTimeFormatConfig$DateTimeFormatConfig$era(config);
  const year = DateTimeFormatConfig$DateTimeFormatConfig$year(config);
  const month = DateTimeFormatConfig$DateTimeFormatConfig$month(config);
  const day = DateTimeFormatConfig$DateTimeFormatConfig$day(config);
  const hour = DateTimeFormatConfig$DateTimeFormatConfig$hour(config);
  const minute = DateTimeFormatConfig$DateTimeFormatConfig$minute(config);
  const second = DateTimeFormatConfig$DateTimeFormatConfig$second(config);
  const time_zone_name =
    DateTimeFormatConfig$DateTimeFormatConfig$time_zone_name(config);
  const format_matcher =
    DateTimeFormatConfig$DateTimeFormatConfig$format_matcher(config);
  const hour12 = DateTimeFormatConfig$DateTimeFormatConfig$hour12(config);

  let localeMatcher = undefined;
  if (Option$isSome(locale_matcher)) {
    const value = Option$Some$0(locale_matcher);
    switch (true) {
      case LocaleMatcher$isLocaleMatcherBestFit(value):
        localeMatcher = "best fit";
        break;
      case LocaleMatcher$isLocaleMatcherLookup(value):
        localeMatcher = "lookup";
        break;
    }
  }

  let calendarValue = undefined;
  if (Option$isSome(calendar)) {
    const value = Option$Some$0(calendar);
    switch (true) {
      case Calendar$isCalendarBuddhist(value):
        calendarValue = "buddhist";
        break;
      case Calendar$isCalendarChinese(value):
        calendarValue = "chinese";
        break;
      case Calendar$isCalendarCoptic(value):
        calendarValue = "coptic";
        break;
      case Calendar$isCalendarDangi(value):
        calendarValue = "dangi";
        break;
      case Calendar$isCalendarEthioaa(value):
        calendarValue = "ethioaa";
        break;
      case Calendar$isCalendarEthiopic(value):
        calendarValue = "ethiopic";
        break;
      case Calendar$isCalendarGregory(value):
        calendarValue = "gregory";
        break;
      case Calendar$isCalendarHebrew(value):
        calendarValue = "hebrew";
        break;
      case Calendar$isCalendarIndian(value):
        calendarValue = "indian";
        break;
      case Calendar$isCalendarIslamic(value):
        calendarValue = "islamic";
        break;
      case Calendar$isCalendarIslamicUmalqura(value):
        calendarValue = "islamic-umalqura";
        break;
      case Calendar$isCalendarIslamicTbla(value):
        calendarValue = "islamic-tbla";
        break;
      case Calendar$isCalendarIslamicCivil(value):
        calendarValue = "islamic-civil";
        break;
      case Calendar$isCalendarIslamicRgsa(value):
        calendarValue = "islamic-rgsa";
        break;
      case Calendar$isCalendarIso8601(value):
        calendarValue = "iso8601";
        break;
      case Calendar$isCalendarJapanese(value):
        calendarValue = "japanese";
        break;
      case Calendar$isCalendarPersian(value):
        calendarValue = "persian";
        break;
      case Calendar$isCalendarRoc(value):
        calendarValue = "roc";
        break;
    }
  }

  let weekdayValue = undefined;
  if (Option$isSome(weekday)) {
    const value = Option$Some$0(weekday);
    switch (true) {
      case Weekday$isWeekdayLong(value):
        weekdayValue = "long";
        break;
      case Weekday$isWeekdayShort(value):
        weekdayValue = "short";
        break;
      case Weekday$isWeekdayNarrow(value):
        weekdayValue = "narrow";
        break;
    }
  }

  let eraValue = undefined;
  if (Option$isSome(era)) {
    const value = Option$Some$0(era);
    switch (true) {
      case Era$isEraLong(value):
        eraValue = "long";
        break;
      case Era$isEraShort(value):
        eraValue = "short";
        break;
      case Era$isEraNarrow(value):
        eraValue = "narrow";
        break;
    }
  }

  let yearValue = undefined;
  if (Option$isSome(year)) {
    const value = Option$Some$0(year);
    switch (true) {
      case Year$isYearNumeric(value):
        yearValue = "numeric";
        break;
      case Year$isYear2Digit(value):
        yearValue = "2-digit";
        break;
    }
  }

  let monthValue = undefined;
  if (Option$isSome(month)) {
    const value = Option$Some$0(month);
    switch (true) {
      case Month$isMonthNumeric(value):
        monthValue = "numeric";
        break;
      case Month$isMonth2Digit(value):
        monthValue = "2-digit";
        break;
      case Month$isMonthLong(value):
        monthValue = "long";
        break;
      case Month$isMonthShort(value):
        monthValue = "short";
        break;
      case Month$isMonthNarrow(value):
        monthValue = "narrow";
        break;
    }
  }

  let dayValue = undefined;
  if (Option$isSome(day)) {
    const value = Option$Some$0(day);
    switch (true) {
      case Day$isDayNumeric(value):
        dayValue = "numeric";
        break;
      case Day$isDay2Digit(value):
        dayValue = "2-digit";
        break;
    }
  }

  let hourValue = undefined;
  if (Option$isSome(hour)) {
    const value = Option$Some$0(hour);
    switch (true) {
      case Hour$isHourNumeric(value):
        hourValue = "numeric";
        break;
      case Hour$isHour2Digit(value):
        hourValue = "2-digit";
        break;
    }
  }

  let minuteValue = undefined;
  if (Option$isSome(minute)) {
    const value = Option$Some$0(minute);
    switch (true) {
      case Minute$isMinuteNumeric(value):
        minuteValue = "numeric";
        break;
      case Minute$isMinute2Digit(value):
        minuteValue = "2-digit";
        break;
    }
  }

  let secondValue = undefined;
  if (Option$isSome(second)) {
    const value = Option$Some$0(second);
    switch (true) {
      case Second$isSecondNumeric(value):
        secondValue = "numeric";
        break;
      case Second$isSecond2Digit(value):
        secondValue = "2-digit";
        break;
    }
  }

  let timeZoneNameValue = undefined;
  if (Option$isSome(time_zone_name)) {
    const value = Option$Some$0(time_zone_name);
    switch (true) {
      case TimeZoneName$isTimeZoneNameShort(value):
        timeZoneNameValue = "short";
        break;
      case TimeZoneName$isTimeZoneNameLong(value):
        timeZoneNameValue = "long";
        break;
      case TimeZoneName$isTimeZoneNameShortOffset(value):
        timeZoneNameValue = "shortOffset";
        break;
      case TimeZoneName$isTimeZoneNameLongOffset(value):
        timeZoneNameValue = "longOffset";
        break;
      case TimeZoneName$isTimeZoneNameShortGeneric(value):
        timeZoneNameValue = "shortGeneric";
        break;
      case TimeZoneName$isTimeZoneNameLongGeneric(value):
        timeZoneNameValue = "longGeneric";
        break;
    }
  }

  let formatMatcherValue = undefined;
  if (Option$isSome(format_matcher)) {
    const value = Option$Some$0(format_matcher);
    switch (true) {
      case FormatMatcher$isFormatMatcherBestFit(value):
        formatMatcherValue = "best fit";
        break;
      case FormatMatcher$isFormatMatcherBasic(value):
        formatMatcherValue = "basic";
        break;
    }
  }

  const unix = $timestamp.to_unix_seconds_and_nanoseconds(timestamp);
  const seconds = unix[0];
  const nanoseconds = unix[1];
  const date = new Date(seconds * 1000 + Math.trunc(nanoseconds / 1_000_000));
  const localeStr = Option$isSome(locale) ? Option$Some$0(locale) : undefined;
  const timeZoneStr = Option$isSome(timeZone)
    ? Option$Some$0(timeZone)
    : undefined;
  const formatter = new Intl.DateTimeFormat(localeStr, {
    localeMatcher,
    calendar: calendarValue,
    weekday: weekdayValue,
    era: eraValue,
    year: yearValue,
    month: monthValue,
    day: dayValue,
    hour: hourValue,
    minute: minuteValue,
    second: secondValue,
    timeZoneName: timeZoneNameValue,
    formatMatcher: formatMatcherValue,
    hour12: Option$isSome(hour12) ? Option$Some$0(hour12) : undefined,
    timeZone: timeZoneStr,
  });

  return formatter.format(date);
}
