# frozen_string_literal: true

module Mobilis
  module RefSlot
    class Slot
      attr_reader :name

      def initialize(name)
        @name = name.to_sym
      end

      def object_var
        "@#{name}".to_sym
      end

      def id_var
        "@#{name}_id".to_sym
      end

      def getter_method
        "#{name}_id".to_sym
      end

      def define_id_getter!(target_class)
        ivar = object_var
        target_class.define_method(getter_method) do
          instance_variable_get(ivar)&.id
        end
      end

      def hydrate(instance, value)
        instance.instance_variable_set(id_var, value)
      end

      def resolve!(instance, index)
        ref_id = instance.instance_variable_get(id_var)
        return unless ref_id

        instance.instance_variable_set(object_var, index[ref_id])
        instance.remove_instance_variable(id_var)
      end
    end

    class ListSlot
      attr_reader :name

      def initialize(name)
        @name = name.to_sym
      end

      def object_var
        :"@#{name}"
      end

      def id_var
        :"@#{name}_ids"
      end

      def getter_method
        "#{name}_ids".to_sym
      end

      def define_id_getter!(target_class)
        ivar = object_var
        target_class.define_method(getter_method) do
          Array(instance_variable_get(ivar)).map(&:id)
        end
      end

      def hydrate(instance, value)
        instance.instance_variable_set(id_var, value)
      end

      def resolve!(instance, index)
        ref_ids = instance.instance_variable_get(id_var)
        return unless ref_ids

        resolved = Array(ref_ids).map { |id| index[id] }
        instance.instance_variable_set(object_var, resolved)
        instance.remove_instance_variable(id_var)
      end
    end

    module ClassMethods
      def ref_attr_registry
        @ref_attr_registry ||= []
      end

      def ref_list_registry
        @ref_list_registry ||= []
      end

      def ref_attr(*names)
        names.each do |name|
          slot = Slot.new(name)
          ref_attr_registry << slot

          attr_accessor name

          slot.define_id_getter!(self)
        end
      end

      def ref_list(*names)
        names.each do |name|
          slot = ListSlot.new(name)
          ref_list_registry << slot

          attr_accessor name

          slot.define_id_getter!(self)
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def resolve_references_using(index)
      self.class.ref_attr_registry.each { |slot| slot.resolve!(self, index) }
      self.class.ref_list_registry.each { |slot| slot.resolve!(self, index) }
    end

    def hydrate_refs!(data)
      self.class.ref_attr_registry.each do |slot|
        slot.hydrate(self, data["\#{slot.name}_id"])
      end

      self.class.ref_list_registry.each do |slot|
        slot.hydrate(self, data["\#{slot.name}_ids"])
      end
    end

    def each_ref_id
      return enum_for(:each_ref_id) unless block_given?

      self.class.ref_attr_registry.each do |slot|
        id = send(slot.getter_method)
        yield slot.name, id if id
      end

      self.class.ref_list_registry.each do |slot|
        ids = send(slot.getter_method)
        Array(ids).each { |id| yield slot.name, id }
      end
    end
  end
end
