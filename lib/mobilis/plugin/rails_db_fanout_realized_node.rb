# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanoutRealizedNode < Mobilis::Base::RealizedNodePlugin
      extend Forwardable

      def_delegators :realized_node, :compose_overrides, :compose_depends_on, :primary_database, :compose_env_vars
      attr_reader :extra_env_db_urls

      def create_additional_services
        wireup_variant(realized_env, realized_node, "cache")
        wireup_variant(realized_env, realized_node, "cable")
        wireup_variant(realized_env, realized_node, "queue")
      end

      def extra_db_nodes
        @extra_db_nodes ||= []
      end

      def generate_compose_overrides
        compose_overrides[:depends_on] = compose_depends_on.dup unless compose_overrides.has_key? :depends_on
        @extra_env_db_urls ||= []

        extra_db_nodes.each do |extra_realized_node|
          compose_overrides[:depends_on][extra_realized_node.name] = {
            condition: primary_database.has_healthcheck? ? "service_healthy" : "service_started",
            restart: primary_database.dependant_services_require_restart?
          }.compact
        end

        unless compose_overrides.has_key? :environment
          compose_overrides[:environment] = compose_env_vars.map(&:docker_repr)
        end

        extra_env_db_urls.each do |env_url|
          compose_overrides[:environment] << env_url
        end
      end

      def wireup_variant(realized_env, realized_node, name)
        @extra_db_nodes ||= []
        @extra_env_db_urls ||= []
        db = primary_database
        db_name = "#{db.name}-#{name}"

        new_db_node = db.config_node.class.new(db_name)
        new_db = db.class.new(realized_node.environment, new_db_node)
        realized_env << new_db
        extra_db_nodes << new_db
        env_db_url = new_db.env_db_url.as("#{name}_DATABASE_URL")
        @extra_env_db_urls << env_db_url.docker_repr
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
