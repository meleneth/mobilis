module Mobilis
  module Base
    class ImageForm < Mobilis::Base::RealizedNode
      def initialize(realized_env, config_node, image)
        super(realized_env, config_node)
        set_compose_image(image)
      end
    end
  end
end
