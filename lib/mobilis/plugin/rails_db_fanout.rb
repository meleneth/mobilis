# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanout < Mobilis::Base::Plugin
      extend Forwardable
      def_delegators :@manifest

      def hook_envs_realized
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_node.primary_database
          next unless realized_env.is_production?

          wireup_variant(realized_env, realized_node, "cache")
          wireup_variant(realized_env, realized_node, "cable")
          wireup_variant(realized_env, realized_node, "queue")
        end
      end

      def wireup_variant(realized_env, realized_node, name)
        db = realized_node.primary_database
        db_name = "#{db.name}-#{name}"

        new_db_node = db.config_node.class.new(db_name)
        new_db = db.class.new(realized_node.environment, new_db_node)
        realized_env << new_db
        env_db_url = new_db.env_db_url.as("#{name}_DATABASE_URL")
        realized_node.env_vars << env_db_url
        realized_node.extra_depends_on << new_db
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
