# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add service override support to RealizedNode.
      module HasOverrides
        def compose_overrides
          return @compose_overrides if defined?(@compose_overrides)

          @compose_overrides = AutoVivify.new
        end

        def render_compose_overrides
          render_helper(compose_overrides)
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
