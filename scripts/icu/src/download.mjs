import { createHash } from "node:crypto";
import { createReadStream, createWriteStream } from "node:fs";
import { mkdir, readFile, rename, rm, stat } from "node:fs/promises";
import path from "node:path";
import { pipeline } from "node:stream/promises";
import { Readable } from "node:stream";
import { BuildError } from "./errors.mjs";

async function exists(filename) {
  try {
    await stat(filename);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function hashFile(algorithm, filename) {
  const hash = createHash(algorithm);
  await new Promise((resolve, reject) => {
    const input = createReadStream(filename);
    input.on("data", (chunk) => hash.update(chunk));
    input.on("error", reject);
    input.on("end", resolve);
  });
  return hash.digest("hex");
}

async function verify(filename, expectedSha256) {
  if (!expectedSha256) return;
  const actual = await hashFile("sha256", filename);
  if (actual !== expectedSha256) {
    throw new BuildError(
      `Checksum mismatch for ${filename}: expected ${expectedSha256}, got ${actual}`,
    );
  }
}

export async function downloadSource(
  source,
  cacheDir,
  { offline = false, log = () => {} } = {},
) {
  const extension = source.archive === "zip" ? "zip" : "tar.gz";
  const filename = path.join(
    cacheDir,
    `${source.id}-${source.version}.${extension}`,
  );
  await mkdir(cacheDir, { recursive: true });
  if (await exists(filename)) {
    await verify(filename, source.sha256);
    log(`cache ${source.id}`);
    return filename;
  }
  if (offline)
    throw new BuildError(`Missing cached source in offline mode: ${source.id}`);

  log(`download ${source.url}`);
  const response = await fetch(source.url, {
    redirect: "follow",
    signal: AbortSignal.timeout(300_000),
  });
  if (!response.ok || !response.body) {
    throw new BuildError(
      `Download failed (${response.status} ${response.statusText}): ${source.url}`,
    );
  }
  const temporary = `${filename}.part-${process.pid}`;
  await rm(temporary, { force: true });
  try {
    await pipeline(
      Readable.fromWeb(response.body),
      createWriteStream(temporary, { flags: "wx" }),
    );
    await verify(temporary, source.sha256);
    await rename(temporary, filename);
  } catch (error) {
    await rm(temporary, { force: true });
    throw error;
  }
  return filename;
}

export async function readDownloadedSource(source, cacheDir, options) {
  return readFile(await downloadSource(source, cacheDir, options));
}
