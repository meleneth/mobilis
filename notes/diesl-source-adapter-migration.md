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
- **Mobilis** retains its service graph semantics, domain-specific constructor
  and relationship rewrites, embedded archive codec, generator, and topology
  projections. Haml/Turbo remains the deliberately small presentation adapter:
  it is not another implementation of source editing or state invalidation.
- **Browser workspace** keeps existing LightningFS persistence and local UI,
  but consumes Carbn's Git/history/rollback primitives and a static policy
  module generated from the authoritative Diesl `workspace do ... end` block.
  The existing IndexedDB namespace is preserved.

The duplicate Mobilis `SourceHistory` and
`MobilisPlayground::ProjectionInvalidator` implementations and their unit
specifications have been removed. Do not delete `SourceDocument` without first
extracting and replacing the Mobilis domain transformations it still owns.

## SourceDocument consolidation

`SourceDocument` now delegates Prism parsing, revision hashes, literal
interpretation, syntax-checked source byte replacement, Unicode-safe line
ranges, direct block-child discovery, nested subtree traversal, and literal
keyword projections to `Diesl::Source`. A pruning affordance avoids traversing
opaque embedded archive calls when collecting source-owned references.
Mobilis still owns its domain-specific service graph declarations, relationship
and service rewrite policies, archive operations, and semantic evaluation.
Regression cases cover multibyte source offsets and the historical nested
relationship-map serialization convention.

The Mobilis `SourceDocument` must not be deleted: the Diesl adapter still calls
its Mobilis-specific transformations. Both builder and inspector forms now
derive fields, collection kinds, and defaults from the Diesl editor block
schema. Removing domain behavior simply to reduce line count is not a goal.

**Workspace boundary (history gap closed):** Carbn now owns the reusable
byte-safe Git checkpoint, authoring working-tree lifecycle, staging and
commits, atomic snapshot publication, multi-phase generated repository history,
and atomic publication/rollback,
Git-object export, and guarded source revision restore.
Mobilis delegates these operations to `/carbn/workspace-history.js`, staged
from the pinned Carbn checkout. A build-time Ruby task generates
`editor-policy.js` from the Diesl workspace block; browser paths, Git author,
branch and generated mirror now come from that one declaration.
Mobilis still owns its workspace UI,
generator-specific validation, compatibility shim, interactive diff, and
browser event wiring. Existing `mobilis-workspace-v1` IndexedDB state, source
paths, and Git history remain unchanged. We do not replace the browser
filesystem name or discard existing commits.

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
