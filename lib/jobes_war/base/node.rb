# frozen_string_literal: true

# Base node logic for all JobesWar layout nodes
module JobesWar
  module Base
    class Node
      attr_accessor :parent

      def initialize(parent: nil)
        @parent = parent
        @pastel = nil
      end

      def root
        @root ||= parent&.root
      end

      def pastel
        @pastel ||= root&.pastel || Pastel.new
      end

      def available_width
        parent&.available_width || default_terminal_width
      end

      def calculated_width
        raise NotImplementedError, "subclasses must implement #calculated_width"
      end

      private

      def default_terminal_width
        require "tty-screen"
        TTY::Screen.width
      end
    end
  end
end
