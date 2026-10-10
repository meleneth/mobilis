# OpenTelemetry and observability

Mobilis can generate application tracing, a Collector, Jaeger, Prometheus, Loki, Alloy, and Grafana. Traces, metrics, and logs follow different paths; adding a Collector does not automatically make every application emit all three signals.

## Wire the stack

This complete Rails example uses the conventional names expected by the Ruby and default Prometheus writers:

```ruby
require "mobilis"

Mobilis::DSL.generate("observed-app") do
  app = rails("app", primary_database: postgres("app-db"))
  collector = otel_collector("otel-collector")
  traces = jaeger("jaeger")
  metrics = prometheus("prometheus")
  logs = loki("loki")
  dashboard = grafana("grafana")
  alloy("alloy", loki: logs)

  connect(from: app, to: collector)
  connect(from: collector, to: traces)
  connect(from: metrics, to: collector)
  connect(from: dashboard, to: metrics)
  connect(from: dashboard, to: logs)
end
```

| Signal | Generated path |
| --- | --- |
| Application traces | Application → OTLP Collector → Jaeger |
| OTLP metrics, if emitted | Application → Collector Prometheus exporter → Prometheus |
| Container logs | stdout/stderr → Alloy → Loki |
| Queries and exploration | Grafana → provisioned Jaeger, Prometheus, and Loki data sources |

Grafana discovers supported data sources across the realized environment; its provisioning is not limited to directly connected services. The generated dashboards include overview and filtered ActiveResource panels when their panel prerequisites exist. Application-specific metrics still need application instrumentation and appropriate scrape jobs.

## Rails: what the connection installs

Connecting Rails to an OTEL Collector creates an integration plugin. During scaffolding it adds `opentelemetry-sdk`, `opentelemetry-instrumentation-all`, and `opentelemetry-exporter-otlp`, then writes:

| File | Purpose |
| --- | --- |
| `config/initializers/opentelemetry.rb` | Configure service name, available automatic instrumentation, and a batched OTLP HTTP trace exporter |
| `lib/instrumentation.rb` | Expose `Instrumentation.trace(name, attributes: {})` for application spans |
| `config/initializers/structured_logging.rb` | Write JSON logs to stdout with service name and active trace/span IDs |

`use_all` enables available instrumentation for libraries the application uses. Add meaningful spans around your own operations:

```ruby
Instrumentation.trace("demo.user.lookup", attributes: { account_id: 7 }) do
  Rails.logger.info("Looking up users")
  User.where(account_id: 7).to_a
end
```

The helper converts attribute keys to strings. The JSON formatter includes `timestamp`, `severity`, `service_name`, `progname`, and `message`; valid active spans add `trace_id` and `span_id`. Logging outside an active span has no trace IDs. Logs reach Loki through Alloy, not an OTLP log exporter.

The integration is installed once using the test realized node during generation; the emitted application files are shared by the generated environments.

## Rack, FastAPI, Go, Envoy, and Flask

| Service | Current generated instrumentation |
| --- | --- |
| Rack connected to Collector | `config/otel.rb`, SDK/exporter/instrumentation gems, `use_all`, batched HTTP traces, and startup preload |
| FastAPI connected to Collector | FastAPI, HTTPX, requests, and PostgreSQL SQLAlchemy instrumentation when a database is connected; W3C trace context and baggage |
| Go HTTP connected to Collector | Batched HTTP trace exporter, inbound/outbound HTTP instrumentation, and PostgreSQL `otelpgx` instrumentation when connected |
| Envoy connected to Collector | OpenTelemetry listener tracing using the Collector's gRPC endpoint |
| Legacy Flask scaffold | Always emits Flask/requests tracing to `otel-collector:4317` with fixed service name `flask-api-otel-demo`; this is not connection-driven |

Rack sets `OTEL_TRACES_EXPORTER=otlp`, `OTEL_METRICS_EXPORTER=none`, and `OTEL_LOGS_EXPORTER=none`. Its default setup exports traces, not application metrics or structured logs. FastAPI and Go telemetry setup is likewise focused on tracing. Do not infer full metrics/log pipelines from their Collector connections.

## Collector endpoints and configuration

The emitted `<collector>/otel-collector-config.yaml` listens on:

| Endpoint | Use |
| --- | --- |
| `4317` | OTLP gRPC receiver |
| `4318` | OTLP HTTP receiver; trace exporters use `/v1/traces` |
| `9464` | Prometheus exporter for received OTLP metrics |

The trace pipeline uses batch and memory-limiter processors, exporting via OTLP gRPC to the connected Jaeger. With no Jaeger edge it falls back to `jaeger:4317`; more than one connected Jaeger is rejected. The generated local export uses insecure transport. The metrics pipeline batches incoming OTLP metrics and exposes them for Prometheus scraping. There is no Collector log pipeline.

### Names and exporter variables

FastAPI and Go HTTP select the connected Collector's URL and generate `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`, and `OTEL_PROPAGATORS=tracecontext,baggage`. They accept at most one connected Collector.

Rails uses `OTEL_EXPORTER_OTLP_ENDPOINT` if present, otherwise `http://otel-collector:4318`, and appends `/v1/traces`. Its service name comes from the generated node name. The generic connection URL (for example `OTEL_COLLECTOR_URL`) alone does not change that exporter variable. For a differently named Collector, explicitly alias its named exported endpoint on the Rails node:

```ruby
collector = otel_collector("telemetry")
app = rails("app") do |service|
  service.env_var_alias("OTEL_EXPORTER_OTLP_ENDPOINT",
                        "telemetry_otel_exporter_otlp_endpoint")
end
connect(from: app, to: collector)
```

Rack currently sets its exporter endpoint to `http://otel-collector:4318` even if connected to a differently named Collector. The default Prometheus writer scrapes `otel-collector:9464`. Use the conventional Collector name for those defaults, or adjust the generated configuration and environment explicitly.

## Metrics, logs, and Grafana

Prometheus defaults to a **60-second** scrape interval. Its Collector job scrapes `otel-collector:9464`. That endpoint exposes received metrics; it does not turn collected traces into metrics. The Kubernetes demo additionally supplies an application `/metrics` scrape job. Observable SeaweedFS nodes receive their own scrape jobs and Grafana panels.

Compose Alloy reads Docker container logs through the Docker socket, filtering the generated project's test/development/production containers. It attaches service and Compose labels and forwards logs to the Loki supplied through `alloy(..., loki: logs)`. In Kubernetes, Alloy reads pod logs through namespace-scoped API permissions. See [Kubernetes and Istio](./kubernetes.md).

Grafana provisions its sources and dashboards under `<grafana>/provisioning/`. Generated local demo credentials are `admin` / `mobilis-admin`. Jaeger uses an in-memory backend, so trace history is not durable across its restart. [Storage and ownership](./storage.md) explains persistence for the other backends.

## Run and verify

The [Rails tracing demo](https://github.com/meleneth/mobilis/blob/core/scripts/05_rails_otel_system.rb) supplies a task that creates application spans:

```sh
bundle exec ruby -Ilib scripts/05_rails_otel_system.rb
cd generate
./dc_test up -d
./dc_test run user-service bundle exec rake demo:trace
./dc_test logs otel-collector jaeger alloy
```

Use the generated README and environment files to find published UI ports. In Jaeger, select `user-service` and look for `demo.user.create`. In Grafana Explore, use the Loki source to find service logs and inspect their JSON trace IDs. Allow batched traces and at least one Prometheus scrape interval before expecting telemetry to appear.

If traces are missing, check the application's exporter endpoint and service name, Collector logs, the Collector → Jaeger target, and receiver protocol/port. If metrics are missing, verify the application emits metrics and that Prometheus has a scrape job for their endpoint. If logs are missing, inspect Alloy's discovery labels and Loki endpoint independently of the trace pipeline.

The [HTTP migration operator guide](https://github.com/meleneth/mobilis/blob/core/scripts/http_migration/README.md) describes trace-aware correctness checks for FastAPI/Go/Envoy. The [Kubernetes guide](./kubernetes.md) documents the live endpoint, trace, counter, and log verifier.
