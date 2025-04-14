# frozen_string_literal: true

module JobesWar
  module Node
    # This represents a # that contains values, and will provide hooks
    # for boxes to be able to render edge pieces that connect
    class TicTac < JobesWar::Base::Node
      attr_reader :styles, :children

      DASH = "-"
      BAR = "|"
      CROSSING = "+"

      def initialize(styles: [], children: [], **kwargs)
        super(**kwargs)
        @styles = styles
        @children = []
        children.each do |child|
          self << child
        end
      end

      def calculated_width
        column_max_widths.sum + ((@children[0].length - 1) * 3)
      end

      def <<(row)
        return @children << row if @children.empty?
        raise "Must have equal number of columns" unless @children[0].length == row.length

        @children << row
      end

      def column_max_widths
        return [] unless @children.length

        result = Array.new(@children.first.length, 0)
        @children.each do |child|
          (0...child.length).each do |index|
            result[index] = child[index].calculated_width if child[index].calculated_width > result[index]
          end
        end
        result
      end

      def render
        content = " " * padding + text + " " * padding
        apply_styles(content)
      end

      def each_line
        return enum_for(:each_line) unless block_given?

        max_widths = column_max_widths

        @children.each do |child|
          value = child.each_with_index.map do |cell, index|
            padding = " " * (max_widths[index] - cell.calculated_width)
            "#{cell.render}#{padding}"
          end.join(" | ")
          yield value
        end
      end

      private

      def apply_styles(str)
        pastel.decorate(str, *styles)
      end
    end
  end
end
