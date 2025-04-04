# frozen_string_literal: true

module Mobilis
  module Realized
    class SQLDatabase < Mobilis::Base::RealizedNode
      attr_reader :db_port_map

      def initialize(env, node, external_port_no:)
        super(env, node)

        @has_data_volume = true
        @has_service_dir = false

        @db_port_map = Mobilis::PortMap.new(
          external_port_no,
          internal_port_no,
          "#{self.class.name.split("::").last} default port"
        )

        port_maps << @db_port_map
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
        "#{scheme}://#{user}:#{password}@#{name}:#{internal_port_no}/#{db_name}"
      end

      # @param for [String] the name of the consuming service (e.g., Rails app)
      # @return [Mobilis::DockerEnvVar]
      def consumer_url_env_var(fer)
        consumer = Mobilis::EnvVar.new(fer)
        provider = Mobilis::EnvVar.new(name)

        Mobilis::DockerEnvVar.new(
          consumer.child("database_url").raw,
          "DATABASE_URL",
          provider.child("#{scheme}_url").ref
        )
      end

      # Subclasses must define this to provide the URL scheme (e.g., "postgres", "mysql2")
      def scheme
        raise NotImplementedError, "#{self.class} must implement #scheme"
      end
    end
  end
end
