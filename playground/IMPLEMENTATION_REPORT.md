# Implementation report

> Runtime packaging update (2026-11-20): the CDN measurements in this report
> remain the verified baseline. Rails/Nokogiri work introduced a separately
> built custom Ruby/native-extension artifact image. Normal playground builds
> consume that image and do not compile Ruby; performance for the finished
> custom runtime must be remeasured once its intentionally infrequent build is
> completed.

## Works

- Static nginx-hosted CRuby/WASM application with Ruby-owned state and events.
- Haml components updated through Turbo Streams.
- Visual creation/removal, service type/name edits, literal property controls,
  and connection declarations for every DSL service type.
- Prism-based source analysis and surgical transformations.
- Last-valid-model recovery from syntax and evaluation errors.
- Exact Ruby DSL, serialized system JSON, and local-instructions export.
- Capability-based, all-or-nothing browser generation using real Mobilis
  realized nodes, plugins, writers, compose emitters, and filesystem output.
- Generated file tree, read-only contents, per-file download, and ZIP export.
- Live Mermaid architecture derived from the validated `Mobilis::System`, with
  explicit dependencies, reference relationships, stale-state recovery, and
  source/builder navigation.
- A synchronized full service inspector with complete validated configuration,
  safe literal property controls, connection role/target editing, incoming
  relationship inspection, and distinct operational dependency presentation.
- Deterministic versioned Base64/ustar embedded bundles, shared by native Ruby
  and WASM, with integrity checks, safe paths, normalized metadata, binary file
  preservation, and size limits.
- Browser-only virtual document navigation and staging, atomic revision-checked
  archive commits into one Prism-located payload, discard, and undo/redo.
- Semantic runtime call/duration instrumentation. Selection, scrolling, graph
  navigation, archive browsing, and document typing leave the Ruby VM idle.
- Independent delivery of the official `@ruby/4.0-wasm-wasi` 2.10.1 runtime
  and a deterministic, content-addressed Mobilis Ruby application archive.
  Runtime, archive, and per-file integrity are verified before one persistent
  VM boots through ordinary Ruby load paths and `require`.

## Verified

The Ruby suite passes 355 examples (2 pre-existing pending examples). It covers
source/model round trips, byte identity, comments, unrelated source, invalid
input, dynamic expressions, Rails authoring, capabilities, Haml, Turbo Stream
markup, authoring export, stable real PostgreSQL generation, and a native parity
fixture. Ten Playwright journeys pass in system Chrome, covering runtime and
DOM/Turbo initialization, visual/source editing, invalid-source recovery, exact
native/WASM PostgreSQL output parity, generation, file navigation, DSL download,
and project ZIP structure, inspector relationship edits, archive
save/reopen/undo/conflict behavior, and Ruby quiescence during nonsemantic UI
interaction.

The production container packages only nginx and static assets; there is no
runtime Ruby process or generation endpoint. See the repository handoff for
the clean Docker build result.

Mermaid 12.3 is pinned and rendered through its public `initialize`/`render`
API. Its supported Node 22.12 runtime is isolated to the Debian build stage;
the production dependency audit reports no vulnerabilities, and Node is not
present in the nginx runtime image.

The production browser check loaded the version-pinned jsDelivr runtime through
the deployed nginx CSP/COEP policy, verified the application archive, booted
one VM, performed visual and direct-source edits, and retained that VM. The
production container contains the application archive and manifests but no
Ruby interpreter file or process.

## Artifact and performance measurements

The “existing” browser was reconstructed from the pre-refactor boot code with
the same 362 current application files. Both sides were served locally through
WEBrick and measured once in the same system Chrome using
`scripts/measure_browser.mjs`; local transfer sizes are uncompressed. Gzip
figures use deterministic `gzip -9 -n` and show artifact payloads only.

| Metric | Existing Base64 filesystem | Decoupled application |
|---|---:|---:|
| Interpreter raw | 32,555,374 B | 32,555,374 B |
| Application raw | 2,709,494 B | 2,354,548 B (tar + manifest + config) |
| Interpreter gzip | 10,082,128 B | 10,082,128 B |
| Application gzip | 1,388,839 B | 1,275,410 B |
| Total gzip | 11,470,967 B | 11,357,538 B |
| Cold first usable, local | 1,635.0 ms | 1,642.2 ms |
| Warm first usable, local | 820.2 ms | 840.1 ms |
| Visual add-service latency | 67.7 ms | 53.5 ms |
| Full source validation latency | 151.7 ms | 333.1 ms |
| Observed JS heap after edits | 24.9 MB | 65.3 MB |

These are single-run engineering observations, not statistically significant
benchmarks. In particular, Chrome's `performance.memory` is GC-state-sensitive,
and the validation measurements varied enough that no regression conclusion is
drawn. The meaningful result is near-identical local startup with a 113,429-byte
smaller gzip application payload and no interpreter rebuild/hosting coupling.

Against the actual production nginx/CDN path, the measured cold first-usable
time was 3,427.4 ms and warm was 2,526.3 ms on the test network. The CDN
transferred 8,015,748 compressed bytes for Ruby and nginx transferred 1,318,617
compressed bytes for the application tar. The warm runtime timing reported
25.8 ms compilation, 9.2 ms application unpack/verification, 1.6 ms filesystem
hydration, 146.2 ms VM instantiation, and 505.2 ms Ruby application loading.
CDN transfer time, rather than interpreter compilation, dominated that run.

## Limitations

- Rails and explicit host-command generation require local execution.
- The visual form maps direct service calls and selected literal properties.
  The inspector exposes complete evaluated configuration, but service-specific
  block APIs and arbitrary metaprogramming remain source-only and are preserved.
- Syntax highlighting is limited to readable monospaced source/output; no
  JavaScript editor framework is included.
- Generation remains synchronous in the main VM pending evidence that a worker
  protocol is needed.
- The CDN timing above is the verified baseline, not a measurement of the new
  custom runtime. The containerized path serves its pinned runtime from nginx;
  no service worker or silent stale-version fallback exists.
- Native extensions cannot be delivered in the application tar. They must be
  pinned in the separate runtime bundle; ordinary Mobilis source changes do
  not rebuild that interpreter/native-extension image.
- Embedded archive editing supports regular text members. Binary members are
  byte-preserved but intentionally read-only, and archive entrypoint/dependency
  metadata is currently authored through the codec rather than a visual form.
- Diagram navigation is available for direct, statically located service calls.
  Services produced by nested calls or metaprogramming are still shown from the
  evaluated model but do not have an independently safe source range to focus.
