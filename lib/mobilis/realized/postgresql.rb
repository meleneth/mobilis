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

        env_vars << DockerEnvVar.new(env_key.child("postgres_db").raw,       "POSTGRES_DB",       db_name)
        env_vars << DockerEnvVar.new(env_key.child("postgres_user").raw,     "POSTGRES_USER",     user)
        env_vars << DockerEnvVar.new(env_key.child("postgres_password").raw, "POSTGRES_PASSWORD", password)
      end

      def scheme
        "postgres"
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
        dsl.child_object "db_port_map", db_port_map
        dsl.child_object "node", node
        dsl.env_vars env_vars
      end
    end
  end
end
