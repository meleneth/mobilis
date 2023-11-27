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

If you need any containers to connect to other containers via the internal
names, you will want to add a link from the project that is connecting to the
project that is being connected to.

When configured to your liking, select the generate option to generate the
projects.  This will *DESTROY* any data in an existing 'generate' directory.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Meleneth/mobilis.

## Plans

- Adding more project types + smart integrations
- Instrumenting generated projects with New Relic
- Smoothing out the flow of the UI
- Be able to load a previous configured set of projects for further editing
- ~~Make generated rails projects wait at startup until the database is usable~~
- More details in TODO.md
