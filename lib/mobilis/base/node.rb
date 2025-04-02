# frozen_string_literal: true

require "securerandom"
require "mobilis/ref_slot"

module Mobilis
  module Base
    class Node
      include Mobilis::RefSlot

      attr_reader :id, :name

      def initialize(name, id: nil, **refs)
        @name = name

        @id = id || SecureRandom.uuid

        # Store raw ref ids (like primary_database_id)
        refs.each do |k, v|
          instance_variable_set("@#{k}", v)
        end
      end

      def to_h
        h = {
          id: id,
          name: name,
          type: self.class.name
        }

        each_ref_id do |ref, id|
          key = self.class.ref_list_registry.any? { |slot| slot.name == ref } ? :"#{ref}_ids" : :"#{ref}_id"

          if key.to_s.end_with?("_ids")
            h[key] ||= []
            h[key] << id
          else
            h[key] = id
          end
        end

        h
      end
    end
  end
end
