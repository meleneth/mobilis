# Diesl and Carbn integration (live playground)

The live playground now loads the pinned Diesl and Carbn libraries into its
CRuby/WASM application artifact. The two libraries are fetched at reviewed Git
commits in `Dockerfile.playground`, and the build stages their original pure-Ruby
`lib/` trees. No Rails server or browser-side DSL interpreter is introduced.

## Ownership after migration

- **Diesl** owns the live `AdaptedSession`, authoritative valid source and
  invalid draft buffer, revision checks, structured edits and undo/redo history.
  The Mobilis adapter translates supported domain operations into source edits.
- **Carbn** owns transactional region invalidation. The active editor avoids a
  textarea replacement on raw source input; history button state is updated in
  place. Source focus/selection and DOM lifecycle remain browser-owned.
- **Mobilis** retains its service graph semantics, Prism-located domain-specific
  constructors, relationship rewrites, embedded archive codec, generator and
  topology projections. The Haml renderer is retained until the separate real
  ViewComponent/WASM compatibility gate passes.
- **Browser workspace** still uses the existing LightningFS/isomorphic-git
  implementation. Diesl's workspace schema describes its ownership policy;
  moving the JavaScript workspace implementation is a distinct parity task.

The duplicate Mobilis `SourceHistory` and
`MobilisPlayground::ProjectionInvalidator` implementations and their unit
specifications have been removed. Do not delete `SourceDocument` without first
extracting and replacing the Mobilis domain transformations it still owns.

## SourceDocument consolidation

`SourceDocument` now delegates Prism parsing, revision hashes, literal
interpretation, and syntax-checked source byte replacement to `Diesl::Source`.
Mobilis still owns its domain-specific service graph declarations, relationship
and service rewrite policies, archive operations, and semantic evaluation.
Regression cases cover multibyte source offsets and the historical nested
relationship-map serialization convention.

The legacy `SourceDocument` must not be deleted: the Diesl adapter still calls
its Mobilis-specific transformations. Further reductions should be driven by
parity tests, not by raw line count.

**Workspace boundary:** Diesl's existing browser workspace does not yet
implement Mobilis's complete generation-phase Git history, checkout, and restore
contract. Keep `playground/public/workspace.js` until those capabilities have
feature-for-feature parity and can preserve existing `mobilis-workspace-v1`
IndexedDB state. Do not silently replace the filesystem name or discard commits.

## Verification gates

- `bundle exec rspec spec/mobilis/browser/diesl_editor_spec.rb
  spec/mobilis/browser/source_document_spec.rb`
- `ruby -c playground/app/application.rb`
- `cd playground && npm test` against a successfully built container
- Test source typing, invalid-draft recovery, structured undo/redo, archive
  edits, example loading, Git checkout, builder focus and graph projection.
- Rebuild with `docker compose up --build` to stage the new pinned Ruby libs.

For host builds outside Docker, set `DIESL_LIB_DIR` and `CARBN_LIB_DIR` to
the `lib/` directories of checkouts at the exact pinned SHAs in
`Dockerfile.playground`, then run `playground/scripts/build`.
