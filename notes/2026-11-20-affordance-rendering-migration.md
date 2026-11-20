# Browser UI migration: Datawires affordances and ViewComponent

## Decision

Keep the static nginx + persistent Ruby WASM architecture. Do not introduce Vue
or a Rails server. Draw on Datawires' actual versioned affordance definitions,
immutable projections, and ViewComponent rendering. No wholesale import of
ActiveRecord or its JSON-document persistence assumptions.

Datawires reference points:
- `EditAffordances::BodyValidator`, `Generated`, `Projection`, `CellBinding`
- `Drafts::ProjectedRowsComponent`, `ProjectedFieldComponent`

Mobilis' authoritative source is Ruby DSL, not JSON. Semantic bindings identify
the target service/property; Prism must re-resolve source locations at mutation
time, rejecting stale or ambiguous targets.

## Current implementation

`ProjectionInvalidator` replaces repeated Turbo DOM region lists in
`Application` with an explicit map of semantic changes to render methods.
It deduplicates renders per transaction, rejects unknown inputs, and never
polls. It does **not** migrate the Haml renderer or establish ViewComponent
compatibility. Local Git, Mermaid, generation, and DOM selection remain intact.

## Mandatory next compatibility gate

Run a real ViewComponent/Action View/Active Support rendering probe inside
the **pinned Ruby 4 WASM runtime**, including escaped attributes, nested
components, and load/render timings. Native Rails success is not enough.
The existing missing-`bigdecimal` generator blocker must not be treated as
solved. Preserve failure evidence rather than shipping a fake stand-in.

Only after that passes should the inspector be migrated to a
renderer-independent affordance projection and actual ViewComponents.
Keep invalid editor source and last-valid visual model behavior.

## Tests

- `bundle exec rspec spec/mobilis/browser/projection_invalidator_spec.rb`
- `bundle exec rspec spec/mobilis/browser/renderer_spec.rb`
- Existing `playground/` Playwright suite after build

Changes authored through GitHub have not been executed in a browser.
