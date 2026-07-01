# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Plugin
    class EnvVars < Mobilis::Base::Plugin
      def hook_before_services_written
        @manifest.each_node_of_type(Mobilis::Base::RealizedNode) do |realized_env, realized_node|
          realized_node.each_model_of_type(Mobilis::Model::EnvVarAlias) do |model|
            suppress_matching_dependency_url(realized_node, model.service_name)
            realized_node.add_compose_aliased_var(model.local_name,
                                                  model.service_name,
                                                  false,
                                                  is_alias_only: true)
          end
        end
      end

      private

      def suppress_matching_dependency_url(realized_node, envfile_name)
        matching = realized_node.compose_environment.data.find do |emit_var|
          emit_var.envfile_name == envfile_name.to_s.upcase.tr("-", "_") &&
            emit_var.container_name&.end_with?("_URL")
        end
        realized_node.compose_environment.data.delete(matching) if matching
      end
    end
  end
end
