# frozen_string_literal: true

module Mobilis
  module Realized
    class FastAPI < HTTPApplication
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
