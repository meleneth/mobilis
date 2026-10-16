# Writing a system

Require Mobilis and declare services inside `Mobilis::DSL.generate`. The outer block exposes DSL methods; service configuration uses an explicit block argument.

```ruby
require "mobilis"

Mobilis::DSL.generate("my-system") do
  database = postgres("app-db")
  rails("app", primary_database: database) do |service|
    service.use_rspec!
    service.add_rails_model("user") do |model|
      model.string "name"
      model.integer "score"
    end
  end
end
```

This is a materializing entrypoint: running the definition writes `generate/` and performs image builds and scaffolding commands.

## Service declarations

| Area | DSL methods |
| --- | --- |
| Ruby applications | `rails`, `rack` |
| HTTP applications and proxy | `flask`, `fastapi`, `go_http`, `envoy` |
| Databases and cache | `postgres`, `mysql`, `redis`, `pgadmin` |
| Object storage | `s3` (also `s3_storage`) |
| Messaging | `google_pubsub`, `goaws`, legacy `localstack` |
| Observability | `otel_collector`, `jaeger`, `prometheus`, `grafana`, `loki`, `alloy` |

Declarations return service nodes. Pass those nodes to options such as `primary_database:` or to `connect`:

```ruby
Mobilis::DSL.generate("rack-example") do
  cache = redis("cache")
  app = rack("app")
  connect(from: app, to: cache)
end
```

`connect` records a directed dependency and supplies URL environment wiring. Plugins and service writers also generate type-specific code, including filtered ActiveResource clients and OpenTelemetry setup. See [Connection affordances](./connections.md) for exactly what each connection produces.

## Names and references

Node names normalize underscores to hyphens. `named` and string-based `connect` look up the original name passed to the DSL; node references avoid that distinction.

## Ruby dependencies and source

Rails and Rack nodes support `add_gem` for dependencies and `local_gem` / `use_local_gem` for generated shared libraries. See [Shared local gems](./local-gems.md) for paths, source files, and image builds.

Service nodes accept `write_file(path, content)` for generated source. The [example scripts](./examples.md) show service-specific configuration, observability connections, models, and HTTP migration routes.

## Kubernetes intent

Add `deploy_kubernetes` alongside service declarations to emit resources for the same realized environments. See [Kubernetes and Istio](./kubernetes.md).
