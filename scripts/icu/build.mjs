#!/usr/bin/env node

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";
import { Packer } from "wetf";
import { prepareSources } from "./src/sources.mjs";
import { buildResourceEntries } from "./src/resource-build.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "../..");
const outputDir = join(projectRoot, "priv", "icudata");
const cacheDir = join(__dirname, ".cache");

const FIXED_ITEMS = [
  "res_index.res",
  "langInfo.res",
  "metaZones.res",
  "timezoneTypes.res",
  "numberingSystems.res",
  "plurals.res",
  "dayPeriods.res",
  "keyTypeData.res",
  "zoneinfo64.res",
  "supplementalData.res",
];

const BUNDLE_SECTIONS = new Map([
  [
    "supplementalData.res",
    new Set([
      "calendarData",
      "calendarPreferenceData",
      "timeData",
      "weekData",
      "weekData%variant",
      "cldrVersion",
    ]),
  ],
  ["timezoneTypes.res", new Set(["typeMap"])],
]);

const LOCALE_BUNDLE_SECTIONS = new Set([
  "NumberElements",
  "calendar",
  "fields",
]);

function focusBundle(itemName, plain, category) {
  const keep =
    category === "locale"
      ? LOCALE_BUNDLE_SECTIONS
      : BUNDLE_SECTIONS.get(itemName);
  if (!keep) return plain;
  invariantIsTable(itemName, plain);
  const focused = {};
  for (const [key, value] of Object.entries(plain)) {
    if (keep.has(key) || key.startsWith("%")) focused[key] = value;
  }
  return focused;
}

function invariantIsTable(itemName, plain) {
  if (!plain || typeof plain !== "object" || Array.isArray(plain)) {
    throw new Error(`Cannot focus ${itemName}: expected a table at the root`);
  }
}

const etfPacker = new Packer({
  encoding: {
    key: "binary",
    string: "binary",
    array: "list",
    undefined: "ignore",
    buffer: "binary",
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

function localeNameFilter(locales) {
  if (!locales) return null;
  return new Set(locales.split(","));
}

async function main() {
  const onlyLocales = localeNameFilter(process.env.LOCALES);
  const offline = process.env.ICU_OFFLINE === "1";
  const log = (message) => process.stdout.write(`${message}\n`);

  const sources = await prepareSources(cacheDir, { offline, log });
  const entries = await buildResourceEntries(join(sources.icu, "icu4c"), {
    log,
  });

  const items = new Map(entries.map((entry) => [entry.name, entry.plain]));

  const allItems = [...items.keys()];
  const isLocaleRes = (n) => n.endsWith(".res") && !FIXED_ITEMS.includes(n);
  const rootLocaleItems = allItems.filter(
    (n) => !n.includes("/") && isLocaleRes(n),
  );
  const zoneItems = allItems.filter(
    (n) => n.startsWith("zone/") && isLocaleRes(n),
  );
  const regionItems = allItems.filter(
    (n) => n.startsWith("region/") && isLocaleRes(n),
  );

  const wantedLocaleBase = (fileName) => fileName.replace(/\.res$/, "");

  const selectedRoot = onlyLocales
    ? rootLocaleItems.filter((n) => onlyLocales.has(wantedLocaleBase(n)))
    : rootLocaleItems;
  const selectedZone = onlyLocales
    ? zoneItems.filter((n) =>
        onlyLocales.has(wantedLocaleBase(n.slice("zone/".length))),
      )
    : zoneItems;
  const selectedRegion = onlyLocales
    ? regionItems.filter((n) =>
        onlyLocales.has(wantedLocaleBase(n.slice("region/".length))),
      )
    : regionItems;

  mkdirSync(outputDir, { recursive: true });

  let count = 0;

  function convertOne(itemName, category) {
    const plain = items.get(itemName);
    if (!plain) return;
    const relPath = itemName.replace(/\.res$/, "");
    const outPath = join(outputDir, `${relPath}.etf`);
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, packEtf(focusBundle(itemName, plain, category)));
    count++;
  }

  for (const name of FIXED_ITEMS) convertOne(name, "fixed");
  for (const name of selectedRoot) convertOne(name, "locale");
  for (const name of selectedZone) convertOne(name, "zone");
  for (const name of selectedRegion) convertOne(name, "region");
  if (onlyLocales) convertOne("root.res", "locale");

  process.stdout.write(`Done: ${count} bundles generated into ${outputDir}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack : error}\n`);
  process.exitCode = 1;
});
