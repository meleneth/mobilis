# frozen_string_literal: true

module Mobilis
  module Realized
    class FastAPI < HTTPApplication
      def initialize(env, node)
        super
        if node.graphql_subgraph_name
          set_healthcheck_command("python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:#{exposed_port_no}/health', timeout=2)\"",
                                  interval: "5s", timeout: "4s", retries: 20, start_period: "10s")
        end
      end

      def service_writer
        Mobilis::ServiceWriter::FastAPI
      end

      def after_all_nodes_realized
        super
        if !database && config_node.has_model_class?(Mobilis::Model::SQLAlchemy::Model)
          raise ArgumentError, "SQLAlchemy models require a PostgreSQL connection"
        end
      end
    end
  end
end
