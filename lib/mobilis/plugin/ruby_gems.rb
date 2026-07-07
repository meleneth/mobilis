# frozen_string_literal: true

require "shellwords"

module Mobilis
  module Plugin
    class RubyGems < Mobilis::Base::Plugin
      def hook_after_services_written
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_env.is_test?

          realized_node.each_model_of_type(Mobilis::Model::RubyGem) do |model|
            directory_service.chdir_project(realized_node)
            rails_builder.container_run(Shellwords.join(["bundle", "add", *model.bundle_add_args]))
            commit_all "#{realized_node.name} add gem #{model.name}"
          end
        end
      end

      def rails_builder
        builder = @manifest.plugin_for Mobilis::Plugin::RailsBuilder
        raise "RailsBuilder plugin is required to add Ruby gems" unless builder.is_a?(Mobilis::Plugin::RailsBuilder)

        builder
      end
    end
  end
end
