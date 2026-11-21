# Diesl

A standalone, extractable Ruby DSL authoring core incubated from Mobilis's browser editor.

Diesl is **not** a service generator, a Rails integration, or a second source of truth. It provides conservative Prism-located source edits, optimistic revision checks, and structured undo/redo. The caller owns DSL interpretation, schema, rendering, and persistence.

## Provenance

Initially extracted from `lib/mobilis/browser/source_document.rb` and `source_history.rb` at Mobilis `beware_of_scary_monsters` commit `f59eab458a1f73dd5308ddb49e7333fae2639ef6`.

## Quick start

```ruby
require "diesl"
document = Diesl::Source.new('config "old", enabled: true')
call = document.calls(name: :config).fetch(0)
updated = document.replace_literal(call.arguments.arguments.first, "new", expected_revision: document.revision)
puts updated # config "new", enabled: true
```

`Source#replace_literal` accepts only static literal Prism nodes. Dynamic expressions are never overwritten. Returned source is a new string, not a mutation. Revision mismatches and syntax failures raise explicit errors.

Run `bundle exec rspec diesl/spec` with the parent repository's dependencies or install dependencies from `diesl/Gemfile` and run `bundle exec rspec spec` inside this directory.

## Extraction boundaries

- Generic: Prism parsing, literal discovery, precise byte ranges, Ruby literal serialization, revision-guarded transactions, structured undo/redo.
- Application-owned: DSL root discovery, supported method names and property schema, source evaluation, semantic validation, virtual-file archive codec, Mermaid projection, Turbo/DOM, LightningFS, isomorphic-git and browser runtime.
- Next step: migrate Mobilis SourceDocument to Diesl primitives behind compatibility tests; then extract virtual document and workspace adapters without copying Mobilis-specific filenames or assumptions.

No Ruby version or Rails image changes are part of this work. This directory can be moved verbatim into a new `diesl` repository once repository creation is available.
