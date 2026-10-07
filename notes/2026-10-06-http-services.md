# HTTP services and migration proxy

## Problem
Add conventional Python/Go HTTP services and a Compose proxy while keeping graph connections authoritative.

## Current behavior
Config nodes hold intent, realized nodes hold Compose/env state, and writers emit runtime files. Dependencies already infer telemetry and URLs. Rails has database references; Postgres realization owns credentials. Flask is loose-script based; GoAws is an SNS/SQS emulator, not a Go archetype. There is no Pub/Sub transport or HTTP routing model. Tests use RSpec, FactoryBot, verifying doubles and temporary directories; materialization has destructive and Docker side effects.

## Proposed change
Add three archetypes, SQLAlchemy models in the existing model collection, and default HTTP routing metadata on dependency edges. Keep weights and mirroring independent. Resolve database and telemetry providers from edges; render bootstrap with no topology constants. Preserve legacy serialized name-only dependencies while emitting metadata-bearing edges. Use HTTPX and net/http for outgoing instrumentation, SQLAlchemy and otelpgx for one database instrumentation layer.

## Test strategy
Test graph round trips, invalid/ambiguous topology, structural files and Compose, then build/import generated Python and compile Go. Validate Envoy with its own config validator. Run all RSpec tests. Load the demo with materialization stubbed in tests, then exercise its normal service writers in temporary directories.

## Limits and future decisions
One default proxy route; integer percentages; one Postgres and collector per application; synchronous SQLAlchemy. No schema migration generator, generic ORM, service mesh, TLS policy or Kubernetes work. Before another deployment renderer, review whether HTTP route grouping and listener exposure need explicit generic concepts.

## Validation results
RSpec passed (210 examples, two pre-existing pending examples). The demo Python package installed as a wheel and its console command ran under Python 3.14; the generated Go service and all four database/telemetry combinations compiled with Go 1.25.3. Envoy 1.35.3 validated its config. Runtime checks proved initial mirroring, candidate-failure isolation, and full Go cutover with legacy stopped. Jaeger traces retained the supplied W3C trace ID and the Envoy parent, with one server and item-query execution span per backend. pgx's separate prepare/pool spans are distinct operations. Docker's local PyPI routing was unavailable, so Python image validation used a temporary offline wheelhouse; no cache URLs were added to generated code.

Collector-to-Jaeger connections now select the actual exporter hostname. Historical collector exporter/global env defaults are retained for old definitions; new application/proxy consumers select their own connected collector. Scoped collector exports prevent different collectors from colliding in environment files.
