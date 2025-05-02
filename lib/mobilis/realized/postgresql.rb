# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :env_db_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::POSTGRES)
        @env_db_url = DockerEnvVar.new("",
                                       Mobilis::EnvVar.new(name).child("database_url").raw,
                                       url)
        env_key = EnvVar.new(name)

        @postgres_user_env_var = DockerEnvVar.new("POSTGRES_USER", env_key.child("postgres_user").raw, user)
        env_vars << @postgres_user_env_var
        env_vars << DockerEnvVar.new("POSTGRES_PASSWORD", env_key.child("postgres_password").raw, password)
        @postgres_db_env_var = DockerEnvVar.new("POSTGRES_DB", env_key.child("postgres_db").raw, db_name)
        env_vars << @postgres_db_env_var
        per_env_vars << data_volume_env_var
        register_external_port(internal_port_no, "#{name}_POSTGRES_PORT",
                               "#{name} database port")

        set_compose_image(Mobilis::ContainerVersions::POSTGRES)
        set_healthcheck_command("pg_isready -U ${#{@postgres_user_env_var.specific_name}} -d ${#{@postgres_db_env_var.specific_name}}")
        add_volume("${#{data_volume_env_var.specific_name}}", "/var/lib/postgresql/data")
      end

      def data_volume_env_var
        @data_volume_env_var ||= BasicEnvVar.new(Mobilis::EnvVar.new("#{name}_postgres_data").raw,
                                                 "./data/#{environment}/#{config_node.name}")
      end

      def scheme
        "postgres"
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def volume_paths
        ["${#{data_volume_env_var.specific_name}}:/var/lib/postgresql/data"]
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
        dsl.env_vars env_vars
      end
    end
  end
end
