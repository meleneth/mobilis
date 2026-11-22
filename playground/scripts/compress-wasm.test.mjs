import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { brotliDecompressSync, gunzipSync } from "node:zlib";

const script = fileURLToPath(new URL("./compress-wasm.mjs", import.meta.url));

test("precompressed WASM is lossless, reproducible and leaves the original unchanged", async () => {
  const dir = await mkdtemp(join(tmpdir(), "mobilis-wasm-compression-"));
  try {
    const path = join(dir, "runtime.wasm");
    const original = Buffer.concat([
      Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]),
      Buffer.alloc(100_000, 0x61),
    ]);
    const sha256 = data => createHash("sha256").update(data).digest("hex");
    await writeFile(path, original);
    const run = () => spawnSync(process.execPath, [script, path], { encoding: "utf8" });
    const first = run();
    assert.equal(first.status, 0, first.stderr);
    const br = await readFile(path + ".br");
    const gz = await readFile(path + ".gz");
    assert.deepEqual(brotliDecompressSync(br), original);
    assert.deepEqual(gunzipSync(gz), original);
    assert.equal(sha256(await readFile(path)), sha256(original));
    const second = run();
    assert.equal(second.status, 0, second.stderr);
    assert.deepEqual(await readFile(path + ".br"), br);
    assert.deepEqual(await readFile(path + ".gz"), gz);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("precompression rejects missing or invalid runtime inputs", () => {
  const run = input => spawnSync(process.execPath, [script, input], { encoding: "utf8" });
  assert.notEqual(run("missing.wasm").status, 0);
  assert.notEqual(run("wrong.txt").status, 0);
});
