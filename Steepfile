target :lib do
  signature "sig"
  check "lib"

  ignore "spec/**/*"

  # Generated-output layers are still covered by specs, but their plugin hooks,
  # delegated helpers, and compose mutation DSL need a more deliberate typing pass.
  ignore "lib/jobes_war/**/*"
  ignore "lib/mobilis/auto_vivify.rb"
  ignore "lib/mobilis/cli.rb"
  ignore "lib/mobilis/file_lines.rb"
  ignore "lib/mobilis/manifest.rb"
  ignore "lib/mobilis/mixins/**/*"
  ignore "lib/mobilis/base/plugin.rb"
  ignore "lib/mobilis/base/realized_node.rb"
  ignore "lib/mobilis/base/realized_node_plugin.rb"
  ignore "lib/mobilis/base/service_writer.rb"
  ignore "lib/mobilis/plugin/**/*"
  ignore "lib/mobilis/pretty_print/**/*"
  ignore "lib/mobilis/realized/**/*"
  ignore "lib/mobilis/realized_env.rb"
  ignore "lib/mobilis/service_writer/**/*"
  ignore "lib/mobilis/system.rb"
  ignore "lib/mobilis/util/**/*"
  ignore "lib/mobilis/yaml.rb"
  ignore "lib/mobilis/ref_slot.rb"


  library "fileutils"
  library "singleton"
  library "forwardable"
  library "logger"
  library 'yaml'
  library "json"
  library "socket"
end
