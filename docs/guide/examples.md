# Example scripts

The `scripts/` directory is the active executable documentation for the DSL.
Run any demo with:

```sh
bundle exec ruby -Ilib scripts/<demo>.rb
```

Then inspect or run the generated project under `generate/`.

| Script                                        | Demonstrates                                                                                                                                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`01_mobilis_initial_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/01_mobilis_initial_system.rb)                | Minimal Rails service with PostgreSQL.                                                                                                                                                 |
| [`02_mobilis_otel_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/02_mobilis_otel_system.rb)                   | Standalone observability stack: Grafana, Loki, Alloy, OpenTelemetry collector, Jaeger, and Prometheus.                                                                                 |
| [`03_flask_otel_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/03_flask_otel_system.rb)                     | Flask service with the observability stack.                                                                                                                                            |
| [`04_big_multirails_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/04_big_multirails_system.rb)                 | Multiple Rails API services with separate PostgreSQL databases and service-to-service wiring.                                                                                          |
| [`05_rails_otel_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/05_rails_otel_system.rb)                     | Rails service with PostgreSQL and full observability wiring.                                                                                                                           |
| [`06_rails_graphql_otel.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/06_rails_graphql_otel.rb)                    | Rails API service with GraphQL, generated model affordances, PostgreSQL, and OpenTelemetry.                                                                                            |
| [`07_flask_redis.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/07_flask_redis.rb)                           | Flask service connected to Redis.                                                                                                                                                      |
| [`08_large_iam_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/08_large_iam_system.rb)                      | Larger IAM-oriented system with Rails API services, filtered ActiveResource affordances, GoAWS SNS/SQS, Redis, and observability.                                                      |
| [`09_just_localstack.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/09_just_localstack.rb)                       | Legacy LocalStack-only smoke scenario. New queue demos should prefer GoAWS.                                                                                                            |
| [`10_rails_tailwind_site.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/10_rails_tailwind_site.rb)                   | Rails site setup with Tailwind.                                                                                                                                                        |
| [`11_add_group_service_to_large_iam_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/11_add_group_service_to_large_iam_system.rb) | Focused IAM slice adding a group service with GraphQL and observability.                                                                                                               |
| [`12_chaos_management_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/12_chaos_management_system.rb)               | Larger Rails application example with richer generated app code.                                                                                                                       |
| [`13_orinoco.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/13_orinoco.rb)                               | Orinoco Rails service connected to PostgreSQL and GoAWS.                                                                                                                               |
| [`14_postgres_replication.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/14_postgres_replication.rb)                  | PostgreSQL replication DSL: `replicate_from(primary)`.                                                                                                                                 |
| [`15_pgadmin_postgres.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/15_pgadmin_postgres.rb)                      | pgAdmin wired to generated PostgreSQL.                                                                                                                                                 |
| [`16_s3_storage.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/16_s3_storage.rb)                            | S3-compatible object storage using SeaweedFS.                                                                                                                                          |
| [`17_observable_s3_storage.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/17_observable_s3_storage.rb)                 | SeaweedFS-backed S3 storage with conditional observability wiring, Prometheus scraping, and Grafana panels.                                                                            |
| [`18_mnbme_otel_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/18_mnbme_otel_system.rb)                     | Rack microservice game demo extracted from MNBME: local gem support, Rack Docker image support, replicated service instances, Redis game state, and OpenTelemetry/Grafana/Loki wiring. |
| [`19_two_rails_local_gem.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/19_two_rails_local_gem.rb)                   | Two Rails services consuming one generated local gem, including per-service Docker build-context handling.                                                                            |
| [`20_http_migration.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/20_http_migration.rb) | FastAPI and Go behind Envoy: live migration controls, trusted request shadow context on one Go candidate, SQL meaning/binding and committed-effect OTEL verification, and a standalone generated `./demo` (defaults to development; select with `MOBILIS_ENV`). |
| [`21_kubernetes_initial.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/21_kubernetes_initial.rb) | Rails and observability deployed to Devastation Kubernetes through Istio. Generates Compose plus dev/test/prod Kubernetes resources and a registry-backed deployment helper. |
| [`22_cassandra.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/22_cassandra.rb) | Single-node Cassandra with schema initialization and a native client write/read example. |
| [`23_google_pubsub.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/23_google_pubsub.rb) | Official Google Pub/Sub emulator, publisher, independent pull subscriptions, competing consumers, redelivery, and a generated integration runner. |

The [Kubernetes guide](./kubernetes.md) documents deployment,
project-first hostnames, private services, and end-to-end telemetry verification.

The HTTP demo's [operator guide](https://github.com/meleneth/mobilis/blob/core/scripts/http_migration/README.md) documents environment selection and expected error checks. Its actual Jaeger/OTEL correctness verifier is [scripts/http_migration/operations.py](https://github.com/meleneth/mobilis/blob/core/scripts/http_migration/operations.py), generated as `legacy/demo/operations.py`; start with `verify()`, `await_trace()`, and `check_trace()`.

The most complete current smoke demos are [`08_large_iam_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/08_large_iam_system.rb) for Rails
service composition and [`18_mnbme_otel_system.rb`](https://github.com/meleneth/mobilis/blob/core/scripts/18_mnbme_otel_system.rb) for Rack/local-gem/multi-
instance behavior.
