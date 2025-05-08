# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanoutRealizedNode < Mobilis::Base::RealizedNodePlugin
      extend Forwardable

      def_delegators :realized_node, :compose_overrides, :primary_database, :compose_env_vars
      attr_reader :extra_env_db_urls

      def create_additional_services
        wireup_variant(realized_env, realized_node, "cache")
        wireup_variant(realized_env, realized_node, "cable")
        wireup_variant(realized_env, realized_node, "queue")
      end

      def wireup_variant(realized_env, realized_node, name)
        db = primary_database
        db_name = "#{db.name}-#{name}"

        new_db_node = db.config_node.class.new(db_name)
        new_db = db.class.new(realized_node.environment, new_db_node)
        realized_env << new_db
        db_env_db_url = new_db.env_db_url
        realized_node.add_compose_aliased_var("#{name}_DATABASE_URL",
                                              db_env_db_url.envfile_name,
                                              db_env_db_url.value,
                                              override: true)
        realized_node.register_depends_on(new_db, override: true)
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
