# Mobilis - Service Oriented Architecture scaffolding

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

Currently, it only works with Ruby on Rails and Postgres.
It used to work with more, but mainenance burden and dirty
core implementation necessitated a full rewrite.

look at scripts/mobilis_initial_system.rb

bundle exec ruby scripts/mobilis_initial_system.rb

this will build a codebase in the 'generate' directory.

There should be documentation for the project in the README.me
in that directory, but let's look at some high level highlights:

In the test environment, the 'user' rails project has it's source
files volume mounted in the docker container.

In the production environment, there are 4 databases wired up to
the 'user' rails project. This is because rails needs the extra
databases in production. These are all wired up, and should be
ready to go.

The databases are all stored in local files, not volumes -
it is expected for Actual Production you will be using externally
managed databases, use something like Vault for your env file
juggling. But out of the box, you can build as if this stuff
exists and it's a small step to get there.

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
