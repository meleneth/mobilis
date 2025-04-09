module Mobilis
  module PrettyPrint
    class Row
      attr_reader :cells

      def initialize(cells)
        @cells = cells
      end
    end
  end
end
