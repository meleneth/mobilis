# frozen_string_literal: true

require "mobilis/base/realized_node"
require "mobilis/docker_env_var"
require "mobilis/env_var"

module Mobilis
  module Realized
    class Rails < Mobilis::Base::RealizedNode
      def initialize(env, node)
        super(env, node)

        @has_service_dir = true
        @has_data_volume = false

        # Register a DATABASE_URL from linked primary database
        return unless node.primary_database

        db_realized = env.realized_node_for(node.primary_database)
        env_vars << db_realized.consumer_url_env_var(for: name) if db_realized.respond_to?(:consumer_url_env_var)
      end
    end
  end
end
