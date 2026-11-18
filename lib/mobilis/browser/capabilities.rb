# frozen_string_literal: true

module Mobilis
  module Browser
    class Capabilities
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
          next unless node.models.any? { |model| model.is_a?(Mobilis::Model::RunCommand) }

          result[node.name] = Mobilis::GeneratorCapabilities.local_only(
            "This service declares a host command that the browser cannot execute."
          )
        end
      end

      def self.project(system)
        incompatible = for_system(system).values.reject(&:browser_generation)
        return Mobilis::GeneratorCapabilities.browser if incompatible.empty?

        Mobilis::GeneratorCapabilities.local_only(incompatible.map(&:reason).uniq.join(" "))
      end
    end
  end
end
