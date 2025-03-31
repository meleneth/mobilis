# frozen_string_literal: true

require "securerandom"

module Mobilis
  class Node
    attr_accessor :raw_data
    attr_reader :id

    def initialize(id: nil, **)
      @id = id || SecureRandom.uuid
    end

    def self.ref_attr(*names)
      ref_attrs.concat(names.map(&:to_sym))

      names.each do |name|
        attr_accessor name

        define_method(:"#{name}_id", Node._make_id_getter(name))
      end
    end

    def self._make_id_getter(name)
      define_method(:__temp_getter) do
        instance_variable_get(:"@#{name}")&.id
      end

      instance_method(:__temp_getter).tap do
        remove_method(:__temp_getter)
      end
    end

    def self.ref_list(*names)
      ref_lists.concat(names.map(&:to_sym))

      names.each do |name|
        attr_accessor name

        define_method(:"#{name}_ids", Node._make_ids_getter(name))
      end
    end

    def self._make_ids_getter(name)
      define_method(:__temp_getter) do
        Array(instance_variable_get(:"@#{name}")).map(&:id)
      end

      instance_method(:__temp_getter).tap do
        remove_method(:__temp_getter)
      end
    end

    def self.ref_attrs
      @ref_attrs ||= [] # : Array[Symbol]
    end

    def self.ref_lists
      @ref_lists ||= [] # : Array[Symbol]
    end

    def to_h
      base = {
        id: id,
        type: self.class.name
      } # : Hash[Symbol, String]

      self.class.ref_attrs.each do |ref|
        base[:"#{ref}_id"] = send(:"#{ref}_id")
      end

      self.class.ref_lists.each do |ref|
        base[:"#{ref}_ids"] = send(:"#{ref}_ids")
      end

      base
    end

    def resolve_references_using(index)
      self.class.ref_attrs.each do |ref|
        ref_id = @raw_data["#{ref}_id"]
        self.instance_variable_set(:"@#{ref}", index[ref_id]) if ref_id # rubocop:disable Style/RedundantSelf
      end

      self.class.ref_lists.each do |ref|
        ref_ids = Array(@raw_data["#{ref}_ids"])
        refs = ref_ids.map { |rid| index[rid] }
        self.instance_variable_set(:"@#{ref}", refs) # rubocop:disable Style/RedundantSelf
      end
    end
  end
end
