module Mobilis
  module Base
    class BuildForm < Mobilis::Base::RealizedNode
      def initialize(realized_env, config_node)
        super
        set_compose_build_context
      end
    end
  end
end
