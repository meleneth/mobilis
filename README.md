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
