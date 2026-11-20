# Build Ruby 4 WASI with real BigDecimal and Nokogiri

The CDN/npm Ruby 4.0 WASI runtime used by Mobilis has no `bigdecimal`.
The actual ViewComponent 4.5 compatibility probe fails when Action View's
sanitizer needs the Nokogiri C extension. Both must be compiled for
**wasm32-unknown-wasip1 and linked into CRuby**; host `.so` files are invalid.

This build uses upstream ruby.wasm 2.10.1's `rbwasm build` integration with
Bundler gem extensions, not a fake replacement for BigDecimal, Nokogiri or
HTML sanitization. Dependencies are pinned in the Gemfile. Commit the
resulting Gemfile.lock after the first successful resolution.

## Build and verify

Prerequisites: a working Ruby 4.0 host, Bundler, standard C toolchain, Git,
Node 22, `playground/node_modules` (`cd playground && npm ci`), and
the WASI SDK/build prerequisites required by ruby.wasm. Builds download
Ruby source and native dependencies; the output is **not** checked into git.

```sh
cd native_wasm
bundle install
bin/build build
node probe_extensions.mjs dist/ruby+stdlib.wasm
```

The expected probe verifies actual decimal arithmetic and parses XML with
Nokogiri. Only after this passes should the Rails and ViewComponent probes
be run with the custom interpreter:

```sh
cd generator_compatibility && RUBY_WASM_RUNTIME_PATH=../native_wasm/dist/ruby+stdlib.wasm bin/probe-rails
cd ../view_component_compatibility && RUBY_WASM_RUNTIME_PATH=../native_wasm/dist/ruby+stdlib.wasm bin/probe
```

Both existing probes respect `RUBY_WASM_RUNTIME_PATH`; with it absent,
they continue using the existing pinned npm interpreter. The production
playground is deliberately unchanged. Passing extension tests is not
enough to adopt a new WASM runtime: it must also preserve JS interop,
generation behavior, and browser startup/integrity assumptions.

## Expected failure points and next steps

- BigDecimal on Ruby 4 is a gem extension, not one of ruby.wasm's default
  Ruby 4 static extensions. `rbwasm build` must compile and link it.
- Nokogiri includes C bindings to libxml2, libxslt and vendored libraries.
  These may require further WASI portability patches. Do **not** silently
  skip the extension or substitute a JavaScript parser.
- ruby.wasm's `--save-temps` preserves compiler logs and failed build
  artifacts so failures can be diagnosed and patched narrowly.
- Measure binary size and cold startup versus the existing CDN runtime.
- Make the final browser artifact content-addressed and integrity checked
  before any production cutover.

Status: build and smoke tests have **not** passed or been executed here.
This is an executable attempt with explicit failure gates, not a claim
that the native extensions have been fixed.
