# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for SQL Databases
    class PostgreSQL < Mobilis::Node::SQLDatabase
      include Mobilis::PrettyPrint::PrettyPrintable
      ref_attr :replicate_from

      NO_REPLICATION_TARGET = Object.new.freeze

      def replicate_from(target = NO_REPLICATION_TARGET)
        return @replicate_from if target == NO_REPLICATION_TARGET

        raise ArgumentError, "PostgreSQL can only replicate from another PostgreSQL node" unless target.is_a?(Mobilis::Node::PostgreSQL)
        raise ArgumentError, "PostgreSQL cannot replicate from itself" if target == self

        @replicate_from = target
      end

      def replica?
        !replicate_from.nil?
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.child_object "replicate_from", replicate_from if replica?
      end
    end
  end
end
