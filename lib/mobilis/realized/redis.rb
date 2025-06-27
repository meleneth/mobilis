# frozen_string_literal: true

module Mobilis
  module Realized
    class Redis < SQLDatabase
      INTERNAL_PORT_NO = 6379
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :redis_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::REDIS)

        # PUBLIC URL for linking (no aliasing needed — used by consumers)
        @redis_url = add_env_only_var("#{name}_redis_url", url)

        set_compose_image(Mobilis::ContainerVersions::REDIS)
        set_healthcheck_command("redis-cli ping")
      end

      def url
        "redis://#{name}:#{internal_port_no}"
      end

      def additional_gems
        ["redis"]
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def ppx_fields(dsl)
        dsl.instance_value "environment", environment
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "name", name
        dsl.instance_value "url", url
        port_maps.each do |port_map|
          dsl.child_object "port_map", port_map
        end
        dsl.child_object "config_node", config_node
        # dsl.env_vars envfile_vars
      end
    end
  end
end
