target :lib do
  signature "sig"
  check "lib"

  ignore "spec/**/*"

  # Generated-output layers are still covered by specs, but their plugin hooks,
  # delegated helpers, and compose mutation DSL need a more deliberate typing pass.
  ignore "lib/mobilis/manifest.rb"
  ignore "lib/mobilis/plugin/**/*"
  ignore "lib/mobilis/realized/postgresql.rb"
  ignore "lib/mobilis/realized/rails.rb"
  ignore "lib/mobilis/realized/sql_database.rb"


  library "fileutils"
  library "singleton"
  library "forwardable"
  library "logger"
  library "open3"
  library 'yaml'
  library "json"
  library "socket"
end
