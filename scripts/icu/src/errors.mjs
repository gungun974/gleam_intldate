export class BuildError extends Error {
  constructor(message, options = {}) {
    super(message, options);
    this.name = "BuildError";
  }
}

export function invariant(condition, message) {
  if (!condition) throw new BuildError(message);
}
