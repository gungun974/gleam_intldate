import path from "node:path";
import { mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { SOURCES } from "./config.mjs";
import { downloadSource } from "./download.mjs";
import { extractArchiveFile } from "./archive.mjs";

async function exists(filename) {
  try {
    await stat(filename);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function emptyDir(dirname) {
  await rm(dirname, { recursive: true, force: true });
  await mkdir(dirname, { recursive: true });
}

export async function prepareSources(
  cacheDir,
  { offline = false, clean = false, log = () => {} } = {},
) {
  const downloadDir = path.join(cacheDir, "downloads");
  const sourceDir = path.join(cacheDir, "sources");
  if (clean) await emptyDir(sourceDir);
  else await mkdir(sourceDir, { recursive: true });
  const prepared = {};

  for (const source of SOURCES) {
    const archive = await downloadSource(source, downloadDir, { offline, log });
    const destination = path.join(sourceDir, source.id);
    const marker = path.join(destination, ".source.json");
    let current = null;
    if (await exists(marker))
      current = JSON.parse(await readFile(marker, "utf8"));
    if (current?.sha256 !== source.sha256) {
      log(`extract ${source.id}`);
      await emptyDir(destination);
      const entries = await extractArchiveFile(
        archive,
        source.archive,
        destination,
      );
      await writeFile(
        marker,
        `${JSON.stringify(
          {
            id: source.id,
            version: source.version,
            sha256: source.sha256,
            entries,
          },
          null,
          2,
        )}\n`,
      );
    } else {
      log(`prepared ${source.id}`);
    }
    prepared[source.id] = source.root
      ? path.join(destination, source.root)
      : destination;
  }
  return Object.freeze(prepared);
}
