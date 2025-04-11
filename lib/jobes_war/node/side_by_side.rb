# frozen_string_literal: true

require "debug"
# Leaf node representing a styled, padded value in the layout tree
module JobesWar
  module Node
    class Box < JobesWar::Base::Node
      attr_reader :text, :styles, :padding, :children, :label_styles

      BAR = "│"

      PADDING_NORMAL = :normal
      PADDING_NONE = :none

      JUSTIFY_CENTER = :center
      JUSTIFY_LEFT = :left
      JUSTIFY_RIGHT = :right

      LABEL_LEFT = :left
      LABEL_RIGHT = :right

      def initialize(styles: [], padding_type: PADDING_NORMAL, children: [], **kwargs)
        super(**kwargs)
        @styles = styles
        @padding_type = padding_type
        @children = children
      end

      def calculated_width
        max_child_width = @children.collect(&:calculated_width).max + 2
        return @label.calculated_width + 2 if @label.calculated_width > max_child_width

        max_child_width + 4
      end

      def render
        content = []
        content << "#{ul_corner}#{rendered_label}#{label_bar}#{ur_corner}"
        @children.each do |child|
          right_pad_amount = calculated_width - child.calculated_width - 4
          right_pad_amount = [right_pad_amount, 1].max
          right_pad = " " * right_pad_amount
          content << "#{bar} #{child.render}#{right_pad}#{bar}"
        end
        content << "#{bl_corner}#{bottom_bar}#{br_corner}"
        content << ""
        content.join("\n")
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
