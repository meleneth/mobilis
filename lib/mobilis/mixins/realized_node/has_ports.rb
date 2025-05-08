# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add port mapping support to RealizedNode.
      module HasPorts
        @@next_port_no = 11_000
        @@next_port_increment = 10

        def port_maps
          @port_maps = [] unless defined?(@port_maps) && @port_maps
          @port_maps
        end

        # def add_port_map(external_port, internal_port, memo = nil)
        #  port_maps << [external_port, internal_port, memo]
        # end

        def register_external_port(internal_port_no, env_var, memo)
          new_port_no = @@next_port_no
          created_env_var = add_env_only_var(env_var, new_port_no)
          @@next_port_no += @@next_port_increment
          new_port = Mobilis::Primitives::PortMap.new(created_env_var.env_var_ref, internal_port_no, memo)
          compose_ports.add(new_port)
          new_port
        end

        def compose_ports
          @compose_ports = Mobilis::Compose::Ports.new unless defined?(@compose_ports) && @compose_ports
          @compose_ports
        end

        def compose_ports_override
          unless defined?(@compose_ports_override) && @compose_ports_override
            @compose_ports_override = Mobilis::Compose::Ports.new(base: compose_ports)
          end
          @compose_ports_override
        end
      end
    end
  end
end
