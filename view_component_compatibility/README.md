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

**Status:** Not executed by GitHub connector. The missing native `bigdecimal`
extension in the standard Ruby WASM runtime is already known from the Rails
generator probe. The probe must not be reported as passing before an actual
run. Do not replace production Haml rendering with a mock component or copy
native .so files into the WASM runtime.

## Extraction target

Datawires' `Drafts::ProjectedRowsComponent` composes
`ProjectedFieldComponent`, `ProjectedCommitComponent`, and navigation
components from typed `EditAffordances::Projection` cells. Mobilis should
adapt its service inspector to the same contract, but use Prism-backed
semantic mutation targets rather than Datawires' JSON-document cursor.

The compatibility result gates an actual renderer migration. Do not add
Vue, a Rails server, or a parallel JavaScript semantic model.
