import { inflateRawSync, gunzipSync } from "node:zlib";
import { createGunzip } from "node:zlib";
import { createReadStream } from "node:fs";
import { link, mkdir, readFile, symlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { BuildError, invariant } from "./errors.mjs";

function safeArchivePath(name) {
  const normalized = name.replaceAll("\\", "/");
  if (normalized.startsWith("/") || /^[A-Za-z]:\//.test(normalized)) {
    throw new Error(`Absolute archive path is forbidden: ${name}`);
  }
  const parts = normalized.split("/").filter((part) => part && part !== ".");
  if (parts.includes(".."))
    throw new Error(`Archive path traversal is forbidden: ${name}`);
  return parts.join("/");
}

const ZIP_END_SIGNATURE = 0x06054b50;
const ZIP_CENTRAL_SIGNATURE = 0x02014b50;
const ZIP_LOCAL_SIGNATURE = 0x04034b50;

function findZipEnd(bytes) {
  const minimum = Math.max(0, bytes.length - 0xffff - 22);
  for (let offset = bytes.length - 22; offset >= minimum; offset--) {
    if (bytes.readUInt32LE(offset) === ZIP_END_SIGNATURE) return offset;
  }
  throw new BuildError("ZIP end-of-central-directory record not found");
}

export function readZipEntries(input) {
  const bytes = Buffer.from(input);
  const end = findZipEnd(bytes);
  const disk = bytes.readUInt16LE(end + 4);
  const centralDisk = bytes.readUInt16LE(end + 6);
  invariant(
    disk === 0 && centralDisk === 0,
    "Multi-disk ZIP archives are unsupported",
  );
  const count = bytes.readUInt16LE(end + 10);
  let offset = bytes.readUInt32LE(end + 16);
  const entries = [];

  for (let index = 0; index < count; index++) {
    invariant(
      bytes.readUInt32LE(offset) === ZIP_CENTRAL_SIGNATURE,
      "Invalid ZIP central directory",
    );
    const flags = bytes.readUInt16LE(offset + 8);
    const method = bytes.readUInt16LE(offset + 10);
    const compressedSize = bytes.readUInt32LE(offset + 20);
    const uncompressedSize = bytes.readUInt32LE(offset + 24);
    const nameLength = bytes.readUInt16LE(offset + 28);
    const extraLength = bytes.readUInt16LE(offset + 30);
    const commentLength = bytes.readUInt16LE(offset + 32);
    const externalAttributes = bytes.readUInt32LE(offset + 38);
    const localOffset = bytes.readUInt32LE(offset + 42);
    invariant((flags & 1) === 0, "Encrypted ZIP entries are unsupported");
    invariant(
      compressedSize !== 0xffffffff && uncompressedSize !== 0xffffffff,
      "ZIP64 entries are unsupported",
    );

    const encoding = flags & 0x800 ? "utf8" : "latin1";
    const rawName = bytes.toString(
      encoding,
      offset + 46,
      offset + 46 + nameLength,
    );
    const directory = rawName.endsWith("/");
    const name = safeArchivePath(rawName);
    invariant(
      bytes.readUInt32LE(localOffset) === ZIP_LOCAL_SIGNATURE,
      `Invalid local ZIP entry: ${name}`,
    );
    const localNameLength = bytes.readUInt16LE(localOffset + 26);
    const localExtraLength = bytes.readUInt16LE(localOffset + 28);
    const dataOffset = localOffset + 30 + localNameLength + localExtraLength;
    const compressed = bytes.subarray(dataOffset, dataOffset + compressedSize);
    let data;
    if (method === 0) data = Buffer.from(compressed);
    else if (method === 8) data = inflateRawSync(compressed);
    else
      throw new BuildError(
        `Unsupported ZIP compression method ${method} for ${name}`,
      );
    invariant(
      data.length === uncompressedSize,
      `Invalid uncompressed size for ${name}`,
    );

    const unixMode = externalAttributes >>> 16;
    const kind = unixMode & 0o170000;
    invariant(kind !== 0o120000, `ZIP symbolic links are forbidden: ${name}`);
    entries.push({ name, directory, data });
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function parseTarNumber(bytes, offset, length) {
  const field = bytes.subarray(offset, offset + length);
  if (field[0] & 0x80) {
    let result = BigInt(field[0] & 0x7f);
    for (let index = 1; index < field.length; index++)
      result = (result << 8n) | BigInt(field[index]);
    return Number(result);
  }
  const text = field.toString("ascii").replaceAll("\0", "").trim();
  return text ? Number.parseInt(text, 8) : 0;
}

function tarString(bytes, offset, length) {
  const end = bytes.indexOf(0, offset);
  return bytes.toString(
    "utf8",
    offset,
    end < 0 || end > offset + length ? offset + length : end,
  );
}

export function readTarEntries(input) {
  const bytes = Buffer.from(input);
  const entries = [];
  let offset = 0;
  let longName = null;
  while (offset + 512 <= bytes.length) {
    const header = bytes.subarray(offset, offset + 512);
    if (header.every((byte) => byte === 0)) break;
    const storedChecksum = parseTarNumber(header, 148, 8);
    let checksum = 0;
    for (let index = 0; index < 512; index++) {
      checksum += index >= 148 && index < 156 ? 0x20 : header[index];
    }
    invariant(
      checksum === storedChecksum,
      `Invalid tar header checksum at byte ${offset}`,
    );
    const size = parseTarNumber(header, 124, 12);
    const type = String.fromCharCode(header[156] || 0x30);
    const prefix = tarString(header, 345, 155);
    const shortName = tarString(header, 0, 100);
    let name = longName || (prefix ? `${prefix}/${shortName}` : shortName);
    longName = null;
    const dataStart = offset + 512;
    const dataEnd = dataStart + size;
    invariant(dataEnd <= bytes.length, `Truncated tar entry: ${name}`);
    const data = bytes.subarray(dataStart, dataEnd);

    if (type === "L") {
      longName = data.toString("utf8").replace(/\0+$/, "");
    } else {
      name = safeArchivePath(name);
      invariant(
        type !== "1" && type !== "2",
        `Tar links are forbidden: ${name}`,
      );
      if (type === "0" || type === "\0" || type === "5") {
        entries.push({
          name,
          directory: type === "5" || name.endsWith("/"),
          data: Buffer.from(data),
        });
      }
    }
    offset = dataStart + Math.ceil(size / 512) * 512;
  }
  return entries;
}

export function readArchive(input, type) {
  if (type === "zip") return readZipEntries(input);
  if (type === "tar") return readTarEntries(input);
  if (type === "tar.gz") return readTarEntries(gunzipSync(input));
  throw new BuildError(`Unsupported archive type: ${type}`);
}

export async function extractArchive(input, type, destination) {
  await mkdir(destination, { recursive: true });
  const entries = readArchive(input, type);
  for (const entry of entries) {
    const filename = path.join(destination, entry.name);
    if (entry.directory) await mkdir(filename, { recursive: true });
    else {
      await mkdir(path.dirname(filename), { recursive: true });
      await writeFile(filename, entry.data, { flag: "wx" });
    }
  }
  return entries.length;
}

function chunkReader(readable) {
  const iterator = readable[Symbol.asyncIterator]();
  let buffered = Buffer.alloc(0);
  return async (length) => {
    while (buffered.length < length) {
      const next = await iterator.next();
      if (next.done)
        throw new BuildError(
          `Truncated stream: needed ${length}, got ${buffered.length}`,
        );
      buffered = buffered.length
        ? Buffer.concat([buffered, next.value])
        : Buffer.from(next.value);
    }
    const result = buffered.subarray(0, length);
    buffered = buffered.subarray(length);
    return result;
  };
}

async function extractTarReadable(readable, destination) {
  const take = chunkReader(readable);
  let count = 0;
  let longName = null;
  const links = [];
  while (true) {
    const header = await take(512);
    if (header.every((byte) => byte === 0)) break;
    const storedChecksum = parseTarNumber(header, 148, 8);
    let checksum = 0;
    for (let index = 0; index < 512; index++) {
      checksum += index >= 148 && index < 156 ? 0x20 : header[index];
    }
    invariant(
      checksum === storedChecksum,
      `Invalid tar header checksum at entry ${count}`,
    );
    const size = parseTarNumber(header, 124, 12);
    const padded = Math.ceil(size / 512) * 512;
    const stored = padded ? await take(padded) : Buffer.alloc(0);
    const data = stored.subarray(0, size);
    const type = String.fromCharCode(header[156] || 0x30);
    const prefix = tarString(header, 345, 155);
    const shortName = tarString(header, 0, 100);
    if (type === "L") {
      longName = data.toString("utf8").replace(/\0+$/, "");
      continue;
    }
    const name = safeArchivePath(
      longName || (prefix ? `${prefix}/${shortName}` : shortName),
    );
    longName = null;
    if (type === "1" || type === "2") {
      const rawTarget = tarString(header, 157, 100).replaceAll("\\", "/");
      invariant(
        !rawTarget.startsWith("/"),
        `Absolute tar link is forbidden: ${name} -> ${rawTarget}`,
      );
      const archiveTarget =
        type === "2"
          ? path.posix.normalize(
              path.posix.join(path.posix.dirname(name), rawTarget),
            )
          : path.posix.normalize(rawTarget);
      const target = safeArchivePath(archiveTarget);
      links.push({ name, target, symbolic: type === "2" });
    } else if (type === "5" || name.endsWith("/"))
      await mkdir(path.join(destination, name), { recursive: true });
    else if (type === "0" || type === "\0") {
      const filename = path.join(destination, name);
      await mkdir(path.dirname(filename), { recursive: true });
      await writeFile(filename, data, { flag: "wx" });
    } else {
      continue;
    }
    count++;
  }
  // Links are created last so that no later archive entry can traverse through one.
  for (const item of links) {
    const filename = path.join(destination, item.name);
    const target = path.join(destination, item.target);
    await mkdir(path.dirname(filename), { recursive: true });
    if (item.symbolic) {
      await symlink(path.relative(path.dirname(filename), target), filename);
    } else {
      await link(target, filename);
    }
  }
  return count;
}

export async function extractArchiveFile(filename, type, destination) {
  await mkdir(destination, { recursive: true });
  if (type === "tar.gz") {
    const gunzip = createGunzip();
    createReadStream(filename)
      .on("error", (error) => gunzip.destroy(error))
      .pipe(gunzip);
    return extractTarReadable(gunzip, destination);
  }
  return extractArchive(await readFile(filename), type, destination);
}
