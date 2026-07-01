# frozen_string_literal: true

module Mobilis
  module Realized
    class MySQL < SQLDatabase
      INTERNAL_PORT_NO = 3306
      attr_reader :env_db_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::MYSQL)

        @env_db_url = add_env_only_var("#{name}_database_url", url)

        @mysql_user_env_var = add_compose_aliased_var("MYSQL_USER", "#{name}_mysql_user", user)
        @mysql_password_env_var = add_compose_aliased_var("MYSQL_PASSWORD", "#{name}_mysql_password", password)
        @mysql_database_env_var = add_compose_aliased_var("MYSQL_DATABASE", "#{name}_mysql_database", db_name)
        add_compose_aliased_var("MYSQL_ROOT_PASSWORD", "#{name}_mysql_root_password", root_password)

        register_external_port(internal_port_no, "#{name}_MYSQL_PORT",
                               "#{name} database port")

        set_compose_image(Mobilis::ContainerVersions::MYSQL)
        set_healthcheck_command("mysqladmin ping -h 127.0.0.1 -u#{@mysql_user_env_var.env_var_ref} -p#{@mysql_password_env_var.env_var_ref}")
        add_volume(data_volume_env_var.env_var_ref, "/var/lib/mysql")
      end

      def root_password
        "#{name}-#{environment}-root-password"
      end

      def build_packages
        ["default-libmysqlclient-dev"]
      end

      def runtime_packages
        ["libmariadb3"]
      end

      def additional_gems
        ["mysql2"]
      end

      def data_volume_env_var
        @data_volume_env_var ||= add_env_only_var("#{name}_mysql_data", "./data/#{environment}/#{config_node.name}")
      end

      def scheme
        "mysql2"
      end

      def internal_port_no
        INTERNAL_PORT_NO
      end
    end
  end
end
