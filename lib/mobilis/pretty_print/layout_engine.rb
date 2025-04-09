module Mobilis
  module PrettyPrint
    class LayoutEngine
      def initialize(jobes, total_width:)
        @jobes = jobes
        @width = total_width
      end

      def render
        calculate_column_layout
        build_lines
      end

      private

      def calculate_column_layout
        fixed   = @jobes.columns.select { _1.mode == :fixed }
        autos   = @jobes.columns.select { _1.mode == :auto }
        flexes  = @jobes.columns.select { _1.mode == :flex }

        fixed_total = fixed.sum(&:width)
        autos_total = autos.sum { auto_width_for(_1) }

        remaining = @width - fixed_total - autos_total - margin_space

        flex_width = remaining / [1, flexes.size].max

        @column_layout = {}
        @jobes.columns.each do |col|
          @column_layout[col.key] =
            case col.mode
            when :fixed then col.width
            when :auto  then auto_width_for(col)
            when :flex  then flex_width
            end
        end
      end

      def auto_width_for(col)
        index = @jobes.columns.index(col)
        @jobes.rows.map { cell_display_width(_1.cells[index]) }.max || 0
      end

      def margin_space
        # borders + padding per column
        @jobes.columns.size * 3 + 2
      end

      def cell_display_width(cell)
        Pastel.new.strip(cell.to_s).size
      end

      def build_lines
        # TODO: actual box drawing and nested child rendering
        ["┌─ #{@jobes.label} ─┐"] +
          @jobes.rows.map { |r| render_row(r) } +
          ["└───────────────┘"]
      end

      def render_row(row)
        row.cells.map.with_index do |cell, i|
          col = @jobes.columns[i]
          width = @column_layout[col.key]
          clipped = clip(cell.to_s, width)
          clipped.ljust(width)
        end.join(" │ ").prepend("│ ").concat(" │")
      end

      def clip(str, width)
        clean = Pastel.new.strip(str)
        return str if clean.size <= width

        visible = clean[0...width - 1]
        "#{visible}…"
      end
    end
  end
end
