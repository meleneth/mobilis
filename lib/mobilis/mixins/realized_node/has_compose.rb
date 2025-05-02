# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      module HasCompose
        def compose
          return @compose if defined?(@compose)

          @compose = AutoVivify.new
          @compose[:image] = compose_image
          @compose[:ports] = compose_ports
          @compose[:environment] = compose_env_vars.map(&:docker_repr)
          @compose[:volumes] = compose_volumes
          @compose[:build][:context] = compose_build_context
          @compose[:healthcheck] = compose_healthcheck # defined in Mobilis::Mixins::RealizedNode::HasHealthCheck
          @compose[:depends_on] = compose_depends_on
          @compose
        end

        def set_compose_image(image)
          @compose_image = image
        end

        def set_compose_build_context(build_context = "default")
          build_context = "./#{name}" if build_context == "default"
          @compose_build_context = build_context
        end

        def compose_build_context
          return @compose_build_context if defined?(@compose_build_context)

          @compose_build_context = nil
        end

        def compose_image
          return @compose_image if defined?(@compose_image)

          @compose_image = "#{meta_project_name}/#{name}"
        end

        def compose_depends_on
          return @compose_depends_on if defined?(@compose_depends_on)

          @compose_depends_on = Mobilis::AutoVivify.new
        end

        def compose_ports
          return @compose_ports if defined?(@compose_ports)

          @compose_ports = port_maps.map(&:to_compose)
        end

        def render_compose
          { services: { name => render_helper(compose) } }
        end

        private
      end
    end
  end
end
