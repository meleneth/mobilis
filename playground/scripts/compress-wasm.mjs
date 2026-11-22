#!/usr/bin/env node
// Produce deterministic, verified, precompressed copies of a WASM runtime.
// Runs in its own Docker stage so application edits do not recompress Ruby.
import { createReadStream, createWriteStream } from "node:fs";
import { stat, rename, rm } from "node:fs/promises";
import { createHash } from "node:crypto";
import {
  constants,
  createBrotliCompress,
  createBrotliDecompress,
  createGzip,
  createGunzip,
} from "node:zlib";
import { pipeline } from "node:stream/promises";

const source = process.argv[2];
if (!source || !source.endsWith(".wasm")) {
  throw new Error("usage: node compress-wasm.mjs PATH_TO_RUNTIME.wasm");
}

async function digest(path, transform) {
  const hash = createHash("sha256");
  const sourceStream = createReadStream(path);
  if (transform) {
    const { Writable } = await import("node:stream");
    await pipeline(sourceStream, transform(), new Writable({
      write(chunk, _encoding, callback) {
        hash.update(chunk);
        callback();
      },
    }));
  } else {
    for await (const chunk of sourceStream) hash.update(chunk);
  }
  return hash.digest("hex");
}

const original = await stat(source);
if (!original.isFile() || original.size === 0) throw new Error("Empty WASM runtime");
const expected = await digest(source);
const encodings = [
  ["br", () => createBrotliCompress({
    params: {
      [constants.BROTLI_PARAM_QUALITY]: 11,
      [constants.BROTLI_PARAM_MODE]: constants.BROTLI_MODE_GENERIC,
    },
  }), () => createBrotliDecompress()],
  ["gz", () => createGzip({ level: 9, mtime: 0 }), () => createGunzip()],
];

for (const [suffix, encoder, decoder] of encodings) {
  const output = source + "." + suffix;
  const temporary = output + ".tmp";
  try {
    await pipeline(createReadStream(source), encoder(), createWriteStream(temporary));
    if (await digest(temporary, decoder) !== expected) {
      throw new Error("Compressed WASM does not round-trip: " + suffix);
    }
    await rename(temporary, output);
  } finally {
    await rm(temporary, { force: true });
  }
  const bytes = (await stat(output)).size;
  console.log(suffix + ": " + bytes + " bytes (" +
    (100 * bytes / original.size).toFixed(1) + "% of raw)");
}
