# frozen_string_literal: true

module Mobilis
  module Node
    class FastAPI < Mobilis::Base::Node
      attr_reader :port

      def initialize(name, port: 8000, **args)
        super(name, **args)
        raise ArgumentError, "Invalid HTTP port" unless port.is_a?(Integer) && (1..65535).cover?(port)
        raise ArgumentError, "Invalid service name" unless self.name.match?(/\A[a-z][a-z0-9-]*\z/)

        @port = port
      end

      def to_h
        super.merge(port: port)
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
