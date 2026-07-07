module Mobilis
  module Model
    class Script
      attr_accessor :filename, :content

      def initialize(filename, content)
        @filename = filename
        @content = content
      end

      def to_h
        {
          type: self.class.name,
          filename: @filename,
          content: @content
        }
      end

      def write_file
        ::File.write(@filename, @content)
      end

      def self.from_h(hash)
        new(hash[:filename], hash[:content])
      end
    end
  end
end
