# frozen_string_literal: true

module Mobilis
  module Node
    class GoHTTP < Mobilis::Base::Node
      attr_reader :port

      def initialize(name, port: 8080, **args)
        super(name, **args)
        raise ArgumentError, "Invalid HTTP port" unless port.is_a?(Integer) && (1..65535).cover?(port)
        raise ArgumentError, "Invalid service name" unless self.name.match?(/\A[a-z][a-z0-9-]*\z/)

        @port = port
      end

      def to_h
        super.merge(port: port)
      end
    end
  end
end
