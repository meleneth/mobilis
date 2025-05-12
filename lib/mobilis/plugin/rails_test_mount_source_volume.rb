# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsTestMountSourceVolume < Mobilis::Base::Plugin
      extend Forwardable

      def hook_before_services_written
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_env.is_test?

          test_dir_path_env_var = realized_node.add_env_only_var("#{realized_node.name}_TEST_SOURCE_PATH",
                                                                 "./#{realized_node.name}")
          realized_node.add_volume(test_dir_path_env_var.env_var_ref, "/app", override: true)
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
