# Shared generation execution and parity

Mobilis owns the ordered generation pipeline in `Manifest#run_generation`. Native,
browser and legacy static entry points all use that pipeline. The
`Mobilis::Generation` executors implement capabilities, not duplicate phase
sequences:

| Capability | Native | Browser |
| --- | --- | --- |
| Initialize Git | git gem in `generate/` | isomorphic-git in a separate browser repository |
| Commit a phase | stage and commit working tree | send changed bytes and deletions to the browser Git adapter |
| Rails application | Rails builder Docker container | real Rails AppGenerator in Ruby WASM |
| Rails builder definition | write Dockerfile then build image | write same Dockerfile, no image build |
| After helper scripts | build test image, then plugin hooks/model/run-command phases | compatible plugin hooks only |
| Static API | n/a | same browser executor, discards Git checkpoints |
| Final workspace | working tree in `generate/` | completed generated repository ZIP with history |

The browser rejects unsupported host-dependent model and Rails options before
generation. It does not execute Docker or host shell commands. Browser Rails
also passes `--skip-ci` because Rails' CI template invokes host Git, and
`--skip-bundle --skip-git` to avoid host-dependent side effects and nested
Git history. Those choices can yield **real artifact differences** from native
Rails output. The framework generator itself is still real.

## Local verification

Run focused Ruby coverage first:

```bash
set -euo pipefail
bundle exec rspec \
  spec/mobilis/generation/execution_spec.rb \
  spec/mobilis/generation/compare_generated_projects_spec.rb \
  spec/mobilis/browser/generator_spec.rb \
  spec/mobilis/browser/capabilities_spec.rb
```

Then run the browser test against your rebuilt container:

```bash
docker compose up --build -d playground
cd playground
npm run test:git
PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080 \
  npx playwright test --grep "generates Rails, Redis and PostgreSQL"
```

## Compare real generated repositories

Generate the same DSL with the native CLI, then extract the browser's
`mobilis-project.zip` into a separate directory. Run:

```bash
ruby scripts/compare_generated_projects \
  /path/to/native/generate \
  /path/to/extracted/browser/project
```

The comparator inspects committed `HEAD` trees and commit messages, not
untracked files, ignored secret keys, or the working directory's incidental
contents. It reports each differing path and the entire commit-message
sequence, and exits nonzero if anything differs. It has **no implicit
ignore-list** for the expected Rails `--skip-ci` difference or for
Docker-dependent plugin phases.

The in-repository execution parity spec deliberately compares an
infrastructure-only PostgreSQL/Redis system without invoking Docker. That
proves the shared phase order and byte-equivalent intermediate trees for that
supported system; it does **not** prove byte-identical native/browser Rails
output. The full Rails browser acceptance test separately proves the generated
ZIP contains valid Git objects and phase history.

## Architectural boundaries

- **Mobilis** decides what files and services to generate, when phases
  complete, which hooks execute, and what commit messages mean.
- **Execution adapters** perform environment-specific side effects.
- **Diesl** exposes generic workspace, AST editing and Git affordances.
  Mobilis chooses repository roots and supplies its own generation context.
- **The generated Git repository** is separate from the authoring DSL
  workspace repository.

Future Diesl extraction should move only the repository-neutral Git
capability. It must not move Mobilis's commit timing, orchestration, or
repository-context decisions into Diesl.
