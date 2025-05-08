# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add service override support to RealizedNode.
      module HasOverrides
        def compose_overrides
          return @compose_overrides if defined?(@compose_overrides)

          @compose_overrides = AutoVivify.new
          @compose_overrides[:environment] = compose_environment_override
          @compose_overrides[:ports] = compose_ports_override
          @compose_overrides[:depends_on] = compose_depends_on_overrides
          @compose_overrides
        end

        def add_override(key, value)
          overrides[key] = value
        end

        def merge_overrides(hash)
          overrides.merge!(hash)
        end
      end
    end
  end
end
