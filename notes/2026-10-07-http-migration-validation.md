# HTTP migration validation — 2026-10-07

The demo was generated and Docker-built in an isolated directory outside the Mobilis checkout. The final running artifact is `/tmp/mobilis-http-migration-validated-20261007/generate`. Its normal operations used only its own scripts, application images, Compose configuration, and mounted generated files. No runtime verifier or application source was mounted from Mobilis.

## Runtime mechanism

Envoy 1.35.3 uses `migration.authority.legacy` and `migration.authority.candidate` weighted-cluster runtime keys, plus `migration.mirror` for the request mirror fraction. The generated operation updates all three together using the admin runtime layer, reads the values back, and checks actual routing and upstream counters. This is supported runtime mutation, not arbitrary static-route mutation or an xDS service. The internal admin port is not published.

The real and shadow Go instances have identical handler source. `candidate-shadow` sets `SHADOW_WRITES=true`; `candidate` uses real writes. This allows full mirroring and partial candidate authority at the same time. Envoy discards shadow responses.

## Generated-project runtime checks

Ran `./dc_test up -d`, repeated `./seed`, then `./migration`, `./exercise`, and `./verify` for every state below in the same generated project, without regeneration, changing source, editing gateway YAML, or restarting the gateway.

The first routing sample after each live migration command was:

| Mirror / candidate authority | Legacy responses | Candidate responses | Shadow sends |
| --- | ---: | ---: | ---: |
| 0 / 0 | 120 | 0 | 0 / 120 |
| 10 / 0 | 120 | 0 | 9 / 120 |
| 100 / 0 | 120 | 0 | 120 / 120 |
| 100 / 1 | 989 | 11 | 1000 / 1000 |
| 100 / 10 | 100 | 20 | 120 / 120 |
| 100 / 50 | 69 | 51 | 120 / 120 |
| 0 / 100 | 0 | 120 | 0 / 120 |

These are samples, not promises of exact percentages. The verifier performed a separate routing sample in each state. Eight verifier passes completed: seven normal phases plus the stopped-candidate failure check.

Each exercise checked health, ordered reads, a gateway write, and read-after-write. Verification checked valid writes, malformed/invalid input (including UTF-16 and BOM input), and both ID and name conflicts against the actual implementations. Invalid and conflicting requests did not change database state.

At `100/0`, one correlated write produced exactly one audited legacy insert. The trace contained a legacy committed effect and an independently computed candidate shadow effect with these attributes:

```text
demo.write.mode = actual | shadow
db.operation.name = INSERT
db.collection.name = items
demo.write.effect = {"operation":"insert","table":"items","values":{"id":...,"name":...}}
```

The verifier parsed and compared those semantic objects against the Postgres audit trigger's resulting row values. It checked the complete before/after item state, the writer and number of audit entries, and zero item database spans in the shadow request. It checked W3C trace propagation, gateway parentage, one logical HTTP server span and expected item-query span per backend, and SQL/effect span ancestry.

Representative shadow-write trace: `3c1827e18e0a48c18fff916879f42ef0`.

The same verifier then stopped **both** Go instances and proved legacy reads and writes still succeeded at `100/0`. It restored the previously running services and waited for their HTTP readiness before returning. This establishes candidate failure isolation for this workload.

At `0/100`, the verifier stopped the legacy HTTP service. All routing probes used candidate with zero mirrors; a new write produced exactly one candidate audit entry and a matching committed effect. Reads, writes, invalid/conflict contracts, propagation and DB/request span ancestry passed with legacy stopped. A temporary Python tooling container used the legacy image, without starting the legacy HTTP server.

Representative candidate-authoritative write trace: `c303580e8c1b48e6bca94a2353e06558`.

The gateway container ID remained unchanged across the runtime checks. The generated repository stayed clean, and its tracked `gateway/envoy.yaml` had no diff. Compose bind mounts referenced only files/data in the generated artifact.

## Test and validation results

- Complete RSpec suite: **213 examples, 0 failures, 2 existing pending**.
- Generated verifier regression suite: **3 tests passed**. Identical logical span copies count once; conflicting copies fail; distinct HTTP span IDs still fail the exactly-one invariant.
- `bundle exec steep check`: passed with no type errors.
- `bundle exec rbs validate`: passed.
- Ruby Standard checks on every changed Ruby file: passed.
- Full repository Standard check: 389 violations remain in untouched files; the pre-change checkout had 398. No broad unrelated formatting rewrite was performed.
- Python source compilation, Bash syntax, Go source formatting and `git diff --check`: passed.
- Generated candidate `go vet ./...` and `go test ./...` with the matching Go image: passed (generated Go packages have no unit test files).
- All three generated application images built successfully.

## Scope of the proven claim

The demo proves independently computed semantic insert intent equals the committed authoritative effect for valid, fresh items; dry-run shadow requests do not mutate Postgres; traffic authority can move progressively using runtime controls without application code changes.

It does not prove arbitrary production application equivalence. Shadow intent does not simulate shared-database constraints, conflicts, triggers, contention, external effects, updates/deletes, or generated IDs. Verification assumes an isolated workload. Runtime overrides are in memory and reset after gateway restart; reapply `./migration`. The generated README documents these limits and the complete operator flow.
