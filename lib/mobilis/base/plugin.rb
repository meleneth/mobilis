# frozen_string_literal: true

module Mobilis
  module Base
    class Plugin
      include Mobilis::PrettyPrint::PrettyPrintable
      include Mobilis::Mixins::Plugin::HasPluginEvents
      extend Forwardable

      def_delegators :@manifest, :directory_service, :username, :commit_all

      attr_reader :manifest

      def initialize(manifest)
        @manifest = manifest
      end
    end
  end
end
