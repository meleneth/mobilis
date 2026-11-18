# Playground service inspector and embedded documents

## Problem

The browser playground validates Ruby source into a `Mobilis::System`, but its
visual builder exposes only direct service declarations and a small literal
property schema. Diagram selection currently crosses into Ruby through a DOM
event, connection declarations have no first-class source records, and Mobilis
has no embedded Base64/tar packaging contract.

The Ruby DSL must remain authoritative while the UI gains a full validated
service inspector, source-aware relationship edits, and transactional editing
of files packed inside the DSL.

## Current behavior

- `Mobilis::Browser::SourceDocument` owns Prism parsing, safe source ranges,
  evaluation through non-materializing `DSL.build`, validation, and surgical
  service edits. Direct service-call offsets are its current identities.
- `MobilisPlayground::Application` owns the last valid `Analysis`, source,
  topology, generated files, and Turbo region updates. Source input and visual
  changes re-evaluate synchronously in the resident main-thread CRuby/WASM VM.
- `Mobilis::Browser::Topology` projects nodes and model relationships from the
  validated `Mobilis::System`. Its safe node IDs are deterministic hashes of
  semantic identity; source offsets are used only for navigation.
- Mermaid rendering is JavaScript-only, but node selection currently dispatches
  back into Ruby. There are no polling loops, scheduled Ruby callbacks,
  workers, invocation metrics, or application-level undo/redo history.
- Generation is revision-guarded by a monotonically increasing request number,
  although it is currently synchronous.
- DSL `connect` and `route` calls become `extra_depends_on` model edges.
  Reference slots such as `primary_database`, `loki`, and `databases` are a
  separate relationship source. Generated Compose `depends_on` is realized
  output and is not an interchangeable authoring concept.
- Mobilis models individual generated files with `Mobilis::Model::File`, but no
  Base64 tar declaration, manifest, archive codec, virtual-document model, or
  embedded archive syntax exists. Build-time Base64 is used only to serialize
  the WASM filesystem and browser downloads.

## Proposed change

1. Extend `SourceDocument::Analysis` with Prism-located relationship and archive
   declarations. Add conservative target/type/removal transforms that reject
   dynamic or ambiguous expressions.
2. Build a service-inspector projection by composing the validated node,
   declaration, topology, capabilities, relationships, and full serialized
   node configuration. Keep unsupported advanced fields visible and link them
   to their real Ruby range rather than inventing controls.
3. Move selection entirely into a JavaScript UI-state controller. Pre-render
   inspector snapshots and selection metadata so graph/card selection, source
   focusing, scrolling, and panel expansion execute no Ruby.
4. Introduce one pure-Ruby `Mobilis::EmbeddedArchive` codec shared by native
   Mobilis and WASM. Version 1 is deterministic Base64-encoded POSIX tar with a
   `.mobilis-archive.json` manifest, normalized metadata, SHA-256 integrity,
   strict relative paths, regular files only, and bounded encoded/decoded/file
   sizes. `Base::Node#embedded_archive` expands the same archive into existing
   `Model::File` objects, so generators remain unchanged.
5. Add Prism discovery for literal `embedded_archive(..., payload: "...")`
   calls. A JavaScript virtual-document controller browses decoded snapshots and
   stages keystrokes without Ruby. Commit sends one semantic request containing
   archive identity, member bytes, and the opening parent revision. Ruby checks
   the revision, repacks through the shared codec, replaces only the payload
   range, revalidates, and atomically publishes the new source.
6. Add a small source history for structured transactions, including archive
   commit undo/redo. Ordinary textarea typing retains browser-native history.
7. Instrument semantic Ruby requests with count and duration. Initialization,
   source validation, structured edits, archive commits, history, and generation
   are semantic work; selection, scrolling, panel toggles, archive browsing,
   embedded typing, and idle time remain JavaScript-only.

A Web Worker migration is intentionally deferred: the existing Ruby `js`
bridge owns Haml/Turbo rendering and DOM event handling, so moving the VM would
require replacing that established boundary with a message-render protocol.
The current event-driven VM is quiescent without polling; removing nonsemantic
selection work from Ruby satisfies the runtime requirement without a second
state transport.

## Test strategy

- Unit-test relationship extraction and surgical transforms across comments,
  dynamic expressions, incoming/outgoing ownership, and semantic options.
- Unit-test every archive boundary: deterministic packing, integrity, binary
  preservation, unsafe entries, limits, malformed tar/Base64, source-only
  replacement, revision conflicts, and unchanged-member preservation.
- Test inspector composition against every browser service type and distinguish
  declared references, semantic connections, and operational dependencies.
- Browser-test graph/card/edge selection, inspector edits, archive navigation,
  staged save/discard/conflict/undo/redo, graph refresh, generation isolation,
  and Ruby invocation-count quiescence.
- Rebuild the static WASM bundle and exercise the workflows in real CRuby/WASM.

## Open questions and explicit limits

- Arbitrary Ruby and dynamically constructed declarations cannot always be
  transformed safely. They remain visible in validated configuration and are
  navigable when Prism has a trustworthy range, but unsafe controls are disabled.
- Source offsets are not durable document identities across arbitrary edits;
  transactions therefore pair them with a parent source revision and rediscover
  declarations after every successful validation.
- Generated/realized health checks, ports, environment, images, and volumes are
  inspectable output when no public config-node DSL setter exists. The inspector
  will not create a parallel DSL merely to make those generated details editable.
