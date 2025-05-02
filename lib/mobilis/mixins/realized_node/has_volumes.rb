# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add volume mount support to RealizedNode.
      module HasVolumes
        def compose_volumes
          return @compose_volumes if defined?(@compose_volumes)

          @compose_volumes = []
        end

        def add_volume(source, target)
          compose_volumes << "#{source}:#{target}"
        end
      end
    end
  end
end
