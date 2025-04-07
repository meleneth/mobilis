# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      include Mobilis::PrettyPrint::DSL
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

      def pretty_print(pp)
        ppx(pp) do
          heading object.class.name
          section "db_port_map", [object.db_port_map]
          line "env", object.environment
          line "url", object.url
          section "env_vars", object.env_vars
        end
        pp
      end
    end
  end
end
