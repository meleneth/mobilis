# frozen_string_literal: true

module Mobilis
  module Base
    class Plugin
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :manifest

      def initialize(manifest)
        @manifest = manifest
      end
    end
  end
end
