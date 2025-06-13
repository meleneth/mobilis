# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add add depends_on support to RealizedNode
      module HasDependsOn
        def register_depends_on(realized_node, force_skip_health_checks: false, override: false)
          if override
            compose_depends_on_overrides.register(realized_node, force_skip_health_checks: force_skip_health_checks)
          else
            compose_depends_on.register(realized_node, force_skip_health_checks: force_skip_health_checks)
          end
        end

        def compose_depends_on
          unless defined?(@compose_depends_on) && @compose_depends_on
            @compose_depends_on = Mobilis::Compose::DependsOn.new
          end
          @compose_depends_on
        end

        def compose_depends_on_overrides
          unless defined?(@compose_depends_on_overrides) && @compose_depends_on_overrides
            @compose_depends_on_overrides = Mobilis::Compose::DependsOn.new(base: compose_depends_on)
          end
          @compose_depends_on_overrides
        end
      end
    end
  end
end
