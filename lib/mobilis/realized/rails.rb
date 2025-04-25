# frozen_string_literal: true

module Mobilis
  module Realized
    class Rails < Mobilis::Base::RealizedNode
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :primary_database, :env_db_url

      def initialize(env, node)
        super(env, node)

        @has_service_dir = true
        @has_data_volume = false
      end

      def after_all_nodes_realized
        return unless node.primary_database

        @primary_database = @realized_env.node_for(node.primary_database)
        @env_db_url = @primary_database.env_db_url.as("DATABASE_URL")
        @env_vars << @env_db_url if @env_db_url
        @env_vars << BasicEnvVar.new("RAILS_ENV", "production") # TODO: this needs meditation
        @env_vars << BasicEnvVar.new("RAILS_MIN_THREADS", 5)
        @env_vars << BasicEnvVar.new("RAILS_MAX_THREADS", 5)
      end

      def required_plugins
        [Mobilis::Plugin::RailsBuilder, Mobilis::Plugin::RailsDBFanout]
      end

      def service_writer
        Mobilis::ServiceWriter::Rails
      end

      def extra_depends_on
        @extra_depends_on ||= []
      end

      def compose
        @compose ||= begin
          fragment = {
            image: "#{username}/#{name}", # Replace with the actual builder output if needed
            # container_name: name,
            ports: port_maps.map(&:to_compose),
            environment: env_vars.map(&:to_compose),
            volumes: service_dir_mounts,
            build: "./#{name}"
          }

          if primary_database
            fragment[:depends_on] = {
              primary_database.name => {
                condition: primary_database.has_healthcheck? ? "service_healthy" : "service_started",
                restart: primary_database.dependant_services_require_restart?
              }.compact
            }
          end

          extra_depends_on.each do |other_node|
            fragment[:depends_on] ||= {}
            fragment[:depends_on][other_node.name] = {
              condition: other_node.has_healthcheck? ? "service_healthy" : "service_started",
              restart: other_node.dependant_services_require_restart?
            }.compact
          end

          { services: { name => fragment.compact } }
        end
      end

      def service_dir_mounts
        nil
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "environment", environment
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.child_object "env_db_url", env_db_url
        dsl.child_object "primary_database", primary_database
        dsl.child_object "node", node
        dsl.env_vars env_vars
      end
    end
  end
end
