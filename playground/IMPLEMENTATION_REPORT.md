# Implementation report

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

## Verified

The Ruby suite passes 305 examples (2 pre-existing pending examples). It covers
source/model round trips, byte identity, comments, unrelated source, invalid
input, dynamic expressions, Rails authoring, capabilities, Haml, Turbo Stream
markup, authoring export, stable real PostgreSQL generation, and a native parity
fixture. Four Playwright journeys pass in system Chrome, covering runtime and
DOM/Turbo initialization, visual/source editing, invalid-source recovery, exact
native/WASM PostgreSQL output parity, generation, file navigation, DSL download,
and project ZIP structure.

The production container packages only nginx and static assets; there is no
runtime Ruby process or generation endpoint. See the repository handoff for
the clean Docker build result.

Mermaid 12.3 is pinned and rendered through its public `initialize`/`render`
API. Its supported Node 22.12 runtime is isolated to the Debian build stage;
the production dependency audit reports no vulnerabilities, and Node is not
present in the nginx runtime image.

## Limitations

- Rails and explicit host-command generation require local execution.
- The visual form maps direct service calls and selected literal properties.
  Arbitrary metaprogramming remains source-only and is preserved.
- Syntax highlighting is limited to readable monospaced source/output; no
  JavaScript editor framework is included.
- Generation remains synchronous in the main VM pending evidence that a worker
  protocol is needed.
- Diagram navigation is available for direct, statically located service calls.
  Services produced by nested calls or metaprogramming are still shown from the
  evaluated model but do not have an independently safe source range to focus.
