# frozen_string_literal: true

module Mobilis
  module PrettyPrint
    class JobesWar
      attr_reader :indent, :label, :columns, :rows, :children

      def initialize(indent: 0, label: nil, label_align: :center, footer_label: nil, footer_align: :center)
        @indent        = indent
        @label         = label
        @label_align   = label_align
        @footer_label  = footer_label
        @footer_align  = footer_align
        @columns       = []
        @rows          = []
        @children      = []
        @column_layout = nil # populated on render
      end

      def define_columns(&block)
        builder = Mobilis::PrettyPrint::ColumnBuilder.new
        builder.instance_eval(&block)
        @columns = builder.columns
      end

      def add_row(*cells)
        @rows << Row.new(cells)
      end

      def nest(label, &block)
        child = Mobilis::PrettyPrint::JobesWar.new(indent: @indent + 2, label: label)
        children << child
        yield child
      end

      def render_to_lines(total_width: TTY::Screen.width)
        Mobilis::PrettyPrint::LayoutEngine.new(self, total_width: total_width).render
      end
    end
  end
end
