# frozen_string_literal: true

module Mobilis
  module Node
    class Rack < Mobilis::Node::Ruby
      attr_accessor :instances

      def initialize(name, instances: 1, **kwargs)
        super(name, **kwargs)
        @instances = instances
      end

      def to_h
        super.merge(instances: instances)
      end

      def self.from_h(hash)
        new(hash[:name], instances: hash[:instances] || 1)
      end
    end
  end
end
