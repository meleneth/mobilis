Mobilis treats the local distributed system as the primary development artifact.

# Mobilis - Service Oriented Architecture scaffolding

With Ruby and Docker installed:

```sh
git clone git@github.com:meleneth/mobilis.git
cd mobilis
bundle install
bundle exec ruby scripts/01_mobilis_initial_system.rb
cd generate
./dc_test build
./dc_test up -d
```

Each demo script writes a generated Docker Compose project into `generate/`.
Most scripts also build the containers as part of materialization. From
`generate/`, use `./dc_test`, `./dc_dev`, or `./dc_prod` to work with the
generated environments.

Initial setup for a service oriented project can be a pain.
Generating initial codebases, wiring them up via environment
variables to talk to each other, assigning ports to each one,
setting them up for multiple environments (test, development,
production), and starting with up to date versions for everything
is a lot to ask for before you even get to write any code for
your actual project.

The project dreams big - if it has a docker container, support
integrating it into a new setup via Docker Compose with very
little work.

## Demo Scripts

The `scripts/` directory is the active executable documentation for the DSL.
Run any demo with:

```sh
bundle exec ruby scripts/<demo>.rb
```

Then inspect or run the generated project under `generate/`.

| Script                                        | Demonstrates                                                                                                                                                                           |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_mobilis_initial_system.rb`                | Minimal Rails service with PostgreSQL.                                                                                                                                                 |
| `02_mobilis_otel_system.rb`                   | Standalone observability stack: Grafana, Loki, Alloy, OpenTelemetry collector, Jaeger, and Prometheus.                                                                                 |
| `03_flask_otel_system.rb`                     | Flask service with the observability stack.                                                                                                                                            |
| `04_big_multirails_system.rb`                 | Multiple Rails API services with separate PostgreSQL databases and service-to-service wiring.                                                                                          |
| `05_rails_otel_system.rb`                     | Rails service with PostgreSQL and full observability wiring.                                                                                                                           |
| `06_rails_graphql_otel.rb`                    | Rails API service with GraphQL, generated model affordances, PostgreSQL, and OpenTelemetry.                                                                                            |
| `07_flask_redis.rb`                           | Flask service connected to Redis.                                                                                                                                                      |
| `08_large_iam_system.rb`                      | Larger IAM-oriented system with Rails API services, filtered ActiveResource affordances, GoAWS SNS/SQS, Redis, and observability.                                                      |
| `09_just_localstack.rb`                       | Legacy LocalStack-only smoke scenario. New queue demos should prefer GoAWS.                                                                                                            |
| `10_rails_tailwind_site.rb`                   | Rails site setup with Tailwind.                                                                                                                                                        |
| `11_add_group_service_to_large_iam_system.rb` | Focused IAM slice adding a group service with GraphQL and observability.                                                                                                               |
| `12_chaos_management_system.rb`               | Larger Rails application example with richer generated app code.                                                                                                                       |
| `13_orinoco.rb`                               | Orinoco Rails service connected to PostgreSQL and GoAWS.                                                                                                                               |
| `14_postgres_replication.rb`                  | PostgreSQL replication DSL: `replicate_from(primary)`.                                                                                                                                 |
| `15_pgadmin_postgres.rb`                      | pgAdmin wired to generated PostgreSQL.                                                                                                                                                 |
| `16_s3_storage.rb`                            | S3-compatible object storage using SeaweedFS.                                                                                                                                          |
| `17_observable_s3_storage.rb`                 | SeaweedFS-backed S3 storage with conditional observability wiring, Prometheus scraping, and Grafana panels.                                                                            |
| `18_mnbme_otel_system.rb`                     | Rack microservice game demo extracted from MNBME: local gem support, Rack Docker image support, replicated service instances, Redis game state, and OpenTelemetry/Grafana/Loki wiring. |

The most complete current smoke demos are `08_large_iam_system.rb` for Rails
service composition and `18_mnbme_otel_system.rb` for Rack/local-gem/multi-
instance behavior.

## Generated Project

Each demo builds a codebase in the `generate/` directory.

The generated project includes its own `README.md`, Compose files,
environment files, helper scripts, and service source directories. In the test
environment, generated application services usually have their source files
mounted into the container for local iteration.

Production-oriented Rails demos may include the additional database roles Rails
expects for cache, cable, and queue storage. Mobilis wires those dependencies
into Compose so the generated project can start locally while still leaving a
clear path to externally managed infrastructure later.

Generated database and storage state is kept in local files under `generate/`.
For actual production deployments, use externally managed stateful services and
real secret management rather than the generated local env files.

## Container Environment Variables

Each environment (test, development, production) gets its own .env file, generated during materialization. This file contains all environment-specific variables needed by the containers — service URLs, ports, credentials, etc.

Mobilis uses a dual-name strategy for environment variables:

Resolved name: unique across the system, e.g., USERDB_POSTGRES_URL

Specific name: used inside the container, e.g., POSTGRES_URL

The Compose template references the resolved names (e.g., ${USERDB_POSTGRES_URL}), while the .env file provides their values. This allows each container to remain unaware of who it's talking to — it just reads POSTGRES_URL or similar, and Mobilis takes care of assigning it via Compose's environment: block.

All values are declared once per environment in the corresponding .env file, so you can inspect or override them easily during local dev, CI runs, or production deploys.

# Mobilis: The Crew Oath

We are the builders of vessels,
the shapers of motion within motion.

We craft not for conquest, nor for comfort alone,
but to reach shores unseen and ideas unspoken.

We do not fear entropy. We dance with it.
We carve order from chaos, and motion from stillness.

We are not passengers. We are not cargo.
_We are the crew._

Each of us brings tools, sparks, ideas.
Alone, we falter. Together, we forge paths through the unknown.

Our hands shape the hull. Our dreams drive the engine.
Our code is the rigging; our will, the wind.

We move within the moving.
Mobilis in mobili.

-- A fragment of starfire, carried aboard Mobilis at the will of Meleneth

# Internal Design

## Config Nodes (System)

Config nodes are the fundamental configuration primitive. They’re intentionally minimal — most are just a class and a name. They are environment-agnostic and exist solely to represent user intent at a high level.

Config nodes live inside a System object and are never modified during realization. They do not include any container or environment-specific details.

## Mobilis::Model

These are per-config-node configuration fragments. They are specific to each type of config node and are not top-level system objects. They live on Config nodes as an array config_node.models

Do not confuse these with general "models" — e.g., `Mobilis::Model::Rails::Model` represents a Rails table, but it exists only within a `Mobilis::Node::Rails`, not on its own.

A Rails model is a `Mobilis::Model::Rails::Model`, not a `Mobilis::Model`, and not a `Mobilis::Node`.

## Realized Nodes (RealizedEnv)

Realized nodes are where all the complexity lives. Each RealizedNode corresponds to a specific config node in a specific environment (e.g., test, development, production). These nodes contain everything needed to generate a working Docker Compose setup, including:

1. Resolved port numbers
1. Environment variable wiring
1. Volume mounts
1. depends_on relationships
1. Compose service definitions

Realized nodes are mostly declarative — but they can be mutated by plugins to reflect per-environment behavior.

## Plugins

Plugins are where the magic happens. They apply transformations to the RealizedEnv graph, making changes like:

"Rails needs three extra databases — but only in production — so replicate the primary database node, swap names, and wire them up."

This separation of concerns allows config nodes to stay clean and intent-focused, while plugins handle derived structure and conditional complexity.

## AutoVivify

This is not your standard auto-vivifying hash. Instead of defaulting to nested hashes on access, the behavior adapts based on how the value is first used.

If the first thing done to a key is <<, it becomes an array. If it’s accessed with [], it becomes a hash. This enables some spooky-action-at-a-distance-style DSL tricks, but it’s deliberate and tested. Use with care.
