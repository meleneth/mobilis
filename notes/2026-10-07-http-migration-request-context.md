# HTTP migration request context correction — 2026-10-07

This supersedes the deployment-based shadow architecture in the earlier validation note. The final artifact was generated and Docker-built at `/tmp/mobilis-http-request-context-final-20261007/generate`. Its executable `./demo` completed successfully using only generated files, application images and ordinary Compose wrappers. Mobilis was not invoked during operation; no repository mounts, hand-edited YAML, candidate semantic configuration changes or gateway restarts were used.

## Architecture and API verification

Inspected Envoy's exact tagged API and router implementation. Version 1.35.3 lacks `RequestMirrorPolicy.request_headers_mutations`; the generated image is now pinned to 1.36.11, whose API supports it. The real gateway successfully loaded that generated configuration and delivered mirrored requests with the expected context.

The ingress header-mutation filter removes `x-mobilis-shadow` and `x-mobilis-mirror-cluster` before routing. Only legacy weighted-cluster selection adds a trusted candidate mirror target. The mirror policy selects `cluster_header`, adds `x-mobilis-shadow: true` to the copy using `OVERWRITE_IF_EXISTS_OR_ADD`, and removes the internal target from that copy. Candidate-authoritative selection supplies no target, preventing self-mirroring. Backend HTTP ports, the diagnostic listener and admin port are unpublished.

Weighted-cluster runtime keys and the mirror fraction still change through the generated `./migration`, Envoy's admin runtime layer and `/runtime_modify`. This is supported runtime mutation, without xDS or arbitrary static-route mutation. The same traffic policy and runtime keys are used by an unpublished deterministic verification listener; its weighted-cluster bucket header is not honored at public ingress.

There is one Go candidate, with no shadow deployment or environment switch. Request validation and `determineEffect` execute once. Only `commitItem` diverges: a trusted shadow returns without any database call; authority applies the already-computed effect. Both emit the same canonical effect representation. The generated Go runtime is Debian 13 trixie, confirmed with its actual `/etc/os-release`; build and runtime images are `golang:1.25.3-trixie` and `debian:trixie-slim`.

## Runtime proof

Ran the complete generated `./demo`, including seed, exercise and verification at every step. Each deterministic routing probe covers all 100 Envoy selection buckets:

| Mirror / candidate authority | Legacy authority | Candidate authority | Shadow sends |
| --- | ---: | ---: | ---: |
| 100 / 0 | 100 | 0 | 100 |
| 100 / 10 | 90 | 10 | 90 |
| 100 / 50 | 50 | 50 | 50 |
| 0 / 100 | 0 | 100 | 0 |

Every normal and spoofed write produced exactly one audited authoritative insert and the expected complete database state. For legacy authority with full mirroring, the candidate HTTP span records shadow=true; its effect span records committed=false and zero item database spans. The independently computed effect matches both legacy's post-commit telemetry and the database trigger's actual row effect. Authoritative candidate requests record shadow=false and committed=true, with an insert span and exactly one candidate audit entry. Mirrored responses are discarded.

Representative post-restoration shadow trace: `e1bfcc905fa04b6f9de61875d1579c6d`. Both effects describe:

```json
{"operation":"insert","table":"items","values":{"id":2083466401,"name":"demo_20e092ac69244314a1f9effbcad1d720"}}
```

The `items.write` span attributes are:

```text
demo.request.shadow = true | false
demo.write.committed = false | true
demo.write.mode = shadow | actual
db.operation.name = INSERT
db.collection.name = items
demo.write.effect = canonical semantic JSON
```

The verifier supplies a fresh W3C trace ID for each logical request. Real Envoy mirroring preserves it, and each backend server span has gateway parentage. Effect and query spans descend from that backend request. No additional correlation ID was needed. JSON is compared as parsed objects, including operation, logical table and values; SQL text is only used to identify expected query instrumentation. The independently checked Postgres audit records writer, insert count and resulting row values. Audit correlation uses isolated before/after snapshots, rather than pretending the audit transports trace context.

The candidate outage check stopped the single candidate, proved authoritative legacy reads and writes still worked (also with a spoofed marker), restored the same deployment, and verified shadow equivalence again. Initial validation exposed a DNS refresh gap after restart: direct candidate readiness preceded Envoy readiness. The helper now waits for observed success through Envoy before counting routes; the full fresh-artifact rerun passed.

After that intentional outage restart, the candidate PID was **1488273**, container ID `9260cae8e44d8fe2b6d6421c452dfe7b99b2b25680ddaa500bccdf6a9f60e79c`, start time `2026-10-07T08:02:17.628722466Z`. PID, start time, image, environment, mounts and port bindings remained identical through 10%, 50% and full authority. Thus the same process handled mirrored writes without committing and later authoritative writes with real commits. There was no restart or configuration change for authority transfer. Gateway PID **1470452** and container identity also stayed unchanged.

At complete cutover, verification stopped the legacy HTTP server and proved candidate reads, writes, invalid/conflict contracts, spoof resistance, database state and expected trace parentage. Representative committed candidate trace: `b9ec3d3ad5bd416691432d6be8736747`. The verifier used a temporary container from the generated Python image as tooling; the legacy HTTP server was stopped throughout the check.

Additional `0/10` exercise and verification passed: exact 90 legacy / 10 candidate authority, zero mirror sends, and real writes at both implementations. This confirms independently disabled mirroring during partial authority.

Additional `100/100` verification passed with zero mirrors and a spoofed caller mirror target: full candidate authority cannot self-mirror even with the mirror fraction set to 100. Runtime state was returned to `0/100`. Two consecutive `./seed` calls both restored exactly the initial row and cleared the audit; a subsequent exercise observed one initial item, a real candidate write and two resulting items.

## Checks

- Complete RSpec: **215 examples, zero failures, two existing pending**.
- Generated candidate Go suite: **3 tests passed**, including strict request-context parsing, one canonical effect and a nil-database shadow commit boundary; `go vet ./...` passed.
- Generated verifier regression suite: **8 tests passed**, preserving logical span counting tests and rejecting committed shadow effects, incorrect authoritative shadow state, independent effect mismatches and unexpected shadow database calls.
- `bundle exec steep check`: no type errors; `bundle exec rbs validate`: passed.
- Targeted Ruby Standard checks passed. Full repository Standard still reports **389 pre-existing formatting violations**, unchanged from the preceding completed work; broad unrelated formatting was left alone.
- Bash syntax, Python compilation, changed Go formatting and `git diff --check` passed.
- All generated application images built successfully; Envoy 1.36.11 ran the actual generated configuration.

## Claim and limits

The exact same running candidate handles mirror and authority solely from trusted request context. The verifier proves independently computed candidate insert intent equals authoritative committed effects for valid fresh inserts, instead of comparing only HTTP responses. Progressive authority transfer changes traffic policy without changing application code or deployment semantics.

This makes candidate a plausible replacement for the demonstrated contract. It is not a proof of arbitrary production application equivalence. Dry-run intent does not simulate uniqueness races, triggers that change values, external effects, generated IDs, updates/deletes or multi-resource transactions. The internal network is trusted; unpublished ports are not authentication against other processes already on that network. Verification assumes no concurrent external writes or traffic-policy changes. Admin runtime state is ephemeral and must be reapplied after a gateway restart. Fractional mirroring is sampled; the complete semantic comparison uses full mirroring of eligible legacy traffic.
