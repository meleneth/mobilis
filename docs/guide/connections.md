# Connection affordances

`connect(from: consumer, to: provider)` is a directed declaration. It records a dependency in the system graph; realization and plugins use the service types and model metadata to generate configuration and application code.

## Every dependency: startup and URLs

```ruby
provider = rails("user-service", api: true)
app = rack("app")
connect(from: app, to: provider)
```

In Compose, the consumer gets a `depends_on` entry. Providers with a healthcheck use `service_healthy`; otherwise the condition is `service_started`. `force_skip_health_checks: true` selects `service_started` explicitly. Providers that request dependent restarts also emit `restart: true`.

Providers with an internal URL expose it to the consumer through an environment variable. For `app` connected to `user-service`:

| Location | Name / value |
| --- | --- |
| Environment file | `APP__USER_SERVICE_URL=http://user-service:80` |
| Consumer container | `USER_SERVICE_URL`, referencing `${APP__USER_SERVICE_URL}` |

Names are uppercased and hyphens become underscores. URLs use internal service names and ports, rather than published host ports. Redis exposes a separate named value such as `CACHE_REDIS_URL`; its realized node does not supply the generic internal URL used above. Add the dependency and explicitly alias that exported value when a consumer needs it:

```ruby
cache = redis("cache")
app = rack("app") do |service|
  service.add_gem("redis")
  service.env_var_alias("CACHE_URL", "cache_redis_url")
end
connect(from: app, to: cache)
```

The alias makes `CACHE_URL=redis://cache:6379` available inside the consumer. You still write the Redis client calls in application code.

## Rails to Rails: filtered resource clients

Declare filterable models on the provider, then connect a Rails consumer to it:

```ruby
require "mobilis"

Mobilis::DSL.generate("identity") do
  users = rails("user-service", api: true,
                primary_database: postgres("user-db")) do |service|
    service.add_rails_model("user") do |model|
      model.string "email"
      model.integer "account_id"
      model.filterable :id, :account_id, :email
    end
  end
  management = rails("management-service", api: true)
  connect(from: management, to: users)
end
```

`filterable` records allowed filter fields and marks the model as API-exposed. `expose_api!` can mark exposure explicitly, but without allowed fields collection filtering cannot succeed.

The provider receives:

- `app/models/concerns/mobilis/filterable.rb`, with allowed-filter metadata.
- Model declarations that include the concern and call `filterable_fields`.
- A controller per exposed model, such as `UsersController`.
- `GET /users`, `GET /users/:id`, and `POST /users/search` routes.

The collection GET selects permitted filters and runs `User.where(filters)`. POST search permits arrays for each declared filter field. Both reject requests with no permitted filters using `ActionController::BadRequest`. Show looks up the record by ID. These generated routes provide index, show, and search; no create/update/delete endpoints or authentication are added.

The consumer receives the `activeresource` gem and `app/models/user.rb`, defining `User < ActiveResource::Base`. It uses `USER_SERVICE_URL` with the provider's internal URL as a fallback. Call the client from consumer application code:

```ruby
User.find(42)
User.where(email: "crew@example.com")
User.search(account_id: [7, 8])
```

`search` posts JSON and converts the response into resource objects. `with_headers` temporarily merges request headers, injects the current OpenTelemetry propagation context when available, and restores the old headers afterward:

```ruby
User.with_headers("X-Request-ID" => request.request_id) do
  User.search(account_id: [7])
end
```

The helper mutates class-level headers during the block; review that behavior before using request-specific headers concurrently. Clients use the model's unqualified class name and file path. Two providers exposing `User`, or a consumer with its own `User` model, can overwrite the same generated client file. Choose distinct exposed model names.

Provider endpoints are driven by model exposure metadata even without a consumer connection. The connection is what gives the consumer its resource clients. A Rails provider with no exposed models yields dependency/URL wiring without ActiveResource clients.

## Other type-specific effects

| Declaration | Generated behavior |
| --- | --- |
| Rails → OTEL Collector | OTEL dependencies, initializer, `Instrumentation.trace`, and structured JSON logging |
| Rack → OTEL Collector | OTEL gems, `config/otel.rb`, environment values, and startup preload |
| FastAPI / Go HTTP → PostgreSQL | `DATABASE_URL` and database-specific generated application support; one PostgreSQL connection is supported |
| FastAPI → Cassandra | Contact points, port, datacenter, keyspace, credentials, and a native Python client; other service types receive connection variables through `connect` |
| FastAPI / Go HTTP → Google Pub/Sub | Scoped publisher and pull subscriber variables, official clients, and optional connected collector spans |
| FastAPI / Go HTTP → OTEL Collector | Trace exporters and HTTP/database instrumentation using the connected collector |
| Envoy → OTEL Collector | OpenTelemetry tracing configuration in the generated Envoy listener |
| OTEL Collector → Jaeger | Export target chosen from the connected Jaeger; at most one Jaeger exporter |

Rails database configuration uses the `primary_database:` option. A generic database `connect` is not a substitute for that option.

Grafana provisions supported data sources from the realized environment, even without individual `connect` edges. The default Prometheus scrape job retains `otel-collector:9464`; a connection alone does not rewrite that target. See [OpenTelemetry and observability](./observability.md) for supported paths and naming limits.

## HTTP routes

`route(from:, to:, candidate:, shadow:, mirror_percent:, candidate_percent:)` records routing metadata as dependency edges. The Envoy writer uses it to generate backend clusters and independent mirror / candidate weights. Generic `connect` adds a dependency, not migration percentages. See the [HTTP migration example](https://github.com/meleneth/mobilis/blob/core/scripts/20_http_migration.rb) and its [operator guide](https://github.com/meleneth/mobilis/blob/core/scripts/http_migration/README.md).

## Generated artifacts belong to you

Affordances are emitted during the one-time generation. Review and extend their application code in the generated project. Mobilis does not reconcile later edits with a revised connection graph.

The [IAM example](https://github.com/meleneth/mobilis/blob/core/scripts/08_large_iam_system.rb) demonstrates several providers, filterable models, consumers, and collector connections together.

See [Google Pub/Sub emulator](./google-pubsub.md) for role-scoped `connect` declarations and delivery behavior.
# Cassandra

Declare a single-node Cassandra database and connect a FastAPI consumer through
the normal `connect` edge:

```ruby
history = cassandra("history") do |db|
  db.version("4.1") # optional; defaults to ContainerVersions::CASSANDRA
  db.datacenter("datacenter1")
  db.keyspace("approvals")
  db.schema_file("schema.cql")
end
api = fastapi("records")
connect(from: api, to: history)
```

The generated consumer receives `CASSANDRA_CONTACT_POINTS`, `CASSANDRA_PORT`,
`CASSANDRA_DATACENTER`, `CASSANDRA_KEYSPACE`, `CASSANDRA_USERNAME`, and
`CASSANDRA_PASSWORD`. It uses the native `cassandra-driver` package; import
`<package>.cassandra_client.execute(operation, cql, parameters)` from generated
FastAPI code. The operation must be a simple identifier, such as `insert` or
`select`. Parameterized CQL keeps values out of the statement and out of spans.

The database stores data under `data/<environment>/<name>` in the generated
project. The container becomes healthy only after authenticated CQL succeeds,
the keyspace exists, and schema initialization succeeds. Startup repeats
`CREATE ... IF NOT EXISTS` declarations and never erases existing data. The
optional schema file may contain only `CREATE TABLE`, `CREATE TYPE`, or
`CREATE INDEX` declarations with `IF NOT EXISTS`. Schema changes to existing
objects need a separate migration process. Failed startup reports whether
readiness, role, keyspace, or schema initialization failed; inspect
`./dc_dev logs history` for the CQL error.
The generated application role receives `SELECT` and `MODIFY` on its keyspace.

Generated test and development environments use `mobilis_dev` /
`mobilis_dev_password`. Production env files contain `REPLACE_CASSANDRA_USER`
and `REPLACE_CASSANDRA_PASSWORD`; replace both before startup. These local
credentials and generated env files are not a production secret-management
design. The initial `cassandra` superuser remains in this local image and must
be handled before any real deployment.

To try the independent write/read example, run `bundle exec ruby scripts/22_cassandra.rb`
once, then in the generated directory run `./dc_dev up -d --build` and
`./dc_dev run --rm records python demo/run.py`. Set
`CASSANDRA_DEMO_OTEL=1` when generating to add a collector connection.
Only that connection enables client-side database spans; spans contain the
operation, keyspace, server address, and error status, but no CQL statement,
parameters, or credentials. The collector itself needs an exporter connection
to make spans viewable. This is client instrumentation, not Cassandra server
tracing.

This first slice uses one Cassandra node and `SimpleStrategy` with replication
factor 1. It demonstrates persistence and client access, not replication or
fault tolerance. Production topology, replication strategy, TLS, secret
delivery, backup, disaster recovery, and schema migration remain future work.
