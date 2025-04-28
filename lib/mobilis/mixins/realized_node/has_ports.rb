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

        def add_port_map(external_port, internal_port, memo = nil)
          port_maps << [external_port, internal_port, memo]
        end

        def register_external_port(internal_port_no, env_var, memo)
          new_port_no = @@next_port_no
          env_var = Mobilis::EnvVar.new(env_var).raw
          @@next_port_no += @@next_port_increment
          new_port = PortMap.new("${#{env_var}}", internal_port_no, memo)
          port_maps << new_port
          add_basic_env_var(env_var, new_port_no, do_not_resolve: true)
        end
      end
    end
  end
end
