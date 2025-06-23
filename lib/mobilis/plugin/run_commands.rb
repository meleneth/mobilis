# frozen_string_literal: true

require "shellwords"

module Mobilis
  module Plugin
    class RunCommands < Mobilis::Base::Plugin
      def hook_run_commands
        @manifest.each_node_of_type(Mobilis::Base::RealizedNode) do |realized_env, realized_node|
          realized_node.each_model_of_type(Mobilis::Model::RunCommand) do |model|
            next unless realized_env.is_test?

            directory_service.chdir_generate

            cmd_args = [
              "./dc_test",
              "run", "--rm", "--entrypoint", "", realized_node.name,
              *Shellwords.split(model.command)
            ]

            Mobilis::Util.run_command(cmd_args)
            commit_all "#{realized_node.name} - #{model.commit_message}" if model.commit_message
          end
        end
      end
    end
  end
end
