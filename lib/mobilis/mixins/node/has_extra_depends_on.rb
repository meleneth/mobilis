# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasExtraDependsOn
        # rubocop:disable Naming/PredicateName
        def has_extra_depends_on(target_node, force_skip_health_checks: false)
          extra_depends_on << { target: target_node, force_skip_health_checks: force_skip_health_checks }
        end
        # rubocop:enable Naming/PredicateName

        def add_script(filename, contents)
          models << Mobilis::Model::Script.new(filename, contents)
        end

        # rubocop:disable Naming/PredicateName
        def has_connected_depends_on_class?(klass)
          extra_depends_on.each do |dep|
            return dep[:target] if dep[:target].instance_of? klass
          end
        end
        # rubocop:enable Naming/PredicateName
      end
    end
  end
end
