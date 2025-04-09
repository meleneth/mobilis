module Mobilis
  module PrettyPrint
    class Column
      attr_reader :key, :mode, :width

      def initialize(key, width: nil, mode: :auto)
        @key   = key
        @mode  = mode
        @width = width
      end
    end
  end
end
