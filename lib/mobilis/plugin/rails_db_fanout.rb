# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanout < Mobilis::Base::Plugin
      extend Forwardable
      def_delegators :@manifest

      def hook_envs_realized
        # iterate all Rails realized instances
        # for each one, if primary_database exists make 3 more databases
        # that are linked, and populate env vars such that rails Just Works

        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, node|
          next unless node.primary_database

          wireup_variant(realized_env, node, "")
          next unless realized_env.is_production?

          wireup_variant(realized_env, node, "cache")
          wireup_variant(realized_env, node, "cable")
          wireup_variant(realized_env, node, "queue")
        end
      end

      def wireup_variant(realized_env, node, name)
        db = node.primary_database
        name = if name == ""
                 db.name
               else
                 "#{db.name}-#{name}"
               end
        new_db_node = db.node.class.new(name)
        new_db = db.class.new(node.environment, new_db_node, external_port_no: "fml")
        puts "Wiring #{name}"
        realized_env << new_db
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
