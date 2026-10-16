# frozen_string_literal: true

module Mobilis
  module Realized
    class Cassandra < Mobilis::Base::ImageForm
      PORT = 9042
      attr_reader :source_image
      def initialize(env, node)
        @source_image = node.version_tag ? "cassandra:#{node.version_tag}" : Mobilis::ContainerVersions::CASSANDRA
        super(env, node, "#{env.meta_project_name}/#{node.name}")
        @has_service_dir = true
        @has_dockerfile = true
        @has_data_volume = true
        set_compose_build_context
        add_volume(add_env_only_var("#{name}_cassandra_data", "./data/#{environment}/#{name}").env_var_ref, "/var/lib/cassandra")
        declare_storage("data", "/var/lib/cassandra")
        add_compose_raw_var("CASSANDRA_DC", node.datacenter_name)
        add_compose_raw_var("CASSANDRA_ENDPOINT_SNITCH", "GossipingPropertyFileSnitch")
        add_compose_raw_var("MOBILIS_KEYSPACE", node.keyspace_name) if node.keyspace_name
        # Local credentials are explicit. Production must be edited in the generated env file.
        user = environment == "production" ? "REPLACE_CASSANDRA_USER" : "mobilis_dev"
        password = environment == "production" ? "REPLACE_CASSANDRA_PASSWORD" : "mobilis_dev_password"
        add_compose_aliased_var("MOBILIS_CASSANDRA_USER", "#{name}_cassandra_user", user)
        add_compose_aliased_var("MOBILIS_CASSANDRA_PASSWORD", "#{name}_cassandra_password", password)
        set_healthcheck_command('test -f /tmp/mobilis-cassandra-ready && cqlsh 127.0.0.1 9042 -u "$$MOBILIS_CASSANDRA_USER" -p "$$MOBILIS_CASSANDRA_PASSWORD" -e "SELECT release_version FROM system.local" >/dev/null 2>&1', interval: "15s", timeout: "10s", retries: 20, start_period: "120s")
      end

      def service_writer
        Mobilis::ServiceWriter::Cassandra
      end

      def dependant_services_require_restart?
        true
      end

      def connection_values
        {"CASSANDRA_CONTACT_POINTS" => name, "CASSANDRA_PORT" => PORT.to_s,
         "CASSANDRA_DATACENTER" => config_node.datacenter_name,
         "CASSANDRA_KEYSPACE" => config_node.keyspace_name,
         "CASSANDRA_USERNAME" => environment == "production" ? "REPLACE_CASSANDRA_USER" : "mobilis_dev",
         "CASSANDRA_PASSWORD" => environment == "production" ? "REPLACE_CASSANDRA_PASSWORD" : "mobilis_dev_password"}.compact
      end
    end
  end
end
