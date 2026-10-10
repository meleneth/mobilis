# Contributing and documentation

## Ruby checks

From the repository root:

```sh
bundle install
bundle exec rspec
```

Follow [AGENTS.md](https://github.com/meleneth/mobilis/blob/core/AGENTS.md) for the config-node / realized-node boundary, plugin lifecycle, and materialization cautions. Tests and documentation inspection should avoid invoking full materialization casually.

## Run the documentation locally

Install Node.js 24 and npm, then run from the repository root:

```sh
npm ci
npm run docs:dev
```

Open the local URL printed by VitePress (with the `/mobilis/` base path). The stable VitePress 1.6.4 dependency uses a Vite 6.4.4 override to include upstream security fixes. Verify development and production builds when changing these versions.

Markdown lives in `docs/`; navigation, search, GitHub links, and the Pages base path are configured in `docs/.vitepress/config.mts`.

Before submitting a change:

```sh
npm run docs:check
npm run docs:preview
```

The production build checks Markdown links. `docs:check` also validates every emitted HTML link and fragment, including navigation, and checks README links against the published page paths. Open the preview to check page layout, navigation, and local search. Keep examples aligned with current Ruby code and specs. The numbered scripts remain executable examples; `notes/` holds dated design and verification records.

## GitHub Pages deployment

The documentation workflow builds pull requests targeting `core`, and builds and deploys pushes to `core`. It also supports manual dispatch. Deployment uses the GitHub Pages artifact and OIDC token, with write permissions confined to the deployment job.

Set the repository's **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. Do not use **Deploy from a branch**: that runs a separate Jekyll build that can overwrite the VitePress deployment with the repository README. The site is served at [meleneth.github.io/mobilis](https://meleneth.github.io/mobilis/). No custom domain is configured.

The `/mobilis/` base path must change if hosting moves to a custom domain or another repository. No Ruby scaffolding or Docker materialization is run by the documentation workflow.
