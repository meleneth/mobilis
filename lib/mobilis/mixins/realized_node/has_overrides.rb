# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add service override support to RealizedNode.
      module HasOverrides
        def overrides
          @overrides ||= {}
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
