/**
 * Which path a callback is repointed to.
 *
 * Extracted from `scripts/cutover.ts` so it can be tested: that script calls
 * `main()` at import time, so nothing inside it can be exercised directly.
 *
 * The rule this encodes exists because one `repoint` run moves EVERY active
 * callback. A single bare `--callback-path` applied to two definitions sends
 * both to one route, and a route refuses a token issued for a different
 * definition — which Fluid rescues into a neutral 200. The result is a callback
 * that is registered, answers "successfully", and contributes nothing to the
 * cart.
 */

export type CallbackPaths = {
  /** A single path, valid only when exactly one callback is moving. */
  bare?: string;
  /** definition name -> path the destination app serves it on. */
  byName: Map<string, string>;
};

export class CallbackPathError extends Error {}

export function destinationPathFor(
  name: string,
  paths: CallbackPaths,
  activeCount: number,
): string {
  const mapped = paths.byName.get(name);
  if (mapped) return mapped;

  if (paths.bare) {
    if (activeCount === 1) return paths.bare;
    throw new CallbackPathError(
      `--callback-path was given once, as a bare path, but ${activeCount} callbacks are ` +
        `active. One path cannot serve them all: a route rejects a token issued for a ` +
        `different definition, and Fluid turns that into a neutral 200 rather than an ` +
        `error.\n  Give one pair per definition instead, e.g.\n` +
        `    --callback-path ${name}=/api/callbacks/${name.replace(/_/g, "-")}`,
    );
  }

  throw new CallbackPathError(
    `no --callback-path given for callback "${name}".\n` +
      `    --callback-path ${name}=/api/callbacks/${name.replace(/_/g, "-")}`,
  );
}
