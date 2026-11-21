# Actual ViewComponent 4.5.0 / Ruby WASM compatibility probe

This is the required compatibility gate before replacing Mobilis' working
Haml/Turbo browser interface with Datawires-style ViewComponents.

Unlike a native Rails test, this probe compiles and instantiates the **actual
pinned Ruby 4.0 WASM interpreter** that the browser playground uses. The gem
bundle is isolated, so a failing probe cannot break the deployed playground.

## Run

From the repository root:

```sh
cd playground && npm ci
cd ../view_component_compatibility
bundle install
bin/probe
```

This reuses the generator compatibility manifest builder to locate exact gem
paths and omit host-native extensions. It mounts those pure-Ruby sources into
WASI and invokes real `ViewComponent::Base#render_in` through
`ActionView::Base.empty`. Two ViewComponent subclasses check nested
rendering and correct HTML escaping. Runtime compilation and component render
timings are printed on success. It fails nonzero and preserves the Ruby/JS
exception on any missing dependency or render failure.

**Status: FAILED on the user's actual Ruby WASM runtime (2026-11-20).**
The failure trace reaches `ViewComponent::Base` → `ActionView::Base` →
`ActionView::Helpers::SanitizeHelper` → `rails-html-sanitizer` → `loofah`
→ `nokogiri`. Nokogiri is intentionally omitted by the gem manifest
because its native extension is built for the host machine, not wasm32-wasi.
The probe does **not** establish working ViewComponent compatibility.

This is distinct from the earlier missing `bigdecimal` extension on the
Rails generator path. Adding Nokogiri's Ruby-platform source gem alone
would not help: its C extension still must be compiled for the WASI target
and integrated with the Ruby interpreter. Do not copy native host `.so`
files into WASM or monkeypatch away HTML sanitization.

Next investigate a reproducible WASI-compatible native build of Nokogiri
(and its dependencies), recording cold-start size and performance before
shipping. Keep the existing Haml implementation operational, and proceed
with renderer-independent affordance projections without coupling them to
ViewComponent until this gate genuinely passes.

## Extraction target

Datawires' `Drafts::ProjectedRowsComponent` composes
`ProjectedFieldComponent`, `ProjectedCommitComponent`, and navigation
components from typed `EditAffordances::Projection` cells. Mobilis should
adapt its service inspector to the same contract, but use Prism-backed
semantic mutation targets rather than Datawires' JSON-document cursor.

The compatibility result gates an actual renderer migration. Do not add
Vue, a Rails server, or a parallel JavaScript semantic model.
