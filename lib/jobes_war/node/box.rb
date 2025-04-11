# frozen_string_literal: true

require "debug"
# Leaf node representing a styled, padded value in the layout tree
module JobesWar
  module Node
    class Box < JobesWar::Base::Node
      attr_reader :text, :styles, :padding, :children, :label_styles

      UL_CORNER = "┌"
      BL_CORNER = "└"
      UR_CORNER = "┐"
      BR_CORNER = "┘"
      DASH = "─"
      BAR = "│"
      T_LEFT = "├"
      T_RIGHT = "┤"
      T_TOP = "┬"
      T_BOTTOM = "┴"

      PADDING_NORMAL = :normal
      PADDING_NONE = :none

      JUSTIFY_CENTER = :center
      JUSTIFY_LEFT = :left
      JUSTIFY_RIGHT = :right

      LABEL_LEFT = :left
      LABEL_RIGHT = :right

      def initialize(styles: [], label: nil, label_styles: [], padding: 0, **kwargs)
        super(**kwargs)
        @text = text.to_s
        @styles = styles
        @padding = padding
        @label = JobesWar::Node::Value.new(" #{label} ", styles: label_styles) if label
        @label_styles = label_styles
        @children = []
      end

      def calculated_width
        max_child_width = 0
        max_child_width = @children.collect(&:calculated_width).max + 2 unless @children.empty?
        return @label.calculated_width + 2 if @label && (@label.calculated_width > max_child_width)

        max_child_width + 4
      end

      def render
        lines = each_line.to_a
        lines.join("\n")
      end

      def each_line
        return enum_for(:each_line) unless block_given?

        yield "#{ul_corner}#{rendered_label}#{label_bar}#{ur_corner}"
        @children.each do |child|
          right_pad_amount = calculated_width - child.calculated_width - 3
          right_pad_amount = [right_pad_amount, 1].max
          right_pad = " " * right_pad_amount
          child.each_line do |rendered|
            yield "#{bar} #{rendered}#{right_pad}#{bar}"
          end
        end
        yield "#{bl_corner}#{bottom_bar}#{br_corner}"
      end

      def <<(child)
        @children << child
      end

      private

      def label_bigger?
        label_width + 2 == calculated_width
      end

      def ul_corner
        apply_styles(UL_CORNER)
      end

      def ur_corner
        apply_styles(UR_CORNER)
      end

      def bl_corner
        apply_styles(BL_CORNER)
      end

      def br_corner
        apply_styles(BR_CORNER)
      end

      def bar
        apply_styles(BAR)
      end

      def bottom_bar
        apply_styles(DASH * (calculated_width - 2))
      end

      def label_bar
        apply_styles(DASH * (calculated_width - 2 - label_width))
      end

      def rendered_label
        @label&.render || ""
      end

      def apply_styles(str)
        pastel.decorate(str, *styles)
      end

      def label_width
        return @label.calculated_width if @label

        0
      end

      def non_label_border_width
        calculated_width - 2 - label_width
      end
    end
  end
end
