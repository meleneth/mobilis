# Generated projects

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

## Working with environments

| Wrapper | Environment |
| --- | --- |
| `./dc_test` | test |
| `./dc_dev` | development |
| `./dc_prod` | production |

Wrappers accept Docker Compose commands such as `build`, `up -d`, `logs`, `ps`, and `down`. Read the emitted Compose files and project README for exact mounts, ports, and commands. Generated files belong to the project owner after generation.

For Kubernetes state and ownership, see [Storage and ownership](./storage.md).
