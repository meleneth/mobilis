import fs from "node:fs/promises";
import path from "node:path";
import { WASI } from "node:wasi";
import { RubyVM } from "../playground/node_modules/@ruby/wasm-wasi/dist/esm/vm.js";

const [runtimePath] = process.argv.slice(2);
if (!runtimePath) throw new Error("usage: node native_wasm/probe_extensions.mjs RUNTIME_WASM");

const bytes = await fs.readFile(runtimePath);
const module = await WebAssembly.compile(bytes);
const wasi = new WASI({
  version: "preview1",
  returnOnExit: true,
  preopens: { "/": path.resolve(process.cwd()) }
});
const { vm } = await RubyVM.instantiateModule({ module, wasip1: wasi });
const result = JSON.parse(vm.eval(`
  require "json"
  require "bigdecimal"
  require "nokogiri"
  # This checks the actual Ruby C extensions, not merely their gem require files.
  decimal = (BigDecimal("0.1") + BigDecimal("0.2")).to_s("F")
  document = Nokogiri::XML("<root><child>value</child></root>")
  JSON.generate(
    decimal: decimal,
    xml: document.at_xpath("/root/child")&.text,
    nokogiri_version: Nokogiri::VERSION
  )
`).toString());

if (result.decimal !== "0.3" || result.xml !== "value") {
  throw new Error(`Native extension smoke test failed: ${JSON.stringify(result)}`);
}
console.log(JSON.stringify({ result, wasm_bytes: bytes.length }, null, 2));
