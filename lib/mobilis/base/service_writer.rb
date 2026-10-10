require "yaml"

module Mobilis
  module Base
    class ServiceWriter
      include Mobilis::PrettyPrint::PrettyPrintable
      extend Forwardable

      attr_reader :manifest, :realized_env, :realized_node

      def_delegators :@manifest, :directory_service, :username, :commit_all

      def initialize(manifest, realized_env, realized_node)
        @manifest = manifest
        @realized_env = realized_env
        @realized_node = realized_node
      end

      def write
        raise "strange to have a ServiceWriter that doesn't override #write"
      end

      # Stamp Dockerfiles owned by this generator, never upstream images.
      def write_image_ownership
        return unless realized_node.compose_build_context

        File.open("Dockerfile", "a") do |file|
          file.puts "\nLABEL org.opencontainers.image.vendor=\"Mobilis\""
          file.puts "LABEL mobilis.project=#{realized_node.meta_project_name.to_json}"
          file.puts "LABEL mobilis.service=#{realized_node.name.to_json}"
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", @manifest
        dsl.child_object "realized_env", @realized_env
        dsl.child_object "realized_node", @realized_node
      end
    end
  end
end
