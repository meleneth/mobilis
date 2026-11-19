# Generator compatibility probes

This isolated bundle pins external generator versions independently from the
Mobilis gem. It is evidence tooling, not a browser-only generator implementation.

## Rails application generator

The probe invokes `Rails::Generators::AppGenerator.start` directly with
railties 8.1.4.1 and the options in `rails_app_options.json`. Native CRuby
generates a 44-file minimal application without the `rails` executable,
Bundler installation, Git, Docker, or post-generation commands.

Run the actual standard Ruby WASM probe with:

```sh
bundle install
bin/probe-rails
```

The probe currently exits nonzero after Rails writes the early application
files. The standard `@ruby/4.0-wasm-wasi` 2.10.1 runtime has no `bigdecimal`
extension, which ActiveSupport loads while Rails generates the master key and
encrypted credentials. Host-native gem variants are intentionally excluded
from the WASM load path; loading their `.so` files would be invalid. The probe
also reuses Mobilis's narrow WASI permission adapter because the Rails generator
sets executable modes and WASI does not implement `chmod`.

Partial output is diagnostic residue only and must never be presented as a
generated Rails application. Mobilis's native Rails writer remains unchanged
and Rails stays authorable/local-only in the browser until this probe completes.

Run the regression cases with:

```sh
cd generator_compatibility
bundle exec rspec spec
```

## Captured generator behavior

`bin/capture-rspec-install` executes the real `rspec-rails` 8.1.0 install
generator through its Rails generator class against a freshly copied minimal
Rails fixture. It records the exact logical invocation, pinned runtime and gem
versions, normalized fixture state, diagnostics, exit status, and sorted file
delta in `captures/rspec-install/`.

The corpus contains both the default invocation and a
`--default-path test/specs` variation. The checked comparison records that the
option relocates both helper files and appends `--default-path` to `.rspec`.
Every run starts from the same fixture digest, and the compatibility specs
reproduce all three JSON records byte-for-structure.

The `Mobilis::GeneratorCompatibility` registry consumes capture evidence only
for exact generator versions and argument lists. The initial `rspec:install`
transformation is intentionally creation-only: it verifies Rails application
prerequisites, refuses conflicting files, treats byte-identical files as an
idempotent no-op, and never interprets a failed capture as executable evidence.
