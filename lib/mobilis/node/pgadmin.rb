# frozen_string_literal: true

module Mobilis
  module Node
    class Pgadmin < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable
      ref_list :databases

      def initialize(...)
        super
        @databases ||= Array.new
      end

      def add_database(database)
        raise ArgumentError, "pgAdmin can only connect to PostgreSQL nodes" unless database.is_a?(Mobilis::Node::PostgreSQL)

        databases << database unless databases.include?(database)
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        databases.each { |database| dsl.child_object "database", database }
      end
    end
  end
end
