# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add volume mount support to RealizedNode.
      module HasVolumes
        def compose_volumes
          return @compose_volumes if defined?(@compose_volumes)

          @compose_volumes = Mobilis::Compose::Volume.new
        end

        def compose_volumes_overrides
          return @compose_volumes_overrides if defined?(@compose_volumes_overrides)

          @compose_volumes_overrides = Mobilis::Compose::Volume.new(base: compose_volumes)
        end

        def add_volume(source, target, override: false)
          if override
            compose_volumes_overrides.add(source, target)
          else
            compose_volumes.add(source, target)
          end
        end
      end
    end
  end
end
