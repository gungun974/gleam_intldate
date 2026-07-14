import { BuildError, invariant } from "./errors.mjs";

function decodeEscape(source, index) {
  const character = source[index];
  const simple = { n: "\n", r: "\r", t: "\t", f: "\f", b: "\b" }[character];
  if (simple) return { value: simple, next: index + 1 };
  if (character === "u" || character === "U") {
    const length = character === "u" ? 4 : 8;
    const digits = source.slice(index + 1, index + 1 + length);
    invariant(
      new RegExp(`^[0-9A-Fa-f]{${length}}$`).test(digits),
      `Invalid ICU Unicode escape: \\${character}${digits}`,
    );
    const codePoint = Number.parseInt(digits, 16);
    return {
      value:
        character === "u"
          ? String.fromCharCode(codePoint)
          : String.fromCodePoint(codePoint),
      next: index + 1 + length,
    };
  }
  if (character === "\r" || character === "\n") {
    let next = index + 1;
    if (character === "\r" && source[next] === "\n") next++;
    return { value: "", next };
  }
  return { value: character, next: index + 1 };
}

export function tokenizeIcuResource(input) {
  const source = String(input).replace(/^\uFEFF/, "");
  const result = [];
  let index = 0;
  while (index < source.length) {
    if (/\s/.test(source[index])) {
      index++;
      continue;
    }
    if (source.startsWith("//", index)) {
      const end = source.indexOf("\n", index + 2);
      index = end < 0 ? source.length : end + 1;
      continue;
    }
    if (source.startsWith("/*", index)) {
      const end = source.indexOf("*/", index + 2);
      invariant(end >= 0, "Unterminated ICU resource comment");
      index = end + 2;
      continue;
    }
    const punctuation = "{}:,()";
    if (punctuation.includes(source[index])) {
      result.push({
        type: source[index],
        value: source[index],
        offset: index++,
      });
      continue;
    }
    if (source[index] === '"') {
      const offset = index++;
      let value = "";
      let closed = false;
      while (index < source.length) {
        if (source[index] === '"') {
          index++;
          closed = true;
          break;
        }
        if (source[index] === "\\") {
          const decoded = decodeEscape(source, index + 1);
          value += decoded.value;
          index = decoded.next;
        } else value += source[index++];
      }
      invariant(closed, `Unterminated ICU string at byte ${offset}`);
      result.push({ type: "string", value, offset });
      continue;
    }
    const offset = index;
    while (
      index < source.length &&
      !/\s/.test(source[index]) &&
      !punctuation.includes(source[index]) &&
      source[index] !== '"' &&
      !source.startsWith("//", index) &&
      !source.startsWith("/*", index)
    )
      index++;
    invariant(
      index > offset,
      `Unexpected ICU resource character at byte ${offset}`,
    );
    result.push({
      type: "identifier",
      value: source.slice(offset, index),
      offset,
    });
  }
  result.push({ type: "eof", value: "", offset: source.length });
  return result;
}

export function parseIcuResource(input) {
  const tokens = tokenizeIcuResource(input);
  let index = 0;
  const peek = (type = null) =>
    type ? tokens[index].type === type : tokens[index];
  const take = (type = null) => {
    const token = tokens[index];
    if (type && token.type !== type)
      throw new BuildError(
        `Expected ${type}, got ${token.type} at byte ${token.offset}`,
      );
    index++;
    return token;
  };

  const parseScalarList = (type) => {
    const values = [];
    while (!peek("}")) {
      const token = take(peek("string") ? "string" : "identifier");
      if (
        type === "string" ||
        type === "array" ||
        type === "alias" ||
        type === "process" ||
        type === "bin" ||
        type === "binary"
      ) {
        while (peek("string")) token.value += take("string").value;
      }
      if (type === "int" || type === "intvector") {
        const value = Number(token.value);
        invariant(
          Number.isInteger(value) &&
            value >= -0x80000000 &&
            value <= 0x7fffffff,
          `Invalid ICU integer at byte ${token.offset}: ${token.value}`,
        );
        values.push(value);
      } else values.push(token.value);
      if (peek(",")) take(",");
      else if ((type === "bin" || type === "binary") && peek("identifier"))
        continue;
      else if (!peek("}"))
        throw new BuildError(`Expected ',' or '}' at byte ${peek().offset}`);
    }
    return type === "int" ? values[0] : values;
  };

  const parseEntry = (isRoot = false) => {
    const keyToken = peek("identifier") ? take("identifier") : take("string");
    const key = keyToken.value;
    let type = null;
    let argument = null;
    if (peek(":")) {
      take(":");
      type = take("identifier").value;
      if (peek("(")) {
        take("(");
        argument = take("identifier").value;
        take(")");
      }
    }
    take("{");
    let value;
    if (type == null && peek("}")) {
      type = isRoot ? "table" : "array";
      value = [];
    } else if (
      type === "int" ||
      type === "intvector" ||
      type === "bin" ||
      type === "binary" ||
      type === "alias" ||
      type === "process"
    ) {
      value = parseScalarList(type);
      if (type === "int")
        invariant(value !== undefined, `Empty int resource: ${key}`);
      if (type === "alias" || type === "process")
        value = Array.isArray(value) ? value[0] : value;
      if (type === "bin" || type === "binary") {
        const hex = Array.isArray(value) ? value.join("") : value;
        invariant(
          /^(?:[0-9a-fA-F]{2})*$/.test(hex),
          `Invalid binary resource: ${key}`,
        );
        value = Buffer.from(hex, "hex");
      }
    } else if (type === "array") {
      value = [];
      while (!peek("}")) {
        if (peek("string")) {
          const token = take("string");
          while (peek("string")) token.value += take("string").value;
          value.push(token.value);
        } else if (peek(":")) {
          take(":");
          const subtype = take("identifier").value;
          take("{");
          let childValue;
          if (subtype === "table") {
            childValue = [];
            while (!peek("}")) childValue.push(parseEntry());
          } else if (
            ["int", "intvector", "bin", "binary", "alias"].includes(subtype)
          ) {
            childValue = parseScalarList(subtype);
            if (subtype === "bin" || subtype === "binary")
              childValue = Buffer.from(childValue.join(""), "hex");
          } else
            throw new BuildError(
              `Unsupported anonymous ICU type ${subtype} at byte ${peek().offset}`,
            );
          take("}");
          value.push(
            Object.freeze({
              key: null,
              type: subtype,
              argument: null,
              value: childValue,
            }),
          );
        } else
          throw new BuildError(
            `Invalid ICU array item at byte ${peek().offset}`,
          );
        if (peek(",")) take(",");
      }
    } else if (
      peek("string") &&
      tokens[index + 1]?.type !== "{" &&
      tokens[index + 1]?.type !== ":"
    ) {
      value = [];
      let hadComma = false;
      while (!peek("}")) {
        if (peek("string")) {
          const token = take("string");
          while (peek("string")) token.value += take("string").value;
          value.push(token.value);
        } else if (peek("{")) {
          take("{");
          if (
            (peek("identifier") || peek("string")) &&
            ["{", ":"].includes(tokens[index + 1]?.type)
          ) {
            const entries = [];
            while (!peek("}")) entries.push(parseEntry());
            value.push(
              Object.freeze({
                key: null,
                type: "table",
                argument: null,
                value: entries,
              }),
            );
          } else {
            value.push(parseScalarList("string"));
          }
          take("}");
        } else
          throw new BuildError(
            `Invalid implicit ICU array item at byte ${peek().offset}`,
          );
        if (peek(",")) {
          take(",");
          hadComma = true;
        }
      }
      if (value.length === 1 && typeof value[0] === "string" && !hadComma)
        value = value[0];
      else type ??= "array";
    } else if (peek("{")) {
      value = [];
      while (peek("{")) {
        take("{");
        if (
          (peek("identifier") || peek("string")) &&
          ["{", ":"].includes(tokens[index + 1]?.type)
        ) {
          const entries = [];
          while (!peek("}")) entries.push(parseEntry());
          value.push(
            Object.freeze({
              key: null,
              type: "table",
              argument: null,
              value: entries,
            }),
          );
        } else if (peek("string") || peek("identifier"))
          value.push(parseScalarList("string"));
        else
          throw new BuildError(
            `Unsupported anonymous ICU resource at byte ${peek().offset}`,
          );
        take("}");
        if (peek(",")) take(",");
      }
      type ??= "array";
    } else {
      const entries = [];
      while (!peek("}")) entries.push(parseEntry());
      value = entries;
      type ??= "table";
    }
    take("}");
    return Object.freeze({ key, type: type ?? "string", argument, value });
  };

  const root = parseEntry(true);
  take("eof");
  return root;
}

export function resourceToObject(resource) {
  if (resource.type === "table" || resource.type === null) {
    return Object.fromEntries(
      resource.value.map((child) => [child.key, resourceToObject(child)]),
    );
  }
  if (resource.type === "array") {
    return resource.value.map((child) =>
      child && typeof child === "object" && "type" in child
        ? resourceToObject(child)
        : child,
    );
  }
  return resource.value;
}
