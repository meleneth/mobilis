# frozen_string_literal: true

module Mobilis
  module Model
    class RunCommand
      attr_reader :command, :commit_message

      def initialize(command, commit_message)
        @command = command
        @commit_message = commit_message
      end

      def to_h
        {
          type: self.class.name,
          command: @command,
          commit_message: @commit_message
        }
      end

      def self.from_h(hash)
        new(hash[:command], hash[:commit_message])
      end

      def ppx_fields(dsl)
        dsl.simple_value "command", command
        dsl.simple_value "commit_message", commit_message
      end
    end
  end
end
