Trying to fix the permissions issue with initdb, specifically for postgres
Prototype for the solve for this works, which involves using the postgres image directly to create the db files, along with ro-mounting the /etc/passwd file from the host into the image.  Kinda gnarly, will clearly want a command line program to be able to 'do this' for any targettable selection of test, development, production environments per-dataservice.

Simple demo now builds and is startable.

Non simple demo fails because it's using the rails-builder image to run model scaffolds, which require access
to the dev database to be able to run.  Unsure why the single case works, probably don't wanna know.
So next is conversion of the scaffold calls being run in the container they are for.  This will require a build
of the container before we try to use it, but also gets weird because we'll want to be able to run a command
instead of the default container thing.  Wouldn't be a bad idea to be setup for that anyways, if we can figure
out a clean way of doing it.

so apparently

ENTRYPOINT [ "/myapp/entrypoint.sh" ]
CMD [ "rails", "server", "-p", "3000" ]

work together.  CMD existing interferes with being able to run 

docker run --rm -v /home/meleneth/code/devscene/drowning/generate/user-service:/myapp -w /myapp meleneth/user-service ./bundle_run.sh ./bin/rails g scaffold user name:string

but it works if the container is built with CMD commented out

which is pretty neat, I about jumped out of my chair when I generated my first scaffold with the rails inside the container that it was adding the scaffold to

Which works and is integrated now.


Moar FIRE
currently working up to the point of not generating different ports for different services to listen on.

Otherwise, things build.  OMG.


# Currently Burning

Working on getting the generated docker compose config to be multi file based.

Need to be able to support multiple environments with the same set of compose files.

Need to start the DB's for test and dev during generation - they should be running at initial rails create time.

How do we check that db's are up and ready to go?  a new invocation of the wait script is probably called for.

Need to fix file generation order.

Write compose.yml first, and supporting files.
As soon as those are written, make the data directory tree
as soon as the directory tree is made, build the DB containers and start them - for dev and test

Currently unresolved - having different ports for different environments

# Old Fires

the world.

Ok, a bit on the nose.
Anyways.

db files are getting created with user ownership issues.

Noodle - define DB container pieces in files, then include those in the main docker-compose files in order to support test/development/production/otherproduction environments
actually, extend that to everything - the main files should be references only

compose/service_name.yml
compose/somedb_test.yml
compose/somedb_production.yml
compose/somedb_development.yml
compose/somedb_otherproduction.yml
docker-compose.yml
docker-compose-development.yml
docker-compose-testdb.yml

name your meta project prompt to start with
Seeing what happens when trying to make a small complicated system
author-service post-service

# The Backlog
- make links look better ( table_print )
- write down every time a flow feels bad
- fix NR integration - .env file with details
- add a rack service wrapper that deploys as a sidecar (*handwave*)
- use graphviz to show a diagram for current metaproject
- be able to render k9s .yml in a specific namespace for easy deployment
- be able to cross build the entire project for pi-k9s deployment
- support creating files for SSL signing against internal generated certs that are integrated across the entire ecosystem - local dev needs https TOO
- add ability to generate a single project (should delete instance first)
- if generate/data exists already with data, have an option to keep or wipe the data
- add command line builder, so you can generate a tree based on an existing config
- in a complex config, it feels bad when the config gets big
- Add ability to convert the docker-compose file to a kubernetes .json (use existing tool, don't write this)
# Modules
- add docker registry support (i.e. the docker container to host a docker registry)
# Nexus
- integrate Nexus server support
# GitLab
- Integrate gitlab support, for running a locally hosted gitlab server.  With runner.
# Javascript
- Vue.js app generator
- javascript (and vue): be able to specify additional packages to depend on
- have some sets of different packages
- local npm package, just like local gem (build and install local without needing actual npm access)
- graphql server
# Rust
- add may-http generator, it's winning the shootout!
# LocalStack
- This is local runnable copies of AWS services for dev purposes.  Would be nice to use for prototyping
# CouchDB
- we know we like couchdb, so integrate it!
# Ruby
- ruby FSM class designer - add states and transitions like links are made, then generate the FSM as a file
- add ruby-script-as-a-service (run a ruby script as a 'service')
- ruby (and rails): be able to specify additional gems to include
# Rack
- Specify routes (w/params)
- pick apart existing rack projects to determine features - https://github.com/meleneth/mnbme/blob/master/gameservice/config.ru
- connecting to redis is nice, add it if the rack project is linked to a redis project
# Rails
- no matter if you create a db or a rails project first, the flow should be easy and obvious to add the other, associated with whatever you made first - this should be done as links from the pages, and will create the service AND link it to the origin
- rails: add interactive service designer (models / controllers)
- rails: add multi-db-at-once support
- rails: scaffold support (this is model + views)
- rails: controller support - should be able to setup args
- rails: add UUID primary key support.  Requires postgres DB, and no mysql or sqlite (redis is fine)
- rails: support setting puma / unicorn / falcon  For unicorn and puma, add settings for thread / process config
- rails: add scenic support for materialized views
- rails: add graphql / graphiql support -> should be able to define an API service, and say what initial API should be
- rails: make model designer easier to use
# Done
- ~~make link flow not redirect back to main menu~~
- ~~fix having to restart several times to go through db create, db migrate, start service loop~~
- ~~add flask app~~
- ~~give some documentation for expected usage / security concerns~~
- ~~add ability to re-load old configuration~~
- ~~The UI FSM is wildly overgrown.  Need to split it into multiple, task-specifc FSM's~~
## Git
- fix git integration, we should have easy-to-read commit logs
- fix git integration so we have proper commit points between each step
## Rails
- rails: model support (schema, should support linking)
# Postgres
- Add replication support (multi-db)
# History
# Danger continues
So the next really bad idea I had was storing everything as linked plain old ruby objects but then wrapping
them dynamically on the fly.  Makes mocking awful.
Currently refactoring back to actually have fat ruby objects storing fat ruby objects, and letting to_json handle
the wiring.

Restoring these is another matter, but the generating / saving is almost working.  Tests are going to have
my back here.

# Danger Will Robinson

the FSM split is seriously bad.
Need to refactor back to one giant FSM
but in different files, not all in one file
this thing is gigantic, and having everything
in one file cannot scale.
The test suite is the only thing that is going to make
this possible, but it's still going to be hella painful.
take it one tiny step at a time, and start by commenting out
the currently failing test.
