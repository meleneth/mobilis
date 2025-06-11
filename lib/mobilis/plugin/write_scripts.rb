# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Plugin
    class WriteScripts < Mobilis::Base::Plugin
      def hook_after_dc_helpers
        @manifest.each_node_of_type(Mobilis::Base::RealizedNode) do |realized_env, realized_node|
          realized_node.each_model_of_type(Mobilis::Model::Script) do |model|
            next unless realized_env.is_test?

            directory_service.chdir_project(realized_node)
            FileUtils.mkdir_p "scripts"
            Dir.chdir "scripts"
            model.write_file
            commit_all "Add script #{realized_node.name} #{model.filename}"
          end
        end
      end
    end
  end
end
