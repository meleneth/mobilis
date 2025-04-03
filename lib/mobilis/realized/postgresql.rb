# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      def initialize(env, node, external_port_no:)
        super
        env_vars << DockerEnvVar.new(
          Mobilis::EnvVar.new(name).child("postgres_url").raw,
          "POSTGRES_URL",
          url
        )
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
    end
  end
end
