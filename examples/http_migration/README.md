# HTTP migration demo

The graph is `gateway → legacy/candidate → store`, with all three HTTP components connected to `telemetry → trace-viewer`. Both implementations expose `GET /health` and `GET /items`; items returns an ordered JSON array of `{id, name}` from the same Postgres table. Mirroring this read-only contract has no write-side effects.

Render into a fresh directory without materialization side effects:

```sh
bundle exec ruby -Ilib scripts/20_http_migration.rb --render /tmp/mobilis-http-demo
cd /tmp/mobilis-http-demo
docker compose --env-file test.env -f test-compose.yml up --build -d
```

Initialize the demo schema/data explicitly (schema creation is not application bootstrap or a migration system):

```sh
docker compose --env-file test.env -f test-compose.yml exec legacy python -c 'from service_legacy.database import engine, Session; from service_legacy.models import Base, Item; Base.metadata.create_all(engine); session = Session(); session.merge(Item(id=1, name="example")); session.commit(); session.close()'
```

Get the gateway and trace viewer ports from `GATEWAY_WEB_PORT` and `TRACE_VIEWER_WEB_PORT` in `test.env`; request `/items` through the gateway. The initial route returns the legacy response and mirrors 100% to the candidate. Candidate errors never replace the authoritative response. Inspect traces in Jaeger at the trace viewer port. Ordinary ASGI, HTTP clients and database queries have automatic instrumentation; application handlers contain no tracing boilerplate. Go database queries use `r.Context()`; outgoing Go requests should use `http.NewRequestWithContext` and `deps.HTTPClient`. Python outgoing clients use HTTPX or Requests.

Change `MIRROR_PERCENT` and `CANDIDATE_PERCENT` when rendering into another fresh directory. They are independent integers in 0–100. Supported steps include `0/0`, `10/0`, `100/0`, `100/1`, `100/10`, `100/50`, `0/100`. For an existing deployment, edit `gateway/envoy.yaml` weights (`100-candidate`, `candidate`) and `request_mirror_policies` fraction, then restart gateway. No application changes are needed. Backends are selected by Docker DNS and their declared ports.

The normal script invocation without `--render` uses Mobilis materialization, including its usual generated-directory recreation and image build.

## New DSL

```ruby
api = fastapi("api", port: 8000)
worker = go_http("worker", port: 8080)
proxy = envoy("proxy", port: 8080)
connect from: api, to: postgres("db")
connect from: api, to: otel_collector("traces")
route from: proxy, to: api, candidate: worker,
      mirror_percent: 100, candidate_percent: 0
api.add_sqlalchemy_model("Item", table: "items") do |model|
  model.column "id", "Integer", python_type: "int", primary_key: true
  model.column "name", "String(80)", python_type: "str", unique: true
end
```

SQL types are SQLAlchemy expressions rendered under `sa.`; Python type annotations and `default:` are Python source strings. Use `default: '"untitled"'`, `default: "True"`, or `default: "42"`. `nullable: true` produces optional typed columns; `foreign_key: "items.id"` produces `ForeignKey`. This is deliberately a small SQLAlchemy renderer, not an ORM abstraction. Keep custom application files in existing `Mobilis::Model::File` models as the demo does.

A single `connect from: proxy, to: api` infers an ordinary default proxy route. Use `route` for explicit mirroring/splitting when there are two backends.

One default proxy route, integer percentages, one Postgres and one collector per application are supported. SQLAlchemy is synchronous; no async ORM, Alembic generation, TLS/auth proxy policy, Pub/Sub transport, dynamic discovery, or Kubernetes configuration is generated. pgx uses the community `otelpgx` adapter because official Go HTTP instrumentation does not supply a pgx tracer. SQLAlchemy is the sole Python database span layer; psycopg is not also instrumented.

To check the seeded initial demo, run the dependency-free verifier on its Compose network (mount the repository's verifier path):

```sh
docker run --rm --network mobilis-http-migration-test_default \
  -v /absolute/path/to/mobilis/examples/http_migration/verify.py:/verify.py:ro \
  python:3.14.4-trixie python /verify.py --mirror
```

It checks the HTTP contract and finds the supplied W3C trace ID in Jaeger, including the Envoy parent and exactly one HTTP server and item-query span per backend. After complete cutover use `--authority candidate` instead of `--mirror`. It does not start, stop, or alter services.
