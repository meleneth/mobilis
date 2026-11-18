# Playground runtime and application separation

## Problem

The playground build currently publishes the official ruby.wasm interpreter as
`mobilis.wasm` beside a Base64 JSON filesystem containing Mobilis, the
playground Ruby application, templates, and pure-Ruby gems. The interpreter is
not custom-compiled, but copying and naming it as a Mobilis asset obscures that
separation and makes every application build appear to own a Ruby runtime.

The desired boundary is a pinned, independently distributed interpreter plus a
versioned Mobilis application artifact. Ordinary Ruby changes must only change
the application artifact.

## Current behavior

- `@ruby/4.0-wasm-wasi` and `@ruby/wasm-wasi` are pinned at 2.10.1. The build
  copies the package's unmodified `ruby+stdlib.wasm` (32,555,374 bytes;
  10,082,141 bytes with gzip -9) to `public/mobilis.wasm`.
- `build_filesystem.rb` emits `filesystem.json`, a sorted Base64 JSON object.
  It contains 362 files and 2,020,130 decoded bytes. The JSON is 2,708,578
  bytes (1,388,652 bytes with gzip -9).
- Application contents are `/src/lib`, `/src/playground/app`, templates, and
  the pure-Ruby Haml 6.4.0, Temple 0.10.7, Thor 1.5.0, and Tilt 2.9.0 library
  trees. Prism and the `js` extension are supplied by the official Ruby 4.0
  runtime.
- JavaScript fetches both assets, constructs a writable WASI filesystem,
  instantiates one `RubyVM`, sets load paths, and requires `boot`. The VM and
  Ruby application survive all editor interactions. Ruby has no polling loop.
- Ruby owns semantic state and calls the browser DOM through `js`. Generators
  write to the in-memory WASI filesystem. Browser-only adapters avoid host
  subprocess behavior; Rails and explicit commands remain local-only.

The runtime is therefore already standard. The work is delivery separation,
integrity/version contracts, and diagnostics rather than a CRuby rebuild.

## Verified upstream interface

The official ruby.wasm documentation publishes the versioned
`@ruby/4.0-wasm-wasi` runtime and shows `RubyVM`/`DefaultRubyVM` browser APIs.
The existing `RubyVM.instantiateModule` path is retained because it supports
the playground's custom writable preopened filesystem. The runtime's WASI
platform does not provide process spawning or Ruby threads; native generators
that need those facilities remain unsupported in the browser.

References:

- <https://github.com/ruby/ruby.wasm>
- <https://github.com/ruby/ruby.wasm/blob/main/docs/cheat_sheet.md>
- <https://ruby.github.io/ruby.wasm/npm/%40ruby/wasm-wasi/>

## Proposed change

1. Generate a deterministic uncompressed ustar archive from the existing
   staged application tree. Preserve paths and load-path semantics, reject
   unsafe or unsupported entries, and publish a content-addressed filename.
2. Publish a small manifest containing the application version, archive and
   per-file SHA-256 integrity, compatible runtime package/version, load paths,
   and boot feature. Do not Base64-encode the application.
3. Generate a runtime configuration with a build-time configurable URL and
   integrity value. Production defaults to the official, version-pinned
   jsDelivr runtime. A local URL is an explicit development override, never a
   silent fallback.
4. Fetch and verify the runtime, manifest, archive, and every archive member
   before VM initialization. Hydrate the same writable filesystem and boot the
   same persistent Ruby application.
5. Cache the content-addressed application archive and pinned runtime through
   ordinary HTTP caching. Fetch the small manifest/config without stale-cache
   fallback. No service worker is introduced and offline operation is not
   claimed.
6. Record interpreter fetch/compile, application fetch/verification,
   filesystem hydration, VM instantiation, and Ruby source-loading durations.
   Keep the existing semantic-operation instrumentation.

The main-thread VM remains deliberate for this change. Moving it to a Worker
would require replacing direct Ruby DOM access with a message/render protocol
and duplicating or transferring current editor state. That is disproportionate
to separating artifacts and does not improve quiescence: the current persistent
VM is already idle unless a semantic browser event invokes Ruby.

## Test strategy

- Prove archive ordering, metadata, hashes, path validation, deterministic
  output, and manifest/runtime compatibility checks.
- Boot the packaged application in the actual browser WASM runtime and retain
  the existing end-to-end editor, generation, archive, and quiescence journeys.
- Assert one VM instance across repeated UI operations and visible propagation
  of runtime, compatibility, integrity, and Ruby boot failures.
- Build after an application-only source change and prove that only the
  application artifact changes; the interpreter is neither rebuilt nor part of
  that artifact.
- Capture before/after raw/compressed artifact sizes and cold/warm browser
  initialization timings. Report measurements without inferring gains.

## Open risks

- The CDN must serve the pinned WASM with CORS headers compatible with the
  playground's cross-origin isolation policy.
- Browser Subresource Integrity support for `fetch` and Web Crypto availability
  must be exercised in the supported browser.
- The application archive contains generator assets such as Python wheels.
  They are intentional source inputs and must not be pruned as unused files.
- Native Ruby extensions cannot be added to the application archive. A future
  dependency requiring one must either exist in the pinned runtime or fail the
  compatibility build explicitly.
