# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :env_db_url

      def initialize(env, node, external_port_no:)
        super
        @env_db_url = DockerEnvVar.new("",
                                       Mobilis::EnvVar.new(name).child("database_url").raw,
                                       url)
        env_key = EnvVar.new(name)

        @postgres_user_env_var = DockerEnvVar.new("POSTGRES_USER", env_key.child("postgres_user").raw, user)
        env_vars << @postgres_user_env_var
        env_vars << DockerEnvVar.new("POSTGRES_PASSWORD", env_key.child("postgres_password").raw, password)
        @postgres_db_env_var = DockerEnvVar.new("POSTGRES_DB", env_key.child("postgres_db").raw, db_name)
        env_vars << @postgres_db_env_var
        @per_env_vars << data_volume_env_var
      end

      def data_volume_env_var
        @data_volume_env_var ||= BasicEnvVar.new(Mobilis::EnvVar.new("#{name}_postgres_data").raw,
                                                 "./data/#{environment}/#{node.name}")
      end

      def scheme
        "postgres"
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def compose
        @compose ||= {
          services: {
            name => {
              image: Mobilis::ContainerVersions::POSTGRES,
              #              container_name: name,
              ports: port_maps.map(&:to_compose),
              environment: env_vars.map(&:to_compose),
              volumes: volume_paths,
              healthcheck: {
                test: ["CMD-SHELL",
                       "pg_isready -U ${#{@postgres_user_env_var.specific_name}} -d ${#{@postgres_db_env_var.specific_name}}"],
                interval: "10s",
                timeout: "5s",
                retries: 5,
                start_period: "5s"
              }
            }
          }
        }.compact
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
        dsl.child_object "db_port_map", db_port_map
        dsl.child_object "node", node
        dsl.env_vars env_vars
      end
    end
  end
end
