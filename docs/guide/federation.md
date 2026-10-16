# Grafbase and Strawberry federation

Mobilis can generate a local Federation v2 graph with a Grafbase Gateway and
FastAPI subgraphs. Strawberry defines each subgraph in Python; Mobilis copies
that source into the generated service's installable package. The gateway
composes the running subgraphs and serves the resulting supergraph schema.

```ruby
sites = fastapi("sites", publish_port: false) do |service|
  service.graphql_subgraph("sites", source: "schemas/sites_schema.py")
end
deployments = fastapi("deployments", publish_port: false) do |service|
  service.graphql_subgraph("deployments", source: "schemas/deployments_schema.py")
end
gateway = grafbase("gateway", port: 5000)
connect(from: gateway, to: sites)
connect(from: gateway, to: deployments)
```

The supplied Python module must export a `strawberry.federation.Schema` named
`schema`. Mobilis installs `strawberry-graphql[fastapi]` and mounts
`GraphQLRouter` at `/graphql`. Query fields, mutations, entity keys,
`resolve_reference`, and application behavior live in that module. The
generator does not create placeholder business resolvers or translate SDL
into Python. Service `routes.py` and other packaged source files remain
available for custom logic.

Connect a subgraph to PostgreSQL using the usual `connect` edge. Its GraphQL
context receives a request-scoped SQLAlchemy `session` that closes at the end
of the request. `graphql_support.py` supplies `load_by_ids` and
`grouped_loader` for bounded batch queries; a resolver can keep a loader in
`info.context["loaders"]` so multiple entity fields share one batch per
request. Synchronous SQLAlchemy work should run through
`starlette.concurrency.run_in_threadpool` in async Strawberry resolvers.
Exceptions propagate as GraphQL errors. Database migrations and schema
ownership remain the application's responsibility.

The gateway connection graph is the subgraph registry. Only connected FastAPI
services with a declared subgraph are composed. Each subgraph must be healthy
before a short-lived composer service invokes `grafbase compose`; composition
failure stops gateway startup and leaves Grafbase's diagnostics in
`./dc_dev logs gateway-composer`. On success, the generated
`supergraph.graphql` is stored in a Compose volume and the official Grafbase
Gateway image starts in air-gapped mode with that file. No Grafbase account or
hosted registry is needed. The DSL's `port:` is the published host port; the
gateway listens internally on 5000. Its default health endpoint is `/health`.
The generated project uses pinned versions from `ContainerVersions`.

Run the numbered example and its generated integration test:

```sh
bundle exec ruby -Ilib scripts/24_grafbase_federation.rb
cd generate
./sites/demo/integration
```

The script seeds two PostgreSQL databases, validates a query traversing
`Site.name` from Sites and `Site.deployments` from Deployments, tests a
mutation and malformed entity key, and proves that incompatible `Site.id`
types fail real Grafbase composition. After startup, execute the federated
query directly against the published gateway port:

```sh
curl -fsS http://localhost:5000/graphql \
  -H 'Content-Type: application/json' \
  --data '{"query":"{ sites { id name deployments { id status } } }"}'
```

The generated project runs without Mobilis after generation. The demonstration
uses local credentials and data; do not treat its two databases or one gateway
as a production availability design.

Set `FEDERATION_DEMO_OTEL=1` before generating to connect the gateway and both
subgraphs to an OpenTelemetry collector. Grafbase exports spans and propagates
W3C `traceparent` to subgraphs; FastAPI instruments incoming HTTP requests and
SQLAlchemy operations using the existing connection-based telemetry setup.
Without collector connections, no exporter endpoint is configured and the
services run normally. The generated schema source remains independent of
telemetry.

This integration was tested with Strawberry Federation 2.5, Grafbase Gateway
0.53.5, and the published Grafbase CLI 0.105.1. It does not imply that all
Federation v2 directives or newer Strawberry defaults are supported by this
combination. Validate additional directives with the pinned composer and
gateway before adopting them. [Grafbase's repository](https://github.com/grafbase/grafbase)
says its hosted platform has sunsetted and the gateway and CLI are in
maintenance mode; the local, air-gapped path here does not depend on that
platform. REST wrapping and broader resolver generation are future work.
