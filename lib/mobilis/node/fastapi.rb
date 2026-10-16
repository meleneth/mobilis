# frozen_string_literal: true

module Mobilis
  module Node
    class FastAPI < Mobilis::Base::Node
      attr_reader :port, :publish_port, :graphql_subgraph_name

      def initialize(name, port: 8000, publish_port: true, graphql_subgraph_name: nil, **args)
        super(name, **args)
        raise ArgumentError, "Invalid HTTP port" unless port.is_a?(Integer) && (1..65535).cover?(port)
        raise ArgumentError, "Invalid service name" unless self.name.match?(/\A[a-z][a-z0-9-]*\z/)

        @port = port
        @publish_port = publish_port
        @graphql_subgraph_name = graphql_subgraph_name
      end

      def to_h
        super.merge(port: port, publish_port: publish_port, graphql_subgraph_name: graphql_subgraph_name)
      end

      def graphql_subgraph(name, source:)
        raise ArgumentError, "Only one GraphQL subgraph is supported per FastAPI service" if graphql_subgraph_name
        raise ArgumentError, "Invalid GraphQL subgraph name" unless name.to_s.match?(/\A[a-z][a-z0-9_]*\z/)
        raise ArgumentError, "GraphQL schema source is missing: #{source}" unless File.file?(source)

        @graphql_subgraph_name = name.to_s
        add_model(Mobilis::Model::File.new("src/#{package_name}/graphql_schema.py", File.read(source)))
        self
      end

      def add_sqlalchemy_model(name, table: nil)
        model = Mobilis::Model::SQLAlchemy::Model.new(name, table: table)
        yield model if block_given?
        add_model(model)
        model
      end

      def package_name
        "service_#{name.tr("-", "_")}"
      end
    end
  end
end
