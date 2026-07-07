# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasExtraDependsOn
        # rubocop:disable Naming/PredicateName
        def has_extra_depends_on(target_node, force_skip_health_checks: false)
          # @type var dependency: Mobilis::node_ref_dependency
          dependency = { target: target_node, force_skip_health_checks: force_skip_health_checks }
          extra_depends_on << dependency
          dependency
        end
        # rubocop:enable Naming/PredicateName

        def add_script(filename, contents)
          model = Mobilis::Model::Script.new(filename, contents)
          models << model
          model
        end

        # rubocop:disable Naming/PredicateName
        def has_connected_depends_on_class?(klass)
          extra_depends_on.each do |dep|
            target = dep[:target]
            return target if target.is_a?(Mobilis::Base::Node) && target.instance_of?(klass)
            return target if target.is_a?(Mobilis::Base::RealizedNode) && target.instance_of?(klass)
          end
          nil
        end
        # rubocop:enable Naming/PredicateName
      end
    end
  end
end
