import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import { mkdirSync, writeFileSync } from "node:fs";
import { deflateSync } from "node:zlib";
import fg from "fast-glob";
import { Packer } from "wetf";

const etfPacker = new Packer({
  encoding: {
    key: "binary",
    string: "binary",
    array: "list",
    undefined: "ignore",
  },
});

function packEtf(value) {
  const raw = etfPacker.pack(value);
  const body = raw.subarray(1);
  const deflated = deflateSync(body);
  const out = new Uint8Array(6 + deflated.length);
  out[0] = 131;
  out[1] = 80;
  out[2] = (body.length >>> 24) & 255;
  out[3] = (body.length >>> 16) & 255;
  out[4] = (body.length >>> 8) & 255;
  out[5] = body.length & 255;
  out.set(deflated, 6);
  return out;
}

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const outputDir = join(projectRoot, "priv", "locale");
const calendarPreferenceData =
  require("cldr-core/supplemental/calendarPreferenceData.json").supplemental
    .calendarPreferenceData;

function unquoteCldr(text) {
  let out = "";
  let inQuote = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === "'") {
      if (text[i + 1] === "'") {
        out += "'";
        i++;
      } else {
        inQuote = !inQuote;
      }
    } else {
      out += c;
    }
  }
  return out;
}

function connectorSeparator(template) {
  const i1 = template.indexOf("{1}");
  const i0 = template.indexOf("{0}");
  if (i1 === -1 || i0 === -1 || i1 > i0) return null;
  if (template.slice(0, i1) !== "" || template.slice(i0 + 3) !== "")
    return null;
  return unquoteCldr(template.slice(i1 + 3, i0));
}

const rawTimeData = require("cldr-core/supplemental/timeData.json");
const metaZones = require("cldr-core/supplemental/metaZones.json");

const { timeData } = rawTimeData.supplemental;
const processedTimeData = Object.keys(timeData).reduce((all, k) => {
  all[k.replace("_", "-")] = timeData[k]._allowed.split(" ");
  return all;
}, {});

function isEqual(a, b) {
  if (a === b) return true;
  if (typeof a !== "object" || typeof b !== "object" || !a || !b) return false;
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => isEqual(a[k], b[k]));
}

export function getAllLocales() {
  return fg
    .sync("*/ca-gregorian.json", {
      cwd: resolve(
        dirname(require.resolve("cldr-dates-full/package.json")),
        "./main",
      ),
    })
    .map(dirname)
    .filter((l) => {
      try {
        return Intl.getCanonicalLocales(l).length;
      } catch {
        console.warn(`Invalid locale ${l}`);
        return false;
      }
    });
}

function resolveDateTimeSymbolTable(token) {
  switch (token) {
    case "h":
      return "h12";
    case "H":
      return "h23";
    case "K":
      return "h11";
    case "k":
      return "h24";
  }
  return "";
}

function filterKeys(data, filterFn) {
  return Object.keys(data)
    .filter(filterFn)
    .reduce((all, k) => {
      all[k] = data[k];
      return all;
    }, {});
}

function hasAltVariant(k) {
  return !k.endsWith("alt-variant");
}

function extractTimezoneToMetazoneMap() {
  const map = {};
  const metazoneInfo = metaZones.supplemental.metaZones.metazoneInfo.timezone;

  for (const continent of Object.keys(metazoneInfo)) {
    const zones = metazoneInfo[continent];
    if (typeof zones !== "object" || zones === null) continue;

    for (const zone of Object.keys(zones)) {
      const fullZoneName = `${continent}/${zone}`;
      const zoneData = zones[zone];

      if (Array.isArray(zoneData) && zoneData.length > 0) {
        const latestMapping = zoneData[zoneData.length - 1];
        if (latestMapping?.usesMetazone?._mzone) {
          map[fullZoneName] = latestMapping.usesMetazone._mzone;
        }
      }
    }
  }

  return map;
}

const tzToMetaZoneMap = extractTimezoneToMetazoneMap();

const CALENDAR_SOURCES = [
  ["buddhist", "buddhist", "buddhist"],
  ["chinese", "chinese", "chinese"],
  ["coptic", "coptic", "coptic"],
  ["dangi", "dangi", "dangi"],
  ["ethiopic", "ethiopic", "ethiopic"],
  ["ethioaa", "ethiopic", "ethiopic"],
  ["hebrew", "hebrew", "hebrew"],
  ["indian", "indian", "indian"],
  ["islamic", "islamic", "islamic"],
  ["japanese", "japanese", "japanese"],
  ["persian", "persian", "persian"],
  ["roc", "roc", "roc"],
];

const SUPPORTED_CALENDARS = new Set([
  "buddhist",
  "chinese",
  "coptic",
  "dangi",
  "ethioaa",
  "ethiopic",
  "gregory",
  "hebrew",
  "indian",
  "islamic",
  "japanese",
  "persian",
  "roc",
]);

function normalizeCalendar(calendar) {
  return calendar === "gregorian" ? "gregory" : calendar;
}

function defaultCalendarForRegion(region) {
  const preferences =
    calendarPreferenceData[region || ""] || calendarPreferenceData["001"] || [];

  for (const calendar of preferences) {
    const normalized = normalizeCalendar(calendar);
    if (SUPPORTED_CALENDARS.has(normalized)) {
      return normalized;
    }
  }

  return "gregory";
}

function dfVal(v) {
  return v && typeof v === "object" ? v._value : v;
}

function localeChain(locale) {
  const parts = locale.split("-");
  const chain = [];
  for (let i = parts.length; i >= 1; i--) {
    chain.push(parts.slice(0, i).join("-"));
  }
  chain.push("root");
  return chain;
}

function loadCalendar(pkg, cldrName, locale) {
  for (const l of localeChain(locale)) {
    let file;
    try {
      file = require(`cldr-cal-${pkg}-full/main/${l}/ca-${pkg}.json`);
    } catch {
      continue;
    }
    const cal = file.main[l] && file.main[l].dates.calendars[cldrName];
    if (cal) return cal;
  }
  return null;
}

function monthList(node) {
  return Object.keys(node)
    .filter((k) => /^\d+$/.test(k))
    .sort((a, b) => Number(a) - Number(b))
    .map((k) => node[k]);
}

function monthFieldsFrom(cal) {
  const m = cal.months.format;
  return {
    narrow: monthList(m.narrow),
    short: monthList(m.abbreviated),
    long: monthList(m.wide),
  };
}

function monthStandaloneFrom(cal) {
  const sa = cal.months["stand-alone"];
  if (!sa) return null;
  const fmt = cal.months.format;
  if (
    isEqual(sa.narrow, fmt.narrow) &&
    isEqual(sa.abbreviated, fmt.abbreviated) &&
    isEqual(sa.wide, fmt.wide)
  ) {
    return null;
  }
  return {
    narrow: monthList(sa.narrow),
    short: monthList(sa.abbreviated),
    long: monthList(sa.wide),
  };
}

function eraFieldsFrom(cal) {
  const e = cal.eras || {};
  const conv = (o) => {
    const r = {};
    if (o) for (const k of Object.keys(o)) r[k] = o[k];
    return r;
  };
  return {
    narrow: conv(e.eraNarrow),
    short: conv(e.eraAbbr),
    long: conv(e.eraNames),
  };
}

function cyclicFrom(cal) {
  const c = cal.cyclicNameSets;
  if (!c || !c.years) return null;
  const node = c.years.format.abbreviated;
  const r = {};
  for (const k of Object.keys(node)) r[k] = node[k];
  return r;
}

function leapFrom(cal) {
  const mp = cal.monthPatterns;
  const leap = mp && mp.format && mp.format.wide && mp.format.wide.leap;
  return leap || null;
}

function calendarDataFrom(key, cal) {
  const monthStandalone = monthStandaloneFrom(cal);
  const yearNames = cyclicFrom(cal);
  const leapMonth = leapFrom(cal);
  return {
    month: monthFieldsFrom(cal),
    ...(monthStandalone ? { monthStandalone } : {}),
    era: eraFieldsFrom(cal),
    ...(yearNames ? { yearNames } : {}),
    ...(leapMonth ? { leapMonth } : {}),
  };
}

function buildCalendarFormats(cal) {
  const standard = cal.dateTimeFormats;
  const atTime = (cal["dateTimeFormats-atTime"] || {}).standard || {};
  const full = atTime.full ?? standard.full;
  const long = atTime.long ?? standard.long;
  const medium = atTime.medium ?? standard.medium;
  const short = atTime.short ?? standard.short;

  const connectorFull = connectorSeparator(full);
  const connectorLong = connectorSeparator(long);
  const connectorMedium = connectorSeparator(medium);
  const connectorShort = connectorSeparator(short);
  const canUseMarker =
    connectorFull !== null &&
    connectorLong !== null &&
    connectorMedium !== null &&
    connectorShort !== null;
  const dateTimeConnectors = {
    full: canUseMarker ? connectorFull : ", ",
    long: canUseMarker ? connectorLong : ", ",
    medium: canUseMarker ? connectorMedium : ", ",
    short: canUseMarker ? connectorShort : ", ",
  };

  const { availableFormats } = cal.dateTimeFormats;
  let rawIntervalFormats = cal.dateTimeFormats.intervalFormats || {};
  const intervalFormats = Object.keys(rawIntervalFormats)
    .filter(hasAltVariant)
    .reduce((all, k) => {
      const v = rawIntervalFormats[k];
      all[k] = typeof v === "string" ? v : filterKeys(v, hasAltVariant);
      return all;
    }, {});
  const available = Object.keys(availableFormats)
    .filter(hasAltVariant)
    .reduce((all, skeleton) => {
      all[skeleton] = availableFormats[skeleton];
      return all;
    }, {});
  const dateFormats = Object.values(cal.dateFormats).reduce((all, v) => {
    const p = dfVal(v);
    all[p] = p;
    return all;
  }, {});
  const timeFormats = Object.values(cal.timeFormats).reduce((all, v) => {
    const p = dfVal(v);
    all[p] = p;
    return all;
  }, {});
  const baseFormats = {
    available,
    date: dateFormats,
    time: timeFormats,
    full,
    long,
    medium,
    short,
    marker: canUseMarker,
  };
  return { baseFormats, intervalFormats, dateTimeConnectors };
}

export function loadDatesFields(locale) {
  const caGregorian = require(
    `cldr-dates-full/main/${locale}/ca-gregorian.json`,
  );
  const timeZoneNamesFile = require(
    `cldr-dates-full/main/${locale}/timeZoneNames.json`,
  );
  let numbersFile;
  try {
    numbersFile = require(`cldr-numbers-full/main/${locale}/numbers.json`);
  } catch {
    numbersFile = undefined;
  }

  const gregorian = caGregorian.main[locale].dates.calendars.gregorian;
  const timeZoneNames = timeZoneNamesFile.main[locale].dates.timeZoneNames;
  const numbers = numbersFile?.main[locale].numbers;
  const nu = numbers
    ? numbers.defaultNumberingSystem === "latn"
      ? ["latn"]
      : [numbers.defaultNumberingSystem, "latn"]
    : [];

  let hc = [];
  let region;
  try {
    if (locale !== "root") {
      region = new Intl.Locale(locale).maximize().region;
    }
    hc = (
      processedTimeData[locale] ||
      processedTimeData[region || ""] ||
      processedTimeData[`${locale}-001`] ||
      processedTimeData["001"]
    ).map(resolveDateTimeSymbolTable);
    if (!hc.includes("h23") && !hc.includes("h24")) {
      hc.push("h23");
    }
    if (!hc.includes("h12") && !hc.includes("h11")) {
      hc.push("h12");
    }
  } catch (e) {
    console.error(`Issue extracting hourCycle for ${locale}`);
    throw e;
  }
  let timeZoneName = {};
  try {
    timeZoneName = !timeZoneNames.metazone
      ? {}
      : Object.keys(tzToMetaZoneMap).reduce((all, tz) => {
          const metazone = tzToMetaZoneMap[tz];
          const metazoneInfo = timeZoneNames.metazone[metazone];
          if (metazoneInfo) {
            all[tz] = {};
            if (metazoneInfo.long) {
              all[tz].long = [
                metazoneInfo.long.standard,
                "daylight" in metazoneInfo.long
                  ? metazoneInfo.long.daylight
                  : metazoneInfo.long.standard,
              ];
              if ("generic" in metazoneInfo.long) {
                all[tz].long.push(metazoneInfo.long.generic);
              }
            }
            if ("short" in metazoneInfo) {
              const standard = metazoneInfo.short.standard;
              const daylight =
                "daylight" in metazoneInfo.short
                  ? metazoneInfo.short.daylight
                  : standard;
              const generic = metazoneInfo.short.generic;

              const values = [standard, daylight];
              if (generic != null) values.push(generic);

              if (values.every((v) => v != null)) {
                all[tz].short = values;
              }
            }
          }

          return all;
        }, {});
    const { long: utcLong, short: utcShort } = timeZoneNames.zone.Etc.UTC;
    timeZoneName.UTC = {};
    if (utcLong) {
      timeZoneName.UTC.long = [utcLong.standard, utcLong.standard];
    }
    if (utcShort) {
      timeZoneName.UTC.short = [utcShort.standard, utcShort.standard];
    }
  } catch (e) {
    console.error(`Issue extracting timeZoneName for ${locale}`);
    throw e;
  }

  const gregorianFormats = buildCalendarFormats(gregorian);

  const calendars = {
    gregory: calendarDataFrom("gregory", gregorian),
  };
  const extraFormats = {};
  for (const [key, pkg, cldrName] of CALENDAR_SOURCES) {
    const calObj = loadCalendar(pkg, cldrName, locale);
    if (!calObj) continue;
    const built = buildCalendarFormats(calObj);
    extraFormats[key] = built.baseFormats;
    calendars[key] = calendarDataFrom(key, calObj);
  }

  return {
    am: gregorian.dayPeriods.format.wide.am,
    pm: gregorian.dayPeriods.format.wide.pm,
    weekday: {
      narrow: Object.values(gregorian.days.format.narrow),
      short: Object.values(gregorian.days.format.abbreviated),
      long: Object.values(gregorian.days.format.wide),
    },
    timeZoneName,
    gmtFormat: timeZoneNames.gmtFormat,
    hourFormat: timeZoneNames.hourFormat,
    dateTimeConnectors: gregorianFormats.dateTimeConnectors,
    formats: {
      gregory: gregorianFormats.baseFormats,
      ...extraFormats,
    },
    calendars,
    intervalFormats: gregorianFormats.intervalFormats,
    hourCycle: hc[0],
    defaultCalendar: defaultCalendarForRegion(region),
    nu,
  };
}

const UNSET_MARKER = "$unset";

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepDiff(child, parent) {
  const out = {};
  const unset = [];
  for (const k of Object.keys(parent)) {
    if (!(k in child)) unset.push(k);
  }
  for (const k of Object.keys(child)) {
    const cv = child[k];
    if (!(k in parent)) {
      out[k] = cv;
      continue;
    }
    const pv = parent[k];
    if (isEqual(cv, pv)) continue;
    if (isPlainObject(cv) && isPlainObject(pv)) {
      out[k] = deepDiff(cv, pv);
    } else {
      out[k] = cv;
    }
  }
  if (unset.length) out[UNSET_MARKER] = unset;
  return out;
}

function deepMerge(base, override) {
  if (isPlainObject(base) && isPlainObject(override)) {
    const out = { ...base };
    for (const k of Object.keys(override)) {
      if (k === UNSET_MARKER) continue;
      out[k] = k in base ? deepMerge(base[k], override[k]) : override[k];
    }
    for (const k of override[UNSET_MARKER] || []) {
      delete out[k];
    }
    return out;
  }
  return override;
}

function findParent(locale, localeSet) {
  for (const candidate of localeChain(locale).slice(1)) {
    if (candidate !== locale && localeSet.has(candidate)) {
      return candidate;
    }
  }
  return null;
}

function main() {
  let locales = getAllLocales();
  if (process.env.LOCALES) {
    const only = new Set(process.env.LOCALES.split(","));
    locales = locales.filter((l) => only.has(l));
  }
  mkdirSync(outputDir, { recursive: true });

  const localeSet = new Set(locales);
  const fullByLocale = new Map();
  for (const locale of locales) {
    fullByLocale.set(locale, loadDatesFields(locale));
  }

  let count = 0;
  let extended = 0;
  for (const locale of locales) {
    const full = fullByLocale.get(locale);
    const parent = findParent(locale, localeSet);

    let output = full;
    if (parent) {
      const parentFull = fullByLocale.get(parent);
      const diff = deepDiff(full, parentFull);
      if (isEqual(deepMerge(parentFull, diff), full)) {
        output = { extend: parent, ...diff };
        extended++;
      }
    }

    const file = join(outputDir, `${locale}.etf`);
    writeFileSync(file, packEtf(output));
    count++;
  }
  console.log(
    `Done: ${count} locales generated into ${outputDir} (${extended} extend a parent)`,
  );
}

if (
  process.argv[1] &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1])
) {
  main();
}
