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
        File.binwrite("tmp_install_graphql.sh", <<~HERE)
          #!/usr/bin/env bash
          set -exuo pipefail
          bundle add graphql
          bundle install
          bundle exec rails generate graphql:install
          bundle install
          rm tmp_install_graphql.sh
        HERE

        rails_builder.container_run("/bin/bash tmp_install_graphql.sh")

        directory_service.chdir_generate
        commit_all("#{realized_node.name} - add and install GraphQL gem")
      end

      def hook_after_rails_models_created
        realized_node.each_model_of_type(Mobilis::Model::Rails::GraphQL) do |model|
          Mobilis::Util.run_command(["./dc_test", "build"])
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
