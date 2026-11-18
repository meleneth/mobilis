# Mobilis Browser Playground

The playground is a static browser application. CRuby runs through ruby.wasm;
Ruby owns application state, Prism analysis, Haml rendering, DOM event handling,
and Mobilis execution. Turbo Streams apply targeted updates. JavaScript only
boots WASM and Turbo and provides browser download/ZIP primitives.

## Run

```sh
docker compose up --build
```

Open <http://localhost:8080>. The runtime image is nginx; it does not contain a
Ruby server or generation API. Once the page assets load, authored source stays
local and generation requires no outbound requests.

For a host build, run `npm ci`, install the isolated `playground/Gemfile`, and
run `playground/scripts/build`. Serve `playground/public/` over HTTP; browsers
do not allow the WASM application to boot reliably from `file://` URLs.

## Deploy to Devastation

From a clean, committed working tree, build, push, and roll out the playground
to the local Devastation Kubernetes cluster with:

```sh
./deploy-devastation.sh
```

The script tags the image with the current commit, pushes it to
`registry.deva.station`, updates only the `mobilis/mobilis` Deployment, and
waits for the rollout. `REGISTRY`, `KUBE_CONTEXT`, `NAMESPACE`, `DEPLOYMENT`,
`CONTAINER`, and `ROLLOUT_TIMEOUT` may be overridden through the environment.

## Authoring and local generation

All DSL service methods discovered in `Mobilis::DSL::DSLContext` appear in the
builder, including Rails. The editor uses `Mobilis::DSL.generate`, so the exact
downloaded `mobilis.rb` is executable in a Mobilis checkout:

```sh
bundle install
bundle exec ruby mobilis.rb
```

The “Local bundle” download also contains `mobilis-system.json`, accepted by
the repository's existing CLI:

```sh
bundle exec mobilis generate mobilis-system.json
```

Both native paths write `generate/` and may invoke Docker. The browser replaces
only the root `generate` method token with `build` in a temporary Prism-located
evaluation copy. It never changes the source being authored or downloaded.

## Generation capabilities

Browser generation capability belongs to the realized service writer. The
base writer is filesystem-only and browser-compatible. The Rails writer marks
itself local-only because its real implementation invokes Docker, `rails new`,
Bundler, and Rails generators. A declared `run_command` is also local-only.

All current non-Rails service writers use Ruby filesystem/template emission and
are eligible for browser generation. This includes PostgreSQL, MySQL, Redis,
S3 storage, observability services, Rack, Flask, FastAPI, Go HTTP, Envoy,
Grafbase, Kafka, Google Pub/Sub, GoAWS, Cassandra, Airflow, and pgAdmin. Runtime
tests prove PostgreSQL generation; eligibility does not imply that every
possible plugin/model combination has been exhaustively tested in WASM.

Mixed projects are all-or-nothing. If any realized writer is local-only, the UI
keeps full authoring and export support but refuses browser generation. It does
not omit the incompatible service or display a partial project as complete.

## Source invariants

- Valid source evaluates to the real `Mobilis::System` model.
- Prism locations identify direct service declarations and literal properties.
- Visual changes replace only the relevant source range.
- Comments, whitespace, and unrelated expressions stay byte-for-byte intact.
- Invalid source remains in the editor while the last valid visual model stays
  visible.
- Dynamic names and properties remain intact and their unsafe visual controls
  are disabled.
- Arbitrary Ruby remains more expressive than the visual form; unsupported
  expressions are shown as such rather than normalized away.

## Security and responsiveness

Ruby DSL source is executable code. WASM removes normal host process and network
APIs, but it is not a complete security boundary: code can consume CPU/memory
and interact with browser APIs exposed by the application. Do not paste
untrusted source. There is no telemetry and source is never submitted.

The static server's Content Security Policy permits both `unsafe-eval` and
`wasm-unsafe-eval`. The ruby.wasm `js` bridge uses JavaScript evaluation during
initialization; allowing only WebAssembly evaluation prevents the runtime from
booting. This CSP is another reason the playground must not be treated as a
security boundary for untrusted Ruby.

Generation currently runs in the main Ruby VM. The existing writers are short,
synchronous filesystem emitters, and keeping one VM avoids duplicating the
semantic model across a worker protocol. A worker becomes appropriate if
measured generation latency becomes interactive; request IDs already prevent a
stale generation result from replacing a newer one. Long-running native
subprocess generators are intentionally local-only.

## Compatibility findings

- The pinned official CRuby 4.0/WASI full runtime loads Mobilis and its
  standard-library dependencies. Mobilis, Haml, Temple, and Tilt sources are
  assembled into a deterministic asset and loaded into a writable in-memory
  WASI filesystem; no custom CRuby compilation is required.
- Prism is a CRuby 4.0 default extension in that runtime; parsing and source
  locations execute inside WASM.
- Haml 6.4, Temple, and Tilt are pure Ruby and render components in WASM.
- Active Support's inflector is loaded lazily by the local-only Rails resource
  plugin. This avoids cross-compiling its unrelated native dependency graph.
- `git` is now loaded lazily only by native materialization. The static path
  does not load or emulate it.
- The browser entrypoint omits the unrelated JobesWar terminal demo requires
  from the historical combined native loader; Mobilis implementation files are
  otherwise loaded from the canonical require list.
- Rails application scaffolding is incompatible by design because the existing
  writer uses host subprocesses and Docker.
- WASI does not preserve POSIX executable bits. The browser filesystem adapter
  ignores only unsupported `chmod` calls while retaining the exact generated
  file bytes; native generation continues to set executable permissions.

The detailed implementation/test status is in
[`IMPLEMENTATION_REPORT.md`](IMPLEMENTATION_REPORT.md).
