# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add volume mount support to RealizedNode.
      module HasVolumes
        def volumes
          @volumes ||= []
        end

        def add_volume(source, target)
          volumes << [source, target]
        end
      end
    end
  end
end
