# Diesl authoring migration (source adapter stage)

This branch does **not** alter the live Mobilis browser. It establishes a
tested domain-adapter boundary before the UI and workspace migration.

- `Mobilis::Browser::DieslSourceDocument` forwards permitted operations to
  the existing `SourceDocument`, with no rewritten Prism algorithms.
- `Diesl::SourceAdapter` enforces source revisions, validates both source
  and transformation output through the *real* Mobilis semantic model, and
  exposes domain analysis.
- `Diesl::AdaptedSession` retains invalid drafts separately, and supplies
  source-aware undo/redo for structured operations.
- `DIESL_EDITOR` declares all Mobilis service types and supported scalar
  fields alongside the workspace: generated artifacts are what Git stages.
  Embedded archive metadata is declared; content editing is delegated to
  Mobilis's proven codec and source edit.
- The `source_document` parity suite checks changes against the unchanged
  original implementation, preserving source comments and archive members.

## Next gate

The next change should make the domain editor projection and its event handlers
consume `DIESL_EDITOR.adapted_session` alongside the existing inspector,
architecture and generation renderer. Add browser tests before removing any
legacy controllers. Array-valued `buckets` properties, source-driven
relationship controls and validated generated-output checkout require explicit
DSL/UI support; none is claimed by this stage.

Run `bundle exec rspec spec/mobilis/browser/diesl_editor_spec.rb` under the
repository's pinned Ruby/Bundler environment. The separate Diesl Gemfile pin
must be updated deliberately when its API changes.
