# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :env_db_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::POSTGRES)

        # PUBLIC URL for linking (no aliasing needed — used by consumers)
        @env_db_url = add_env_only_var("#{name}_database_url", url)

        # POSTGRES_* vars used inside the container
        @postgres_user_env_var = add_compose_aliased_var("POSTGRES_USER", "#{name}_postgres_user", user)
        add_compose_aliased_var("POSTGRES_PASSWORD", "#{name}_postgres_password", password)
        @postgres_db_env_var = add_compose_aliased_var("POSTGRES_DB", "#{name}_postgres_db", db_name)

        register_external_port(internal_port_no, "#{name}_POSTGRES_PORT",
                               "#{name} database port")

        set_compose_image(Mobilis::ContainerVersions::POSTGRES)
        set_healthcheck_command("pg_isready -U #{@postgres_user_env_var.env_var_ref} -d #{@postgres_db_env_var.env_var_ref}")
        add_volume(data_volume_env_var.container_var_ref, "/var/lib/postgresql/data")
      end

      def data_volume_env_var
        # this var will not be in the environment for the comtainer
        # but it will be in the .env file
        @data_volume_env_var ||= add_env_only_var("#{name}_postgres_data", "./data/#{environment}/#{config_node.name}")
      end

      def scheme
        "postgres"
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def volume_paths
        ["${#{data_volume_env_var.container_name}}:/var/lib/postgresql/data"]
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
        dsl.env_vars envfile_vars
      end
    end
  end
end
