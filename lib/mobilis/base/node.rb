# frozen_string_literal: true

require "securerandom"

module Mobilis
  module Base
    class Node
      include Mobilis::RefSlot
      include Mobilis::Mixins::Node::HasModels
      include Mobilis::Mixins::Node::HasScripts
      include Mobilis::Mixins::Node::HasExtraDependsOn

      attr_reader :id, :name, :extra_depends_on

      def initialize(name, id: nil, extra_depends_on: [], **refs)
        @name = name.tr("_", "-")

        @id = id || SecureRandom.uuid

        @extra_depends_on = extra_depends_on

        # Store raw ref ids (like primary_database_id)
        refs.each do |k, v|
          instance_variable_set("@#{k}", v)
        end
      end

      def run_command(command, commit_message)
        model = Mobilis::Model::RunCommand.new(command, commit_message)
        add_model(model)
      end

      def to_h
        h = {
          id: id,
          name: name,
          type: self.class.name,
          extra_depends_on: extra_depends_on.map { |dep| dep[:target].name },
          models: models.map(&:to_h)
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
