# frozen_string_literal: true

module Mobilis
  module GeneratorCapture
    class Definition
      WORKSPACE_TOKEN = "{workspace}"
      REPOSITORY_TOKEN = "{repository}"

      attr_reader :name, :generator_name, :generator_version, :fixture_name,
                  :fixture_path, :command_parts, :argument_list, :environment_variables,
                  :runtime_metadata, :repository_path

      def initialize(name)
        @name = String(name)
        @argument_list = []
        @environment_variables = {}
        @runtime_metadata = {}
      end

      def generator(name, version:)
        @generator_name = String(name)
        @generator_version = String(version)
      end

      def fixture(name, path:)
        @fixture_name = String(name)
        @fixture_path = File.expand_path(path)
      end

      def repository(path:)
        @repository_path = File.expand_path(path)
      end

      def command(*parts)
        @command_parts = parts.flatten.map(&:to_s).freeze
      end

      def arguments(*values)
        @argument_list = values.flatten.map(&:to_s).freeze
      end

      def environment(values)
        @environment_variables = values.to_h.transform_keys(&:to_s).transform_values(&:to_s).sort.to_h.freeze
      end

      def runtime(values)
        @runtime_metadata = values.to_h.transform_keys(&:to_s).transform_values(&:to_s).sort.to_h.freeze
      end

      def validate!
        raise ArgumentError, "Capture name cannot be empty" if name.empty?
        raise ArgumentError, "Capture #{name} has no generator" unless generator_name && generator_version
        raise ArgumentError, "Capture #{name} has no fixture" unless fixture_name && fixture_path
        raise ArgumentError, "Fixture does not exist: #{fixture_path}" unless Dir.exist?(fixture_path)
        raise ArgumentError, "Capture #{name} has no command" unless command_parts&.any?
        unless command_parts.any? { |part| part.include?(WORKSPACE_TOKEN) }
          raise ArgumentError, "Capture command must include #{WORKSPACE_TOKEN}"
        end
        if command_parts.any? { |part| part.include?(REPOSITORY_TOKEN) } ||
           environment_variables.values.any? { |value| value.include?(REPOSITORY_TOKEN) }
          raise ArgumentError, "Capture #{name} has no repository path" unless repository_path
        end

        self
      end
    end
  end
end
