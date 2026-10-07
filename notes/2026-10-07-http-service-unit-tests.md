# Generated HTTP service unit tests — 2026-10-07

Validated the generated migration project at `/tmp/mobilis-http-unit-tests-20261007/generate`. Native service unit tests ran while every container in its Compose project was stopped. They construct in-process HTTP handlers and do not require Postgres, Envoy, Jaeger, an exporter or the collector. Dependency installation is a normal setup step; test execution itself needs no external network. Python TestClient uses asyncio's local socketpairs, so this host's socket-restricted sandbox required an unrestricted test process. That does not introduce an infrastructure dependency.

## Substrate and application ownership

FastAPI writers emit a separate `[project.optional-dependencies].test` extra with pytest, pytest-cov and flexmock. Coverage.py is supplied by pytest-cov. Pytest discovers `tests/`; coverage measures the actual generated package, uses branches and shows missing lines. A native health smoke test is included. Runtime images install the ordinary package, without test extras.

Python database construction is lazy through `get_engine`/`get_session`, and `create_app(telemetry=False)` avoids exporter configuration. Lifespan cleanup disposes an already-created engine without opening a new one. Go exposes `Handler(Dependencies)` separately from `New`'s runtime bootstrap, and emits a standard `httptest` health test. No Go testing framework or new external testing dependency was added.

The demo owns its `ItemStore` and `itemStore` boundary, concrete Postgres adapters, effect translation and substantive behavioral tests. These remain ordinary file models. The generated root `./test` calls native pytest coverage and Go race/coverage commands; it installs nothing and starts no infrastructure. Native commands remain independently usable. Both language runtimes remain Debian trixie.

## Verifying collaborators and effects

Every flexmock expectation targets a real `ItemStore` instance or an existing function on the actual project module. Existing signatures and exact arguments are checked, and cardinality expectations reject missing or duplicate calls. `test_flexmock_rejects_a_method_absent_from_the_production_collaborator` proves an invented method raises FlexmockError. No loose flexmock objects, dictionaries or generic empty objects are used. The store's explicit session factory fails if the isolated handler unexpectedly opens a session. Real SQLite/SQLAlchemy exercises ordered read adapter behavior, rather than mocking ORM internals.

The Go fake has a compile-time assertion against the production `itemStore` interface, as does its actual adapter. It fails immediately on unexpected methods/interactions represented by that interface, extra reads, duplicate commits or a different operation/table/item effect. Cleanup also rejects missing interactions. For the same input `{id:42,name:"foo"}`, authority must commit exactly once with the literal expected effect; shadow must make zero commit calls. Both HTTP executions must emit exactly that semantic effect with the appropriate shadow and committed flags. The nil-collaborator shadow proof is retained. Missing, duplicate, malformed, uppercase, whitespace and other unexpected marker values remain authoritative; only a single literal `true` suppresses commit.

Go uses a local SDK span recorder with a per-test provider, without exporters or global provider mutation. Tests inspect the application's request/effect attributes and preservation of request trace context, not SDK internals. Canonical effect serialization and attribute translation are tested directly. Python uses a verifying spy on its real translation function to prove exact semantic arguments and commit-before-report ordering; failed writes must not invoke committed-effect translation. No OpenTelemetry methods are mocked.

HTTP tests cover health, empty/populated reads, exact response bodies/status/content type, valid boundary values, malformed JSON and encodings, unknown/missing fields, invalid types/ranges/names, successful writes, conflict/unavailable outcomes and relevant read failures. Go also covers shadow suppression/reporting, authoritative commitment and row-data failures. Application unit tests do not claim to prove Envoy's header sanitization.

## Executed checks and coverage

Using the generated project, actually ran:

```sh
pytest
pytest --cov=service_legacy --cov-report=term-missing
go test ./...
go test -race ./...
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
./test
```

Python: **38 tests passed**, repeatedly, with **79% overall branch-aware coverage**. `routes.py` has **100% coverage**. Missing coverage is primarily runtime CLI/bootstrap, exporter configuration and the real Postgres write adapter. The upstream Starlette/httpx compatibility layer emits one deprecation warning; tests pass without suppressing it.

Go: all tests and race checks passed. `internal/app` has **51.1% statement coverage**, and whole-project coverage including `cmd` is **42.8%**. `Handler`, route handling, `determineEffect`, shadow detection, request context recording, `commitItem` and `effectAttributes` have **100% coverage**. Actual Postgres adapter methods and runtime bootstrap are intentionally covered by runtime integration rather than infrastructure-dependent unit tests. The logging branch of response-writing failure remains outside the measured core surface. `go vet` and changed Go formatting passed. Native Go was 1.27.1; Docker built the generated service with its pinned 1.25.3 trixie image.

Also emitted bare Python and Go archetypes for all four database/telemetry combinations and ran their health tests successfully. Each Python variant passed its native test; each Go variant passed `go test ./...` after normal module setup.

Mobilis: **215 RSpec examples, zero failures, two existing pending**. Focused assertions cover separate Python extras, coverage configuration, emitted native health/application tests, handler factories and the executable project test wrapper. Steep and RBS validation passed. Targeted Ruby formatting, Bash syntax, Python parsing and diff checks passed. Full Standard still reports the same **389 pre-existing violations**; no unrelated formatting cleanup was done.

## Runtime regression

The complete generated `./demo` passed after refactoring. This exercised seed, health/read/write workloads, live runtime policy changes, read and effect traces, spoofed markers, intentional candidate failure/recovery, partial authority and cutover with the legacy server stopped:

| Mirror / candidate authority | Legacy responses | Candidate responses | Mirrors |
| --- | ---: | ---: | ---: |
| 100 / 0 | 100 | 0 | 100 |
| 100 / 10 | 90 | 10 | 90 |
| 100 / 50 | 50 | 50 | 50 |
| 0 / 100 | 0 | 100 | 0 |

At shadowing, the verifier compared independent candidate intent with committed legacy telemetry and the Postgres trigger's actual insert effect, checked exactly one mutation and zero shadow item database spans, and verified request/evidence ancestry. At candidate authority, real writes and expected database spans passed; complete cutover passed with legacy stopped. Caller-supplied markers could not suppress authoritative writes. The existing verifier regression suite also passed all **8 tests** in the generated image. No integration assertions were weakened.

## Deliberately project-specific

Item-store interfaces, application validation cases, effect representations, effect commitment/reporting behavior, validating fakes, flexmock expectations and the migration project's test wrapper were deliberately not abstracted into Mobilis. A service testing/mocking DSL or generic effect framework would be premature. Mobilis provides ecosystem substrate and construction seams; the generated application owns its tests.
