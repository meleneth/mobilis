# AGENTS.md

Guidance for coding agents working in this repository.

## Project Shape

Mobilis is a Ruby gem that scaffolds multi-service Docker Compose projects.

The main flow is:

1. `Mobilis::DSL` builds a high-level `Mobilis::System`.
2. `Mobilis::System` owns config nodes: user intent, environment-agnostic.
3. `Mobilis::Manifest` builds one `Mobilis::RealizedEnv` for each environment.
4. `Mobilis::RealizedEnv` turns config nodes into environment-specific realized nodes.
5. Plugins mutate realized nodes and may add additional realized services.
6. Service writers and compose/env emitters write the generated project under `generate/`.

Important entry points:

- `lib/mobilis.rb` loads the library.
- `lib/mobilis/dsl.rb` defines the user-facing DSL.
- `lib/mobilis/system.rb` serializes and hydrates config graphs.
- `lib/mobilis/manifest.rb` orchestrates materialization.
- `lib/mobilis/realized_env.rb` maps config node classes to realized node classes.
- `lib/mobilis/base/realized_node.rb` is the shared realized-node base.
- `lib/mobilis/plugin/*.rb` contains plugin hooks.
- `scripts/*.rb` are executable examples and smoke-test scenarios.

## Working Rules

- Prefer existing patterns over new abstractions. This project has a deliberate config-node vs realized-node split.
- Do not put environment-specific compose behavior on config nodes. Config nodes represent intent.
- Put generated-output details on realized nodes, compose helper classes, service writers, or plugins.
- Be careful with `Manifest#materialize`: it deletes and recreates `generate/`, initializes git there, commits generated files, builds Docker images, and runs Docker Compose commands.
- Do not run materialization casually in tests or inspection work.
- The normal test command is `bundle exec rspec`.
- On Windows/sandboxed environments, Bundler may need permission to run `git ls-files` from `mobilis.gemspec`.

## Plugin Lifecycle

`Manifest#initialize` runs:

1. `setup_plugins`
2. `generate_per_node_plugins`
3. `create_additional_services`

`Manifest#materialize` then runs:

1. `create_builder_images`
2. `hook_before_services_written`
3. service writers and compose files
4. `hook_after_services_written`
5. compose wrappers, env files, overrides, command files, helper scripts
6. `hook_after_dc_helpers`
7. `hook_create_rails_models`
8. `hook_after_rails_models_created`
9. `hook_run_commands`

There are two plugin shapes:

- `Mobilis::Base::Plugin`: manifest-wide plugin.
- `Mobilis::Base::RealizedNodePlugin`: plugin bound to one realized node.

Some plugins create more plugins. `RailsDBFanout` and `Plugerator` are examples. Hook order is important, so add tests when changing plugin setup or lifecycle behavior.

## AutoVivify

`Mobilis::AutoVivify` is used as a lazy tree for compose fragments, overrides, and service writer config.

The first operation determines node shape:

- `node[key]` or `node[key] = value` makes a hash-backed node.
- `node << value` makes an array-backed node.
- Mixing hash and array use raises `TypeError`.

Most output should go through `to_serial`, `symbolize_keys_deep`, or `clean_shrunk`.

Known sharp edges:

- `AutoNode#merge!` should be treated carefully with nested hashes. Existing tests cover some deep behavior, but missing nested keys under merged plain hashes may not auto-vivify.
- Direct JSON serialization of an array-backed `AutoNode` is not the primary path; serialize from the top-level `AutoVivify` instead.
- Compose helper classes should consistently honor `base:` when used for overrides. `Environment`, `Ports`, and `DependsOn` do; verify `Volume` behavior before relying on override merging.

## DSL Affordances

The public DSL currently uses block arguments:

```ruby
Mobilis::DSL.generate("generate") do
  rails("app", primary_database: postgres("app-db")) do |svc|
    svc.use_rspec!
    svc.add_rails_model("user") do |m|
      m.string "name"
    end
  end
end
```

Do not assume `instance_eval` style blocks work for service configuration.

Names are normalized on nodes by replacing `_` with `-`. Check raw input names vs normalized node names when touching `DSLContext#named` or `DSLContext#connect`.

## Known Issues To Keep In Mind

- `RefSlot#hydrate_refs!` appears to use literal interpolation strings for lookup keys. Current specs do not fully prove hydration from only serialized IDs.
- `System#resolve!` has suspicious `extra_depends_on` restoration over a hash; verify before relying on JSON round-trips for dependencies.
- `RealizedEnv#build_realized_node` uses an explicit class map. Adding a node class also requires adding its realized mapping.
- `GoAws` has DSL-ish helpers, but verify its internal arrays are initialized before using `queue`, `topic`, or `subscribe`.
- `TODO.md` currently lists short tactical items, including the `rspec:install` issue.

## Planning Convention

Keep `AGENTS.md` for stable project guidance and known traps.

Use `TODO.md` for the small active backlog. If a plan grows beyond a few lines, create a dated note under `notes/` or a focused design document, then link it from `TODO.md`.

Suggested format for larger plans:

- Problem
- Current behavior
- Proposed change
- Test strategy
- Open questions

Avoid burying multi-step implementation plans in `AGENTS.md`; stale plans make future agents worse.
