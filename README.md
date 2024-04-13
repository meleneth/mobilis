# Mobilis

Mobilis is a ruby app for generating linked sets of docker containers, for rapid
prototyping of arbitrary project architecture.

It has some smarts built in to make common things simple, and will allow you to
further customize the output for more complex needs.

## Installation

    $ gem install mobilis

## Usage

    $ mobilis

This will start the console based user interface.

Add projects of the various kinds.  The input doesn't save you from mistakes
like entering spaces for service names, so don't do it.

Do not use dashes or underscores for database names.  Underscores are invalid in hostnames,
and dashes are invalid in ??? yaml keys?

If you need any containers to connect to other containers via the internal
names, you will want to add a link from the project that is connecting to the
project that is being connected to.

When configured to your liking, select the generate option to generate the
projects.  This will *DESTROY* any data in an existing 'generate' directory.

# Generated Projects
generated projects will have multiple root compose files generated, with 
filenames like compose-development.yml and compose-production.yml

These are skeletons that along with compose/development.env and compose/production.env
and a .yml per service, are used to generate the overall compose config.

this command will show the config for user-service in the development environment:

docker compose -f compose-development.yml config user-service

You can also bring individual services up:
docker compose -f compose-development.yml up user-service

or all the services at once:
docker compose -f compose-development.yml up

## LocalGem support
If you make and link a localgem project, the base directory for the service's 
build context will change.  This is all integrated and generated for you.
What is not integrated is updating the .gemspec file so it will actually build.
I feel comfortable giving you insecure username / password to the generated 
data services since those are obvious to fix and cannot be deployed without being
thought about, but if you want to cheat on the .gemspec you'll need to
  gem install mel-minion
  cd my-localgem-directory
  minion mumble my-localgem.gemspec

## assigned port numbers
Port numbers for all the environments are auto-generated.  You can edit the port
assignments in the per-environment configuration.  The services communicate
internally via the internal hostnames and ports.

## per-environment configurations
Env vars are defined in compose/development.env etc.

These are not directly used in the containers, but are referenced in the .yml
files with the ${COMPOSE_VAR_NAME} syntax.

## Special Rails support
If a Ruby on Rails project is linked to a postgres or mysql instance, it will
be setup with a DATABASE_URL environment variable that has the connection
information.

In addition, the database instance will receive a environment variable with the
name of the default production database that is based on the rails project's name

## Security
The generated projects are insecure, because of credential handling details.

If you want to deploy the projects into a production environment, you are
responsible for secrets management.

This will look like encrypting the secrets in the per-env configuration,
which will need to be modified for actual production deployments anyways.

RAILS_MASTER_KEY is set in each rails project, you'll want to handle that.

# Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Meleneth/mobilis.

# Plans

- Adding more project types + smart integrations
- Instrumenting generated projects with New Relic
- Smoothing out the flow of the UI
- Be able to load a previous configured set of projects for further editing
- ~~Make generated rails projects wait at startup until the database is usable~~
- More details in TODO.md
