# Getting started

Mobilis is a Ruby gem that scaffolds multi-service projects. Start from a repository example, then adapt its Ruby system definition to your services.

## Prerequisites

Install Ruby and Bundler, Git, and Docker with the Docker Compose plugin. Docker must be running: generation builds images and runs container commands, including application scaffolding.

## Generate the first example

```sh
git clone git@github.com:meleneth/mobilis.git
cd mobilis
bundle install
bundle exec ruby -Ilib scripts/01_mobilis_initial_system.rb
```

::: warning Generation replaces the output directory
Materialization deletes and recreates `generate/`, initializes Git there, commits generated files, builds images, and runs Compose commands. Save changes to an existing generated project before running a demo again. The argument to `DSL.generate` is the project name; demo output is written to `generate/`.
:::

The first demo generates Rails with PostgreSQL, RSpec support, and a user model. Start its test environment:

```sh
cd generate
./dc_test build
./dc_test up -d
./dc_test ps
```

Read the generated `README.md` for project-specific commands. Use `./dc_dev` for development and `./dc_prod` for production configuration. Stop the selected environment with its wrapper, for example `./dc_test down`.

## Next steps

Read [Writing a system](./dsl.md) for the DSL, [Generated projects](./generated-projects.md) for environment configuration, or choose an [example script](./examples.md).

Mobilis generates a project once. Continue development in that project with standard tools; generating again replaces the output rather than updating your application.
