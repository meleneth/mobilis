import fs from "node:fs/promises";
import path from "node:path";
import { WASI } from "node:wasi";
import { RubyVM } from "../playground/node_modules/@ruby/wasm-wasi/dist/esm/vm.js";

const [manifestPath, outputDirectory] = process.argv.slice(2);
if (!manifestPath || !outputDirectory) {
  throw new Error("usage: node probe_rails_wasm.mjs MANIFEST_JSON OUTPUT_DIRECTORY");
}

const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
const options = JSON.parse(await fs.readFile(new URL("./rails_app_options.json", import.meta.url), "utf8"));
await fs.mkdir(outputDirectory, { recursive: true });

const preopens = { "/": path.resolve(outputDirectory) };
preopens["/mobilis-lib"] = path.resolve(new URL("../lib", import.meta.url).pathname);
const loadPaths = ["/mobilis-lib"];
const omitted = new Set(manifest.wasm_omitted.map(entry => entry.name));
for (const gem of manifest.gems) {
  if (omitted.has(gem.name)) continue;
  const guest = `/gem-${gem.name}-${gem.version}`;
  preopens[guest] = gem.path;
  for (const requirePath of gem.require_paths) loadPaths.push(`${guest}/${requirePath}`);
}

const runtimePath = process.env.RUBY_WASM_RUNTIME_PATH
  ? path.resolve(process.env.RUBY_WASM_RUNTIME_PATH)
  : new URL("../playground/node_modules/@ruby/4.0-wasm-wasi/dist/ruby+stdlib.wasm", import.meta.url);
const module = await WebAssembly.compile(await fs.readFile(runtimePath));
const wasi = new WASI({
  version: "preview1",
  returnOnExit: true,
  preopens
});
const { vm } = await RubyVM.instantiateModule({ module, wasip1: wasi });

const rubyLoadPaths = loadPaths.map(value => JSON.stringify(value)).join(", ");
const rubyOptions = options.map(value => JSON.stringify(value)).join(", ");

try {
  const result = vm.eval(`
    $LOAD_PATH.unshift(${rubyLoadPaths})
    require "rubygems"
    require "fileutils"
    require "json"
    require "mobilis/browser/file_system_compatibility"
    require "rails/generators/rails/app/app_generator"
    Mobilis::Browser::FileSystemCompatibility.without_posix_permissions do
      Rails::Generators::AppGenerator.start([${rubyOptions}], destination_root: "/")
    end
    JSON.generate(
      ruby: RUBY_VERSION,
      rails: Rails::VERSION::STRING,
      files: Dir.glob("/probe/**/*", File::FNM_DOTMATCH)
        .select { |entry| File.file?(entry) }
        .map { |entry| entry.delete_prefix("/probe/") }
        .sort
    )
  `);
  console.log(result.toString());
} catch (error) {
  console.error(`Rails WASM probe failed:\n${error.stack || String(error)}`);
  process.exitCode = 1;
}
