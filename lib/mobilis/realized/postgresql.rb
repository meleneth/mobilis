# frozen_string_literal: true

module Mobilis
  module Realized
    class PostgreSQL < SQLDatabase
      INTERNAL_PORT_NO = 5432
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :env_db_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::POSTGRES)

        # PUBLIC URL for linking (no aliasing needed — used by consumers)
        @env_db_url = add_env_only_var("#{name}_database_url", url)

        # POSTGRES_* vars used inside the container
        @postgres_user_env_var = add_compose_aliased_var("POSTGRES_USER", "#{name}_postgres_user", user)
        add_compose_aliased_var("POSTGRES_PASSWORD", "#{name}_postgres_password", password)
        @postgres_db_env_var = add_compose_aliased_var("POSTGRES_DB", "#{name}_postgres_db", db_name)

        register_external_port(internal_port_no, "#{name}_POSTGRES_PORT",
                               "#{name} database port")

        set_compose_image(Mobilis::ContainerVersions::POSTGRES)
        set_healthcheck_command("pg_isready -U #{@postgres_user_env_var.env_var_ref} -d #{@postgres_db_env_var.env_var_ref}")
        add_volume(data_volume_env_var.env_var_ref, "/var/lib/postgresql")
      end

      def after_all_nodes_realized
        configure_primary_replication if primary_with_replicas?
        configure_replica if replica?
      end

      def service_writer
        Mobilis::ServiceWriter::PostgreSQL
      end

      def build_packages
        ["libpq-dev"]
      end

      def runtime_packages
        ["libpq5"]
      end

      def additional_gems
        ["pg"]
      end

      def data_volume_env_var
        # this var will not be in the environment for the container
        # but it will be in the .env file
        @data_volume_env_var ||= add_env_only_var("#{name}_postgres_data", "./data/#{environment}/#{config_node.name}")
      end

      def user
        "#{database_identity_node.name}-#{environment}-user"
      end

      def password
        "#{database_identity_node.name}-#{environment}-password"
      end

      def db_name
        "#{database_identity_node.name}_#{environment}"
      end

      def scheme
        "postgres"
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end

      def replica?
        !config_node.replicate_from.nil?
      end

      def primary_with_replicas?
        realized_env.realized_nodes.any? do |node|
          node.is_a?(Mobilis::Realized::PostgreSQL) && node.config_node.replicate_from == config_node
        end
      end

      def replication_enabled?
        replica? || primary_with_replicas?
      end

      def replication_user
        "#{name}-#{environment}-replicator"
      end

      def replication_password
        "#{name}-#{environment}-replication-password"
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
        # dsl.env_vars envfile_vars
      end

      private

      def database_identity_node
        config_node.replicate_from || config_node
      end

      def configure_primary_replication
        @has_service_dir = true
        add_compose_aliased_var("POSTGRES_REPLICATION_USER", "#{name}_postgres_replication_user", replication_user)
        add_compose_aliased_var("POSTGRES_REPLICATION_PASSWORD", "#{name}_postgres_replication_password", replication_password)
        add_volume("./#{name}/init-replication-primary.sh", "/docker-entrypoint-initdb.d/010-init-replication-primary.sh")
        compose[:command] << "postgres"
        compose[:command] << "-c"
        compose[:command] << "wal_level=replica"
        compose[:command] << "-c"
        compose[:command] << "max_wal_senders=10"
        compose[:command] << "-c"
        compose[:command] << "max_replication_slots=10"
        compose[:command] << "-c"
        compose[:command] << "hot_standby=on"
        compose[:command] << "-c"
        compose[:command] << "password_encryption=scram-sha-256"
      end

      def configure_replica
        @has_service_dir = true
        primary = realized_env.realized_node_for_config_node(config_node.replicate_from)
        register_depends_on(primary)
        add_compose_aliased_var("POSTGRES_PRIMARY_HOST", "#{name}_postgres_primary_host", primary.name)
        add_compose_aliased_var("POSTGRES_PRIMARY_PORT", "#{name}_postgres_primary_port", primary.internal_port_no)
        add_compose_aliased_var("POSTGRES_REPLICATION_USER", "#{name}_postgres_replication_user", primary.replication_user)
        add_compose_aliased_var("POSTGRES_REPLICATION_PASSWORD", "#{name}_postgres_replication_password", primary.replication_password)
        add_volume("./#{name}/replica-entrypoint.sh", "/usr/local/bin/mobilis-postgres-replica-entrypoint.sh")
        compose[:entrypoint] << "mobilis-postgres-replica-entrypoint.sh"
        compose[:command] << "postgres"
      end
    end
  end
end
