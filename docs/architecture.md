# Architecture

Generation flows through these layers:

```text
Ruby DSL → System / config nodes
         → Manifest
         → RealizedEnv for test, development, production
         → realized nodes + plugins
         → service writers, Compose/env emitters, optional Kubernetes generator
         → generated project
```

The system graph represents intent. Environment-specific output belongs to realized nodes, plugins, and writers. After generation, ordinary tools own the project's development and runtime lifecycle.

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

Plugins transform the RealizedEnv graph. For example:

"Rails needs three extra databases — but only in production — so replicate the primary database node, swap names, and wire them up."

This separation of concerns allows config nodes to stay clean and intent-focused, while plugins handle derived structure and conditional complexity.

## AutoVivify

This is not your standard auto-vivifying hash. Instead of defaulting to nested hashes on access, the behavior adapts based on how the value is first used.

If the first thing done to a key is <<, it becomes an array. If it’s accessed with [], it becomes a hash. Do not mix hash and array operations on the same node: that raises `TypeError`. Serialize output through `to_serial`, `symbolize_keys_deep`, or `clean_shrunk`.
