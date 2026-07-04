import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";
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

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");

const FIRST_YEAR = 1900;
const LAST_YEAR = 2101;

const chineseDate = new Intl.DateTimeFormat("zh-CN-u-ca-chinese", {
  timeZone: "UTC",
  year: "numeric",
  month: "numeric",
  day: "numeric",
});

const chineseMonths = new Map([
  ["正月", 1],
  ["二月", 2],
  ["三月", 3],
  ["四月", 4],
  ["五月", 5],
  ["六月", 6],
  ["七月", 7],
  ["八月", 8],
  ["九月", 9],
  ["十月", 10],
  ["十一月", 11],
  ["腊月", 12],
]);

function isGregorianLeapYear(year) {
  return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
}

function gregorianToRd(year, month, day) {
  const priorYear = year - 1;
  return (
    365 * priorYear +
    Math.floor(priorYear / 4) -
    Math.floor(priorYear / 100) +
    Math.floor(priorYear / 400) +
    Math.floor((367 * month - 362) / 12) +
    (month <= 2 ? 0 : isGregorianLeapYear(year) ? -1 : -2) +
    day
  );
}

function gregorianFromRd(rd) {
  let year = Math.floor((rd - 1) / 365) + 1;
  while (gregorianToRd(year + 1, 1, 1) <= rd) year += 1;
  while (gregorianToRd(year, 1, 1) > rd) year -= 1;

  const monthLengths = [
    31,
    isGregorianLeapYear(year) ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  let dayOfYear = rd - gregorianToRd(year, 1, 1) + 1;
  let month = 1;
  for (const length of monthLengths) {
    if (dayOfYear <= length) break;
    dayOfYear -= length;
    month += 1;
  }

  return { year, month, day: dayOfYear };
}

function dateFromRd(rd) {
  const { year, month, day } = gregorianFromRd(rd);
  const date = new Date(Date.UTC(year, month - 1, day, 12));
  date.setUTCFullYear(year);
  return date;
}

function chineseParts(rd) {
  const parts = chineseDate.formatToParts(dateFromRd(rd));
  const get = (type) => parts.find((part) => part.type === type)?.value;
  const rawMonth = get("month");
  const day = get("day");
  const relatedYear = get("relatedYear");

  if (!rawMonth || !day || !relatedYear) {
    throw new Error(
      `Intl did not return Chinese date parts for RD ${rd}: ${JSON.stringify(parts)}`,
    );
  }

  const isLeapMonth = rawMonth.startsWith("闰");
  const monthName = isLeapMonth ? rawMonth.slice(1) : rawMonth;
  const month = chineseMonths.get(monthName);
  if (!month) throw new Error(`Unknown Chinese month ${rawMonth} for RD ${rd}`);

  return {
    relatedYear: Number(relatedYear),
    month,
    isLeapMonth,
    day: Number(day),
  };
}

function chineseNewYear(year) {
  for (
    let rd = gregorianToRd(year, 1, 1);
    rd <= gregorianToRd(year, 3, 1);
    rd += 1
  ) {
    const date = chineseParts(rd);
    if (
      date.relatedYear === year &&
      date.month === 1 &&
      !date.isLeapMonth &&
      date.day === 1
    ) {
      return rd;
    }
  }

  throw new Error(`Could not find Chinese New Year ${year}`);
}

function yearEntry(year) {
  const newYear = chineseNewYear(year);
  const nextNewYear = chineseNewYear(year + 1);
  const starts = [];
  const months = [];

  for (let rd = newYear; rd < nextNewYear; rd += 1) {
    const date = chineseParts(rd);
    if (date.day === 1) {
      starts.push(rd);
      months.push(date);
    }
  }

  let lengthBits = 0;
  for (let i = 0; i < starts.length; i += 1) {
    const next = i + 1 < starts.length ? starts[i + 1] : nextNewYear;
    if (next - starts[i] === 30) lengthBits |= 1 << i;
  }

  const leapIndex = months.findIndex((month) => month.isLeapMonth);
  return {
    newYear,
    monthCount: starts.length,
    leapPosition: leapIndex < 0 ? 0 : leapIndex + 1,
    lengthBits,
  };
}

function generateEntries() {
  const entries = [];
  for (let year = FIRST_YEAR; year <= LAST_YEAR; year += 1) {
    const entry = yearEntry(year);
    entries.push([
      entry.newYear,
      entry.monthCount,
      entry.leapPosition,
      entry.lengthBits,
    ]);
  }
  return entries;
}

function generate() {
  const out = packEtf(generateEntries());

  mkdirSync(join(projectRoot, "priv"), { recursive: true });
  writeFileSync(join(projectRoot, "priv", "chinese.etf"), out);
}

generate();
