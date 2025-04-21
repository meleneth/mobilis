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

      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[k.to_s] = deep_stringify_keys(v)
          end
        when Array
          obj.map { |e| deep_stringify_keys(e) }
        else
          obj
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
