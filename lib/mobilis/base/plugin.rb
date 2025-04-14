# frozen_string_literal: true

module Mobilis
  module Base
    class Plugin
      include PrettyPrint::PrettyPrintable

      def initialize(realized_env)
        @realized_env = realized_env
      end
    end
  end
end
