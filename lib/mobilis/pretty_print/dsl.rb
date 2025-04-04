# frozen_string_literal: true

require "pastel"

module Mobilis
  module PrettyPrint
    module DSL
      def ppx(pp, &block)
        context = Context.new(pp, self)
        context.instance_eval(&block)
      end

      class Context
        attr_reader :pp, :indent_level, :pastel, :target

        def initialize(pp, target, indent_level = 0)
          @pp = pp
          @indent_level = indent_level
          @target = target
          @pastel = ::Pastel.new(enabled: ENV["DISABLE_COLOR_OUTPUT"] != "1")
        end

        def object
          target
        end

        def heading(text)
          pp.text(indent + pastel.bold.blue(text.to_s))
          pp.breakable
        end

        def line(label, value)
          pp.breakable
          pp.text(indent + pastel.cyan("#{label}: ") + value.to_s)
        end

        def row(*columns, note: nil)
          columns = columns.map(&:to_s)
          width = columns.map(&:length).max
          padded = columns.map { |c| c.ljust(width) }.join(pastel.white(" | "))
          padded += "  #{pastel.dim("# #{note}")}" if note
          pp.breakable
          pp.text(indent + padded)
        end

        def section(label, items)
          pp.text(indent + pastel.magenta("#{label}:"))
          nested = self.class.new(pp, indent_level + 2)
          items.each do |item|
            item.pretty_print(pp) # Each item will run its own DSL with shared pp
          end
        end

        private

        def indent
          " " * indent_level
        end
      end
    end
  end
end
