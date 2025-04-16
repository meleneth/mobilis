# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanout < Mobilis::Base::Plugin
      extend Forwardable
      def_delegators :@manifest, :realized_production_env

      def hook_envs_realized
        # for the prod realized_env, iterate all Rails realized instances
        # for each one, if primary_database exists make 3 more databases
        # that are linked, and populate env vars such that rails Just Works

        realized_production_env&.each_node_of_type(Mobilis::Realized::Rails) do |node|
          next unless node.primary_database

          wireup_varient(node, "cache")
          wireup_varient(node, "cable")
          wireup_varient(node, "queue")
        end
      end

      def wireup_varient(node, name)
        db = node.primary_database
        new_db = node.class.new(node.end, nil, "fml")
      end
    end
  end
end
