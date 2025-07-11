# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby on Rails
    class Rails < Mobilis::Node::Ruby
      include Mobilis::PrettyPrint::PrettyPrintable
      ref_attr :primary_database
      attr_accessor :api_mode

      def add_rails_model(name, &block)
        new_model = Mobilis::Model::Rails::Model.new(name)
        new_model.instance_eval(&block) if block_given?

        models << new_model
        new_model
      end

      def install_graphql!
        graphql_model = Mobilis::Model::Rails::GraphQL.new
        models << graphql_model
        graphql_model
      end

      def to_h
        super.merge({ api_mode: api_mode })
      end

      def self.from_h(hash)
        new(hash[:name]).tap do |obj|
          obj.api_mode = hash[:api_mode]
        end
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "api_mode", api_mode
        dsl.child_object "primary_database", primary_database
      end
    end
  end
end
