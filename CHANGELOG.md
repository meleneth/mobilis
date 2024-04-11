## [Unreleased]
- I scaffolded 19 services today and they started right up and everything migrated on boot and everything was amazing.
- Just thought someone should know.  I did cheat and use minion mumble before the build on the localgem, but cheating is amazing.
- when scaffolding models, the test db containers will be spun up since rails talks to the db at scaffold time
- generated compose is now multiple files, allowing for multiple environment deployments for groups of related services
- a huge amount of refactoring of the main FSM.  Everything is likely broken, but tests are coming
- changed uid / gid to hardcoded value of '200' in the rails builder image
  to let it work in Windows.  Will need to re-test linux and mac
- multiple db support is hosed.  Need non-destructive YAML editing before it is really fixable
- minor markdown syntax fixes
- FSM tests
- bugfixes in interactive designer

## [0.0.5] - 2022-12-09
- fixed a bug when loading a project that made the rails builder not update
- fixed permissions of wait-until, which means rails projects will wait until the database
  is available to run migrations and start the server
- reworked a lot of the screens to be less cluttered and make more sense
- fixed unit tests to not hardcode my username in the test
- bumped redis version

## [0.0.4] - 2022-09-11

- Added command line options load and build
- Added wait-until to rails w/postgresql or mysql to wait for the db to be ready before starting rails
- Fixed per-state display not working
- Use table_print to display some information such as linked projects

## [0.0.1] - 2022-06-26

- Initial release
