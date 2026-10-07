# HTTP migration demo

Mobilis generates this self-contained project once. After generation, operate it using the scripts below; Mobilis and its repository are no longer needed. Envoy owns traffic selection, the applications own behavior, and OpenTelemetry provides evidence for verification.

The graph is `gateway → legacy / candidate → store`. All request handlers export traces through `telemetry → trace-viewer`. **The candidate is the actual replacement implementation, not a deployment in a special shadow mode.** Envoy marks mirrored copies as shadow requests. The candidate shares request parsing, validation and effect computation, then suppresses only the final database commit for a trusted shadow request. An authoritative request commits the same class of effect. The same running candidate can gradually become authoritative without redeployment or semantic reconfiguration.

```text
same candidate, same business logic:
  mirrored request      → compute effect → record intent → suppress commit
  authoritative request → compute effect → commit → record applied effect
```

From the generated project directory, with Docker Compose and Bash available, run the included executable shell script:

```sh
./demo
```

It runs this progression:

```sh
./dc_test up -d
./seed

./migration 100 0
./exercise
./verify

./migration 100 10
./exercise
./verify

./migration 100 50
./exercise
./verify

./migration 0 100
./exercise
./verify
```

Helpers discover ports and print a clickable human-facing Jaeger URL. `./exercise` checks health, reads items, creates one item through the gateway, and reads again. `./verify` sends its own correlated requests and checks the running applications, Postgres, Envoy runtime/counters, and Jaeger traces. It exits unsuccessfully on any unmet claim. At `100/0` it additionally stops candidate, proves legacy reads and writes still succeed, restores candidate with unchanged configuration, and verifies shadowing again. This restored process continues through partial authority and complete cutover. At `0/100` it stops legacy during verification and restores it afterward if it was previously running. The verifier's temporary Python process uses the legacy image as a tooling image; the legacy HTTP server is stopped throughout the cutover check.

`./seed` resets the demo table to `[{"id":1,"name":"example"}]` and clears the write audit. It is destructive to demo data and intended for local demonstrations. It can be repeated between runs. Run it with no concurrent workload; exercises and verification deliberately accumulate identifiable items until the next reset. Schema creation and the audit trigger are demo-owned initialization, not a generated general-purpose migration system.

## What the walkthrough proves

`./migration MIRROR_PERCENT CANDIDATE_PERCENT` changes two independent Envoy runtime settings:

- Mirror percentage selects how many **legacy-authoritative** requests also go to candidate as shadow requests. Envoy discards mirrored responses; shadow errors cannot replace an authoritative response.
- Candidate percentage selects how many requests the real-write candidate serves authoritatively. The remaining requests go to legacy.

Thus `100/0` serves every response from legacy and mirrors every request. `100/10` gives candidate approximately 10% authority and mirrors all remaining legacy requests to that same candidate. **Candidate-authoritative requests are never mirrored back to candidate**, preventing duplicate processing and effects. `0/100` is complete candidate authority with no mirrors. These controls remain independent: mirror fraction applies to the traffic still eligible for shadow comparison. No candidate restart or configuration change transfers authority.

Public ingress removes caller-supplied `X-Mobilis-Shadow` and the internal mirror-target header before routing. Only the mirrored copy receives `X-Mobilis-Shadow: true`. Backend HTTP ports are not published to the host; the trusted boundary is the generated project's internal network and Envoy ingress. `./verify` sends spoofed markers at both authoritative implementations and proves they cannot suppress a real write.

Read verification checks the ordered JSON contract, W3C trace propagation, exactly one logical HTTP server span and item-query span per expected backend, and gateway-to-backend parentage.

Write verification proves more than matching status codes. It sends a new item through Envoy with a unique supplied trace ID, then:

1. Checks the response body and identifies the authoritative implementation.
2. Queries Postgres directly and checks the complete before/after item state.
3. Checks that exactly one audited insert occurred, its writer matches authority, and its values match the request.
4. Retrieves that same trace and extracts the authoritative committed effect.
5. At full mirroring, extracts the shadow candidate's independently computed effect and checks that its request emitted zero item database spans.
6. Compares the database audit effect, authoritative telemetry effect, and shadow intent as parsed semantic objects; checks the evidence spans belong to the corresponding HTTP request.

The Go handler parses and validates input and constructs its insert effect once, before a small commitment function checks request context. The shadow path makes no database call; the authoritative path applies that computed effect. The authoritative handler emits its effect only after a successful transaction commit. The audit trigger independently records the resulting row values and transaction's application identity. At complete cutover the candidate really inserts, and verification succeeds while the legacy server is stopped.

Only transfer authority after observing equivalence for the workloads that matter to your application. This small demo proves its specific item contract; it does not establish arbitrary application equivalence.

## Write contract and telemetry

`POST /items` accepts UTF-8 JSON without a byte-order mark, exactly `{"id": INTEGER, "name": STRING}`. IDs range from 1 through 2147483647. Names contain 1–80 ASCII letters, digits, underscores or hyphens. No extra fields, coercion, nulls, floating-point IDs, trailing JSON, or malformed JSON are accepted. Both implementations return:

- `201` with the supplied item after a successful authoritative insert.
- `400 {"error":"invalid item"}` for invalid input.
- `409 {"error":"item exists"}` for duplicate ID or name during authoritative execution.
- `503 {"error":"database unavailable"}` when an authoritative write cannot reach or commit to the database.

For a shadow request, candidate returns `201` for valid input after computing the effect. It deliberately does not check uniqueness against shared Postgres: the authoritative insert may already be present when a mirror arrives. Therefore mirrored conflict outcomes are **not** a claim of this demo. Mirrored responses are discarded. `GET /items` returns all items ordered by ID. `GET /health` returns `{"status":"ok"}`.

An `items.write` span records:

```text
demo.request.shadow = true or false
demo.write.committed = false or true
demo.write.mode = "shadow" or "actual"
db.operation.name = "INSERT"
db.collection.name = "items"
demo.write.effect = JSON string
```

The stable semantic JSON is:

```json
{"operation":"insert","table":"items","values":{"id":2,"name":"something"}}
```

The verifier parses this JSON, so serialization key order is irrelevant. Trace IDs correlate mirrors with their authoritative request; span ancestry ties effect and database spans to each backend's request. Postgres's `item_effects` table records the actual effect, writer, and audit sequence. Verification uses the change in audit sequence while running an isolated workload, rather than claiming the audit itself is a distributed trace transport.

## Runtime implementation

Envoy's static route declares `migration.authority` as the weighted-cluster runtime key prefix and `migration.mirror` as its mirror fraction runtime key, including when initial mirroring is zero. A generated helper submits both weights (totaling 100) and the mirror fraction together to `/runtime_modify`, then reads `/runtime` and probes actual routing and mirror counters. It does not mutate static routes or edit YAML.

Envoy is pinned to `1.36.11`: the earlier `1.35.3` API did not support mirror-specific header mutations. Its [tagged route API](https://github.com/envoyproxy/envoy/blob/v1.36.11/api/envoy/config/route/v3/route_components.proto) provides `RequestMirrorPolicy.request_headers_mutations`. An ingress header-mutation filter removes reserved caller headers; only legacy weighted-cluster selection supplies the trusted mirror target. The mirror policy uses `cluster_header` to select that target and adds the shadow marker only to the copy. Candidate selection supplies no mirror target, so even 100% mirroring cannot self-mirror candidate authority.

These are supported Envoy runtime controls: weighted-cluster runtime weights, runtime mirror fractions, [runtime layers](https://www.envoyproxy.io/docs/envoy/latest/configuration/operations/runtime), and [admin runtime modification](https://www.envoyproxy.io/docs/envoy/latest/operations/admin). No xDS control plane is needed. The admin listener is internal to Compose, with no published host port. Runtime admin overrides are in memory and reset to generation defaults when gateway restarts. Reapply `./migration` after such a restart; no regeneration is needed. This local demo does not provide persistent rollout state, authentication, or concurrent-controller coordination.

Partial-authority verification is deterministic: an unpublished listener uses the same route policy and runtime keys, plus Envoy's weighted-cluster `header_name` support. The verifier exercises all 100 selection buckets and targets both implementations for correlated writes. The public listener does not honor that diagnostic header and retains normal random selection. The verifier checks exact authority counts, mirror counters, and no candidate self-mirroring; correctness does not depend on random selection getting lucky.

The operational scripts target `dc_test`. Python and its dependencies run from the generated application's image. They mount no repository files and need no host Python installation. All source, Dockerfiles, Compose configuration, verifier, and documentation live in the generated project. Take the entire directory to another host, build with `./dc_test build`, and use the same flow.

## Unit tests

Unit tests construct HTTP handlers without opening Postgres connections or configuring exporters. They need no Compose services, Envoy, Jaeger or collector. Install ordinary development dependencies once:

```sh
cd legacy
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -e '.[test]'
pytest
pytest --cov=service_legacy --cov-report=term-missing
cd ../candidate
go mod tidy
go test ./...
go test -race ./...
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
cd ..
./test
```

`./test` is a convenience shell wrapper around native pytest coverage and Go race/coverage commands; it uses the activated virtual environment and your installed Go toolchain. It never starts infrastructure or installs dependencies. Go's race detector requires a supported Go platform and a C compiler. The Python `test` extra contains pytest, pytest-cov/coverage.py and flexmock, separate from runtime dependencies. Coverage uses branches and reports missing lines; no arbitrary coverage gate is imposed.

The generated archetypes provide a health smoke test and ordinary handler factories. Python's `create_app(telemetry=False)` avoids exporter setup, and its database engine is lazy. Go's `Handler(Dependencies)` constructs routes separately from `New`'s runtime resource setup. These are application construction seams, not a Mobilis testing DSL.

Demo-owned `ItemStore`/`itemStore` collaborators isolate item database behavior. Python tests override FastAPI's real dependency and apply flexmock expectations only to existing methods on real production objects/modules. A regression test rejects an invented method. SQLite exercises the real SQLAlchemy read adapter without reproducing ORM internals. Go uses a small fake implementing the production interface, which rejects unexpected calls, wrong effects, duplicate commits and missing interactions.

For identical input, Go HTTP tests require authority to commit the exact canonical effect once, shadow to make zero commit calls, and both to report that same effect. Malformed shadow marker values remain authoritative. Telemetry translation is checked deterministically; a local span recorder also checks the handler's emitted context/effect evidence without exporters. Python verifies committed-effect translation occurs only after a successful commit and never on failed writes.

Keep the three levels distinct: Mobilis RSpec tests generation, generated unit suites test local behavior, and `./verify` tests real traffic, database effects and distributed tracing. Unit coverage intentionally leaves runtime bootstrap and the Postgres adapters to integration verification; it is not a claim that those paths are unit-tested.

## Generation and DSL

For the author generating this artifact, run once from the Mobilis repository:

```sh
bundle exec ruby -Ilib scripts/20_http_migration.rb
cd generate
```

Initial defaults can be set with `MIRROR_PERCENT` and `CANDIDATE_PERCENT` at generation time; normal operation uses `./migration`.

The demo uses existing config nodes, realized nodes, service writers and ordinary file models:

```ruby
legacy = fastapi("legacy", publish_port: false)
candidate = go_http("candidate", publish_port: false)
gateway = envoy("gateway", verification_port: 8081)
route from: gateway, to: legacy, candidate: candidate,
      mirror_percent: 100, candidate_percent: 0
```

This demo generates one Go candidate. A single `connect from: gateway, to: legacy` still infers an ordinary proxy route. Application handlers have no knowledge of Envoy.

SQLAlchemy models are rendered using `add_sqlalchemy_model`; custom handlers and operations use ordinary `Mobilis::Model::File` artifacts. File models can request executable permissions. SQL types are SQLAlchemy expressions rendered under `sa.`. `python_type:` and `default:` are Python source; nullable and foreign-key columns are supported. This is a small renderer, not an ORM abstraction.

## Deliberate limits

This is a local, isolated demo with one Postgres table and deterministic insert intent. It has no external side effects, generated IDs, updates/deletes, transactional multi-resource writes, TLS/auth proxy policy, general schema migration system, or production rollout manager. Telemetry includes item values; use appropriate data handling before adapting this to sensitive requests.

Dry-run intent is computed from validated input; it does not simulate database constraints, triggers or contention. The verifier establishes successful fresh-insert equivalence and verifies real invalid/conflict contracts; it cannot prove shadow behavior for conflicts or arbitrary production requests. It requires no concurrent external writes or migration changes during a check. Public authoritative selection and fractional mirroring are sampled; the internal verification listener deterministically proves the authoritative split. At mirror percentages below 100, individual requests may have no mirror; full intended-versus-actual proof requires a `100` mirror phase.

The Go build image and runtime image use Debian trixie (`golang:1.25.3-trixie` and `debian:trixie-slim`), with no Alpine/musl or BusyBox dependency.

SQLAlchemy is synchronous and supplies the Python database instrumentation layer without duplicate psycopg instrumentation. Go uses request contexts, pgx and `otelpgx`. Automatic HTTP/DB instrumentation supplies transport evidence; the application explicitly supplies semantic effect evidence. Jaeger ingestion is asynchronous, so verification waits for the relevant trace evidence. Duplicate copies of one span ID count once only when their semantic attributes and ancestry agree; conflicting copies fail, and distinct HTTP span IDs still fail the exactly-one invariant.
