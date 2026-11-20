import fs from "node:fs/promises";
import path from "node:path";
import { WASI } from "node:wasi";
import { RubyVM } from "../playground/node_modules/@ruby/wasm-wasi/dist/esm/vm.js";

const [manifestPath, outputDirectory] = process.argv.slice(2);
if (!manifestPath || !outputDirectory) {
  throw new Error("usage: node probe_view_component_wasm.mjs MANIFEST_JSON OUTPUT_DIRECTORY");
}

const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
const preopens = {
  "/": path.resolve(outputDirectory),
  "/probe": path.resolve(new URL(".", import.meta.url).pathname)
};
const loadPaths = [];
const omitted = new Set(manifest.wasm_omitted.map(gem => gem.name));

for (const gem of manifest.gems) {
  if (omitted.has(gem.name)) continue;
  const guest = `/gem-${gem.name}-${gem.version}`;
  preopens[guest] = gem.path;
  for (const requirePath of gem.require_paths) loadPaths.push(`${guest}/${requirePath}`);
}

const runtimePath = new URL("../playground/node_modules/@ruby/4.0-wasm-wasi/dist/ruby+stdlib.wasm", import.meta.url);
const source = await fs.readFile(runtimePath);
const compilationStarted = performance.now();
const wasmModule = await WebAssembly.compile(source);
const compilationMs = performance.now() - compilationStarted;
const wasi = new WASI({ version: "preview1", returnOnExit: true, preopens });
const instantiateStarted = performance.now();
const { vm } = await RubyVM.instantiateModule({ module: wasmModule, wasip1: wasi });
const instantiationMs = performance.now() - instantiateStarted;

const wasmLoadPaths = loadPaths.map(value => JSON.stringify(value)).join(", ");
try {
  const output = vm.eval(`
    $LOAD_PATH.unshift(${wasmLoadPaths})
    load "/probe/render_probe.rb"
  `).toString();
  const result = JSON.parse(output);
  if (result.nested_html !== '<section><span>&lt;unsafe&gt; &amp; friends</span></section>') {
    throw new Error(`Unexpected nested/escaped ViewComponent output: ${JSON.stringify(result.nested_html)}`);
  }
  console.log(JSON.stringify({
    ...result,
    wasm_bytes: source.length,
    wasm_compilation_ms: compilationMs,
    wasm_instantiation_ms: instantiationMs
  }, null, 2));
} catch (error) {
  console.error(`ViewComponent WASM compatibility probe FAILED:\n${error.stack || String(error)}`);
  process.exitCode = 1;
}
