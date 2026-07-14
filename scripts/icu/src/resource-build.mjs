import path from "node:path";
import { readdir, readFile } from "node:fs/promises";
import { parseIcuResource } from "./icu-resource.mjs";
import { resourceNodeToPlain } from "./resource-plain.mjs";
import { compileResourceIndex } from "./res-index.mjs";

const FAMILIES = ["locales", "zone", "region"];
const MISC_FILES = [
  "langInfo.txt",
  "metaZones.txt",
  "timezoneTypes.txt",
  "numberingSystems.txt",
  "plurals.txt",
  "dayPeriods.txt",
  "keyTypeData.txt",
  "windowsZones.txt",
  "zoneinfo64.txt",
  "supplementalData.txt",
];

function outputPrefix(family) {
  return family === "locales" ? "" : `${family}/`;
}

async function readFamily(dataDir, family) {
  const dir = path.join(dataDir, family);
  const names = (await readdir(dir))
    .filter(
      (name) =>
        name.endsWith(".txt") &&
        !(family === "zone" && name === "tzdbNames.txt"),
    )
    .sort();
  return Promise.all(
    names.map(async (name) => ({
      name: name.slice(0, -4),
      plain: resourceNodeToPlain(
        parseIcuResource(await readFile(path.join(dir, name), "utf8")),
      ),
    })),
  );
}

export async function buildResourceEntries(
  icuSourceDir,
  { log = () => {} } = {},
) {
  const dataDir = path.join(icuSourceDir, "source", "data");
  const entries = [];

  for (const family of FAMILIES) {
    const bundles = await readFamily(dataDir, family);
    const prefix = outputPrefix(family);
    for (const bundle of bundles)
      entries.push({
        name: `${prefix}${bundle.name}.res`,
        plain: bundle.plain,
      });
    log(`resources ${family}: ${bundles.length}`);
  }

  entries.push({
    name: "res_index.res",
    plain: await compileResourceIndex(icuSourceDir, "locales"),
  });

  const miscDir = path.join(dataDir, "misc");
  for (const name of MISC_FILES) {
    entries.push({
      name: `${name.slice(0, -4)}.res`,
      plain: resourceNodeToPlain(
        parseIcuResource(await readFile(path.join(miscDir, name), "utf8")),
      ),
    });
  }
  log(`misc resources: ${MISC_FILES.length}`);

  log(`resource entries complete: ${entries.length}`);
  return entries;
}
