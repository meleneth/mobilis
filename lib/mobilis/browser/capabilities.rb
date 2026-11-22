# frozen_string_literal: true

module Mobilis
  module Browser
    class Capabilities
      HOST_DEPENDENT_MODELS = [
        Mobilis::Model::RunCommand,
        Mobilis::Model::RubyGem,
        Mobilis::Model::Rails::Model,
        Mobilis::Model::Rails::GraphQL
      ].freeze

      def self.for_system(system)
        manifest = Mobilis::Manifest.new(system)
        writer_capabilities = manifest.realized_production_env.realized_nodes.map do |node|
          capability = if node.has_service_dir
                         node.service_writer.generator_capabilities
                       else
                         Mobilis::GeneratorCapabilities.browser
                       end
          [node.name, capability]
        end.to_h

        system.config_nodes.values.each_with_object(writer_capabilities) do |node, result|
          reasons = unsupported_reasons(node)
          if reasons.empty? && node.is_a?(Mobilis::Node::Rails)
            result[node.name] = Mobilis::GeneratorCapabilities.browser
          elsif !reasons.empty?
            result[node.name] = Mobilis::GeneratorCapabilities.local_only(reasons.join(" "))
          end
        end
      end

      def self.unsupported_reasons(node)
        reasons = node.models.filter_map do |model|
          "Browser cannot execute #{model.class} for #{node.name}." if model.is_a?(Object) && HOST_DEPENDENT_MODELS.any? { |klass| model.is_a?(klass) }
        end
        return reasons unless node.is_a?(Mobilis::Node::Rails)

        reasons << "Browser cannot bundle Rails local gems." unless node.local_gems.empty?
        %i[rspec_enabled? factory_bot_enabled? haml_enabled? tailwind_enabled?].each do |feature|
          reasons << "Browser does not support Rails #{feature} setup." if node.public_send(feature)
        end
        reasons << "Browser cannot generate Rails UUID migrations." if node.uuid_primary_keys
        reasons
      end

      def self.project(system)
        incompatible = for_system(system).values.reject(&:browser_generation)
        return Mobilis::GeneratorCapabilities.browser if incompatible.empty?

        Mobilis::GeneratorCapabilities.local_only(incompatible.map(&:reason).uniq.join(" "))
      end
    end
  end
end
