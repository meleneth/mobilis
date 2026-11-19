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
BUNDLE_GEMFILE=generator_compatibility/Gemfile \
  bundle exec rspec generator_compatibility/spec
```
