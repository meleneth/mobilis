# frozen_string_literal: true

require "mobilis/base/realized_node"
require "mobilis/port_map"
require "mobilis/docker_env_var"
require "mobilis/env_var"

module Mobilis
  module Realized
    class PostgreSQL < Mobilis::Base::RealizedNode
      INTERNAL_PORT_NO = 5432

      def initialize(env, node, external_port_no:)
        super(env, node)

        @has_data_volume = true
        @has_service_dir = false

        env_key = EnvVar.new(name)

        port_maps << PortMap.new(external_port_no, INTERNAL_PORT_NO, "PostgreSQL default port")

        env_vars << DockerEnvVar.new(env_key.child("postgres_db").raw,       "POSTGRES_DB",       db_name)
        env_vars << DockerEnvVar.new(env_key.child("postgres_user").raw,     "POSTGRES_USER",     user)
        env_vars << DockerEnvVar.new(env_key.child("postgres_password").raw, "POSTGRES_PASSWORD", password)
        env_vars << DockerEnvVar.new(env_key.child("postgres_url").raw,      "POSTGRES_URL",      url)
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def user
        "#{name}-#{environment}-user"
      end

      def password
        "#{name}-#{environment}-password"
      end

      def db_name
        "#{name}_#{environment}"
      end

      def url
        "postgres://#{user}:#{password}@#{name}:#{INTERNAL_PORT_NO}/#{db_name}"
      end
    end
  end
end
