# frozen_string_literal: true

module Mobilis
  module Base
    class RealizedNodePlugin
      include Mobilis::PrettyPrint::PrettyPrintable
      include Mobilis::Mixins::Plugin::HasPluginEvents
      extend Forwardable

      def_delegators :@manifest, :directory_service, :username
      def_delegators :realized_node, :realized_env

      attr_reader :manifest, :realized_node

      def initialize(manifest, realized_node)
        @manifest = manifest
        @realized_node = realized_node
      end
    end
  end
end
