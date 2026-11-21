import { readFile } from "node:fs/promises";
import { RubyVM, consolePrinter } from "@ruby/wasm-wasi";
import { WASI, File, OpenFile, PreopenDirectory } from "@bjorn3/browser_wasi_shim";

const filename = process.argv[2];
if (!filename) throw new Error("usage: node probe-wasm-json.mjs PATH_TO_RUBY_WASM");

const module = await WebAssembly.compile(await readFile(filename));
const wasi = new WASI([], [], [
  new OpenFile(new File([])),
  new OpenFile(new File([])),
  new OpenFile(new File([])),
  new PreopenDirectory("/", []),
], { debug: false });
const printer = consolePrinter();
const { vm } = await RubyVM.instantiateModule({
  module,
  wasip1: wasi,
  addToImports: imports => printer.addToImports(imports),
  setMemory: memory => printer.setMemory(memory),
});

function inspect(source) {
  try {
    const value = vm.eval(source);
    return value?.toString?.() ?? String(value);
  } catch (error) {
    throw new Error("WASM evaluation failed: " + source + "\n" + (error.stack || error), { cause: error });
  }
}

console.log("Ruby:", inspect("RUBY_DESCRIPTION"));
console.log("Preload native JSON State:", inspect('defined?(JSON::Ext::Generator::State) || "undefined"'));
console.log("Preload JSON generator setter:", inspect('defined?(JSON::Ext::Generator::State) && JSON::Ext::Generator::State.respond_to?(:default_sort_keys_proc=)'));
console.log("Preload JSON features:", inspect('$LOADED_FEATURES.grep(/json\\/ext\\/generator/).inspect'));
console.log("Preload native JSON methods:", inspect('defined?(JSON::Ext::Generator::State) ? JSON::Ext::Generator::State.singleton_methods(false).sort.inspect : "undefined"'));

console.log(inspect(`
  require "json"
  raise "Wrong JSON release: #{JSON::VERSION}" unless JSON::VERSION == "3.1.0"
  raise "Missing JSON generator setter" unless JSON::Ext::Generator::State.respond_to?(:default_sort_keys_proc=)
  raise "Invalid JSON parser" unless JSON.parse('{"ok":true}') == {"ok" => true}
  raise "Invalid JSON generator" unless JSON.generate({"ok" => true}) == '{"ok":true}'
  "JSON 3.1.0 native extension smoke test passed"
`));
