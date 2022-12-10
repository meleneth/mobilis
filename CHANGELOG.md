## [Unreleased]

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
