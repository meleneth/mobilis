module Mobilis
  module PrettyPrint
    class ColumnBuilder
      attr_reader :columns

      def initialize
        @columns = []
      end

      def column(key, width: nil, mode: :auto)
        @columns << Mobilis::PrettyPrint::Column.new(key, width: width, mode: mode)
      end
    end
  end
end
