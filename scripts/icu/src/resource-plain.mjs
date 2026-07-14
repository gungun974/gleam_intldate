import { BuildError, invariant } from "./errors.mjs";

export function resourceNodeToPlain(node) {
  if (typeof node === "string") return node;
  if (Array.isArray(node)) return node.map(resourceNodeToPlain);
  invariant(node && typeof node === "object", "Invalid ICU resource node");
  switch (node.type) {
    case "table": {
      const out = {};
      for (const child of node.value)
        out[child.key] = resourceNodeToPlain(child);
      return out;
    }
    case "array":
      return node.value.map(resourceNodeToPlain);
    case "alias":
      return { $alias: String(node.value) };
    case "int":
      return node.value;
    case "intvector":
      return { $int_vector: [...node.value] };
    case "bin":
    case "binary":
      return { $binary: Buffer.from(node.value) };
    case "string":
      return node.value;
    default:
      throw new BuildError(`Unsupported ICU resource type: ${node.type}`);
  }
}
