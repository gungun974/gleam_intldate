import path from "node:path";
import { readdir, readFile } from "node:fs/promises";

const EXCLUDED = new Set([
  "ja_JP_TRADITIONAL",
  "th_TH_TRADITIONAL",
  "de_",
  "de__PHONEBOOK",
  "es_",
  "es__TRADITIONAL",
  "root",
]);

function readJsonWithLineComments(source) {
  return JSON.parse(
    source
      .split(/\r?\n/)
      .filter((line) => !line.trimStart().startsWith("//"))
      .join("\n"),
  );
}

export async function compileResourceIndex(icuSourceDir, family) {
  const dir = path.join(icuSourceDir, "source", "data", family);
  const names = (await readdir(dir))
    .filter(
      (name) =>
        name.endsWith(".txt") &&
        !(family === "curr" && name === "supplementalData.txt") &&
        !(family === "zone" && name === "tzdbNames.txt"),
    )
    .sort();
  const dependencies = readJsonWithLineComments(
    await readFile(path.join(dir, "LOCALE_DEPS.json"), "utf8"),
  );
  const aliases = new Set(Object.keys(dependencies.aliases ?? {}));
  const installedLocales = {};
  const aliasLocales = {};
  for (const name of names) {
    const locale = name.slice(0, -4);
    if (EXCLUDED.has(locale)) continue;
    (aliases.has(locale) ? aliasLocales : installedLocales)[locale] = "";
  }
  const plain = {
    InstalledLocales: installedLocales,
    AliasLocales: aliasLocales,
  };
  if (family === "locales") plain.CLDRVersion = dependencies.cldrVersion;
  return plain;
}
