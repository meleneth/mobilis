# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby
    class Ruby < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      def add_gem(name, **options)
        gem = Mobilis::Model::RubyGem.new(name, **options)
        add_model(gem)
        gem
      end

      def local_gem(name, path: nil, require_name: nil, &block)
        gem = Mobilis::Model::LocalGem.new(name, path: path, require_name: require_name)
        block&.call(gem)
        add_model(gem)
        gem
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
      end
    end
  end
end
