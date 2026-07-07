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
      attr_accessor :internal_url_scheme

      def initialize(name, id: nil, extra_depends_on: [], **refs)
        @name = name.tr("_", "-")

        @id = id || SecureRandom.uuid

        @extra_depends_on = extra_depends_on
        @internal_url_scheme = "http"

        # Store raw ref ids (like primary_database_id)
        refs.each do |k, v|
          instance_variable_set("@#{k}", v)
        end
      end

      def run_command(command, commit_message)
        model = Mobilis::Model::RunCommand.new(command, commit_message)
        add_model(model)
      end

      def env_var_alias(local_name, service_name)
        model = Mobilis::Model::EnvVarAlias.new(local_name, service_name)
        add_model(model)
      end

      def to_h
        # @type var h: Hash[Symbol, untyped]
        h = {
          id: id,
          name: name,
          type: self.class.name,
          extra_depends_on: extra_depends_on.filter_map do |dep|
            target = dep[:target]
            name = dep[:name]

            if target.is_a?(Mobilis::Base::Node)
              target.name
            elsif name.is_a?(String)
              name
            end
          end,
          models: models.map(&:to_h)
        }
        h[:internal_url_scheme] = internal_url_scheme unless internal_url_scheme == "http"

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
