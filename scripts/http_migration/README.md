# HTTP migration demo

Mobilis generates this self-contained project once. After generation, operate it using the scripts below; Mobilis and its repository are no longer needed. Envoy owns traffic selection, the applications own behavior, and OpenTelemetry provides evidence for verification.

The graph is `gateway → legacy / candidate → store`, with a second instance of the same Go application, `candidate-shadow`, receiving mirrors. All request handlers export traces through `telemetry → trace-viewer`. The shadow instance has `SHADOW_WRITES=true`; the authoritative candidate uses real writes. These are two instances of identical application source, allowing safe mirroring and partial authoritative cutover simultaneously.

From the generated project directory, with Docker Compose and Bash available:

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

Helpers discover ports and print a clickable human-facing Jaeger URL. `./exercise` checks health, reads items, creates one item through the gateway, and reads again. `./verify` sends its own correlated requests and checks the running applications, Postgres, Envoy runtime/counters, and Jaeger traces. It exits unsuccessfully on any unmet claim. At `100/0` it additionally stops both Go instances, proves legacy reads and writes still succeed, and restores the service. At `0/100` it stops legacy during verification and restores it afterward if it was previously running. The verifier's temporary Python process uses the legacy image as a tooling image; the legacy HTTP server is stopped throughout the cutover check.

`./seed` resets the demo table to `[{"id":1,"name":"example"}]` and clears the write audit. It is destructive to demo data and intended for local demonstrations. It can be repeated between runs. Run it with no concurrent workload; exercises and verification deliberately accumulate identifiable items until the next reset. Schema creation and the audit trigger are demo-owned initialization, not a generated general-purpose migration system.

## What the walkthrough proves

`./migration MIRROR_PERCENT CANDIDATE_PERCENT` changes two independent Envoy runtime settings:

- Mirror percentage selects how many authoritative requests are also sent to the dry-run candidate instance. Envoy discards mirrored responses; shadow errors cannot replace an authoritative response.
- Candidate percentage selects how many requests the real-write candidate serves authoritatively. The remaining requests go to legacy.

Thus `100/0` serves every response from legacy and mirrors every request. `100/10` gives the candidate approximately 10% authority while retaining full shadow coverage, including candidate-authoritative requests. `0/100` is complete candidate authority with no mirrors. Application code does not change between these phases. Both candidate instances are already running with the appropriate environment configuration; no application restart is needed to change percentages.

Read verification checks the ordered JSON contract, W3C trace propagation, exactly one logical HTTP server span and item-query span per expected backend, and gateway-to-backend parentage.

Write verification proves more than matching status codes. It sends a new item through Envoy with a unique supplied trace ID, then:

1. Checks the response body and identifies the authoritative implementation.
2. Queries Postgres directly and checks the complete before/after item state.
3. Checks that exactly one audited insert occurred, its writer matches authority, and its values match the request.
4. Retrieves that same trace and extracts the authoritative committed effect.
5. At full mirroring, extracts the shadow candidate's independently computed effect and checks that its request emitted zero item database spans.
6. Compares the database audit effect, authoritative telemetry effect, and shadow intent as parsed semantic objects; checks the evidence spans belong to the corresponding HTTP request.

The shadow handler parses and validates the same input and constructs the same insert effect, but its shadow branch never calls Postgres. The authoritative handler emits its effect only after a successful transaction commit. The audit trigger independently records the resulting row values and transaction's application identity. At complete cutover the candidate really inserts, and verification succeeds while the legacy server is stopped.

Only transfer authority after observing equivalence for the workloads that matter to your application. This small demo proves its specific item contract; it does not establish arbitrary application equivalence.

## Write contract and telemetry

`POST /items` accepts UTF-8 JSON without a byte-order mark, exactly `{"id": INTEGER, "name": STRING}`. IDs range from 1 through 2147483647. Names contain 1–80 ASCII letters, digits, underscores or hyphens. No extra fields, coercion, nulls, floating-point IDs, trailing JSON, or malformed JSON are accepted. Both implementations return:

- `201` with the supplied item after a successful authoritative insert.
- `400 {"error":"invalid item"}` for invalid input.
- `409 {"error":"item exists"}` for duplicate ID or name during authoritative execution.
- `503 {"error":"database unavailable"}` when an authoritative write cannot reach or commit to the database.

The dry-run candidate returns `201` for valid input after computing the effect. It deliberately does not check uniqueness against shared Postgres: the authoritative insert may already be present when a mirror arrives. Therefore mirrored conflict outcomes are **not** a claim of this demo. Mirrored responses are discarded. `GET /items` returns all items ordered by ID. `GET /health` returns `{"status":"ok"}`.

An `items.write` span has four effect attributes:

```text
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

These are supported Envoy runtime controls: [weighted clusters and mirror fractions](https://www.envoyproxy.io/docs/envoy/v1.35.3/api-v3/config/route/v3/route_components.proto), [runtime layers](https://www.envoyproxy.io/docs/envoy/v1.35.3/configuration/operations/runtime), and [admin runtime modification](https://www.envoyproxy.io/docs/envoy/v1.35.3/operations/admin). No xDS control plane is needed. The admin listener is internal to Compose, with no published host port. Runtime admin overrides are in memory and reset to generation defaults when gateway restarts. Reapply `./migration` after such a restart; no regeneration is needed. This local demo does not provide persistent rollout state, authentication, or concurrent-controller coordination.

The operational scripts target `dc_test`. Python and its dependencies run from the generated application's image. They mount no repository files and need no host Python installation. All source, Dockerfiles, Compose configuration, verifier, and documentation live in the generated project. Take the entire directory to another host, build with `./dc_test build`, and use the same flow.

## Generation and DSL

For the author generating this artifact, run once from the Mobilis repository:

```sh
bundle exec ruby -Ilib scripts/20_http_migration.rb
cd generate
```

Initial defaults can be set with `MIRROR_PERCENT` and `CANDIDATE_PERCENT` at generation time; normal operation uses `./migration`.

The demo uses existing config nodes, realized nodes, service writers and ordinary file models:

```ruby
legacy = fastapi("legacy")
candidate = go_http("candidate")
shadow = go_http("candidate-shadow")
gateway = envoy("gateway")
route from: gateway, to: legacy, candidate: candidate, shadow: shadow,
      mirror_percent: 100, candidate_percent: 0
```

`shadow:` optionally chooses a separate mirror backend that never appears in authoritative weights. Without it, existing two-backend routes mirror to `candidate:`. A single `connect from: gateway, to: legacy` still infers an ordinary proxy route. Application handlers have no knowledge of Envoy.

SQLAlchemy models are rendered using `add_sqlalchemy_model`; custom handlers and operations use ordinary `Mobilis::Model::File` artifacts. File models can request executable permissions. SQL types are SQLAlchemy expressions rendered under `sa.`. `python_type:` and `default:` are Python source; nullable and foreign-key columns are supported. This is a small renderer, not an ORM abstraction.

## Deliberate limits

This is a local, isolated demo with one Postgres table and deterministic insert intent. It has no external side effects, generated IDs, updates/deletes, transactional multi-resource writes, TLS/auth proxy policy, general schema migration system, or production rollout manager. Telemetry includes item values; use appropriate data handling before adapting this to sensitive requests.

Dry-run intent is computed from validated input; it does not simulate database constraints, triggers or contention. The verifier establishes successful fresh-insert equivalence and verifies real invalid/conflict contracts; it cannot prove shadow behavior for conflicts or arbitrary production requests. It requires no concurrent external writes or migration changes during a check. Partial percentages are sampled, so exact counts are not promised. At mirror percentages below 100, individual requests may have no mirror; full intended-versus-actual proof requires a `100` mirror phase.

SQLAlchemy is synchronous and supplies the Python database instrumentation layer without duplicate psycopg instrumentation. Go uses request contexts, pgx and `otelpgx`. Automatic HTTP/DB instrumentation supplies transport evidence; the application explicitly supplies semantic effect evidence. Jaeger ingestion is asynchronous, so verification waits for the relevant trace evidence. Duplicate copies of one span ID count once only when their semantic attributes and ancestry agree; conflicting copies fail, and distinct HTTP span IDs still fail the exactly-one invariant.
