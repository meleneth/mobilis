# Leaf node representing a styled, padded value in the layout tree
module JobesWar
  module Node
    class Value < JobesWar::Base::Node
      attr_reader :text, :styles, :padding

      def initialize(text, styles: [], padding: 0, **kwargs)
        super(**kwargs)
        @text = text.to_s
        @styles = styles
        @padding = padding
      end

      def calculated_width
        text.size + (2 * padding)
      end

      def render
        each_line.to_a[0]
      end

      def each_line
        return enum_for(:each_line) unless block_given?

        content = " " * padding + text + " " * padding
        yield apply_styles(content)
      end

      private

      def apply_styles(str)
        pastel.decorate(str, *styles)
      end
    end
  end
end
