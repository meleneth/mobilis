# frozen_string_literal: true

require "shellwords"

module Mobilis
  module Plugin
    class RubyGems < Mobilis::Base::Plugin
      def hook_after_services_written
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_env.is_test?

          gem_dependencies(realized_node).each do |model|
            directory_service.chdir_generate
            rails_builder.container_run(
              Shellwords.join(["bundle", "add", *model.bundle_add_args]),
              workdir: realized_node.name
            )
            commit_all "#{realized_node.name} add gem #{model.name}"
          end
        end
      end

      def rails_builder
        builder = @manifest.plugin_for Mobilis::Plugin::RailsBuilder
        raise "RailsBuilder plugin is required to add Ruby gems" unless builder.is_a?(Mobilis::Plugin::RailsBuilder)

        builder
      end

      def gem_dependencies(realized_node)
        ruby_gems = [] #: Array[Mobilis::Model::RubyGem]
        realized_node.config_node.models.each do |model|
          ruby_gems << model if model.is_a?(Mobilis::Model::RubyGem)
        end
        local_gems = realized_node.config_node.local_gems.map(&:gem_dependency)
        ruby_gems + local_gems
      end
    end
  end
end
