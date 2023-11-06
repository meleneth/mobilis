# Currently Burning
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
# Modules
- add docker registry support (i.e. the docker container to host a docker registry)
# Javascript
- Vue.js app generator
- javascript (and vue): be able to specify additional packages to depend on
- have some sets of different packages
# Ruby
- ruby FSM class designer - add states and transitions like links are made, then generate the FSM as a file
- add ruby-script-as-a-service (run a ruby script as a 'service')
- ruby (and rails): be able to specify additional gems to include
# Rails
- no matter if you create a db or a rails project first, the flow should be easy and obvious to add the other, associated with whatever you made first - this should be done as links from the pages, and will create the service AND link it to the origin
- rails: add interactive service designer (models / controllers)
- rails: add multi-db-at-once support
- rails: model support (schema, should support linking)
- rails: scaffold support (this is model + views)
- rails: controller support - should be able to setup args
- rails: add UUID primary key support.  Requires postgres DB, and no mysql or sqlite (redis is fine)
- rails: support setting puma / unicorn / falcon  For unicorn and puma, add settings for thread / process config
- rails: add scenic support for materialized vues
- rails: add graphql / graphiql support -> should be able to define an API service, and say what initial API should be
# Git
- fix git integration, we should have easy-to-read commit logs
- fix git integration so we have proper commit points between each step
# Done
- ~~make link flow not redirect back to main menu~~
- ~~fix having to restart several times to go through db create, db migrate, start service loop~~
- ~~add flask app~~
- ~~give some documentation for expected usage / security concerns~~
- ~~add ability to re-load old configuration~~
