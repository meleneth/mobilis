# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Plugin
    class WriteFiles < Mobilis::Base::Plugin
      def hook_after_dc_helpers
        @manifest.each_node_of_type(Mobilis::Base::RealizedNode) do |realized_env, realized_node|
          realized_node.each_model_of_type(Mobilis::Model::File) do |model|
            next unless realized_env.is_test?

            directory_service.chdir_project(realized_node)
            model.write_file
            commit_all "#{realized_node.name} add file - #{model.path}"
          end
        end
      end
    end
  end
end
