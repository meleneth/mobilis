# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin creates rails models defined on rails services
    class GraphQLRailsIntegration < Mobilis::Base::RealizedNodePlugin
      def rails_builder
        manifest.plugin_for Mobilis::Plugin::RailsBuilder
      end

      def hook_after_services_written
        directory_service.chdir_project(realized_node)
        rails_builder.container_run("bundle add graphql")
        directory_service.chdir_generate
        commit_all("#{realized_node.name} - add GraphQL gem")
      end

      def hook_after_rails_models_created
        realized_node.each_model_of_type(Mobilis::Model::Rails::GraphQL) do |model|
          Mobilis::Util.run_command(["./dc_test", "build"])
          Mobilis::Util.run_command([
                                      "./dc_test",
                                      "run", "--rm", "--entrypoint", "", realized_node.name,
                                      "bundle", "exec", "rails", "generate", "graphql:install"
                                    ])
          commit_all("#{realized_node.name} - install GraphQL gem")
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
