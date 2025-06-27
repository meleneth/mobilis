# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Plugin
    class EnvVars < Mobilis::Base::Plugin
      def hook_before_services_written
        @manifest.each_node_of_type(Mobilis::Base::RealizedNode) do |realized_env, realized_node|
          realized_node.each_model_of_type(Mobilis::Model::EnvVarAlias) do |model|
            realized_node.add_compose_aliased_var(model.local_name,
                                                  model.service_name,
                                                  false,
                                                  is_alias_only: true)
          end
        end
      end
    end
  end
end
