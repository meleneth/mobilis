target :lib do
  signature "sig"
  check "lib"

  ignore "spec/**/*"

  # Generated-output layers are still covered by specs, but their plugin hooks,
  # delegated helpers, and compose mutation DSL need a more deliberate typing pass.
  ignore "lib/jobes_war/**/*"
  ignore "lib/mobilis/manifest.rb"
  ignore "lib/mobilis/mixins/realized_node/has_data_volume.rb"
  ignore "lib/mobilis/base/service_writer.rb"
  ignore "lib/mobilis/plugin/**/*"
  ignore "lib/mobilis/pretty_print/**/*"
  ignore "lib/mobilis/realized/**/*"
  ignore "lib/mobilis/realized_env.rb"
  ignore "lib/mobilis/service_writer/**/*"


  library "fileutils"
  library "singleton"
  library "forwardable"
  library "logger"
  library "open3"
  library 'yaml'
  library "json"
  library "socket"
end
