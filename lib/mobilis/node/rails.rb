# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby on Rails
    class Rails < Mobilis::Node::Ruby
      include Mobilis::PrettyPrint::PrettyPrintable
      ref_attr :primary_database

      def add_rails_model(name, &block)
        new_model = Mobilis::Model::Rails::Model.new(name)
        new_model.instance_eval(&block) if block_given?

        models << new_model
        new_model
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.child_object "primary_database", primary_database
      end
    end
  end
end
