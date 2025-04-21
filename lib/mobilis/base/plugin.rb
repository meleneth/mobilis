# frozen_string_literal: true

module Mobilis
  module Base
    class Plugin
      include Mobilis::PrettyPrint::PrettyPrintable
      extend Forwardable

      def_delegators :@manifest, :directory_service, :username

      attr_reader :manifest

      def initialize(manifest)
        @manifest = manifest
      end

      def hook_envs_realized
      end

      def hook_before_services_written
      end
    end
  end
end
