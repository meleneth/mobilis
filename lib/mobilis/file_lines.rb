# frozen_string_literal: true

require "forwardable"

module Mobilis
  class FileLines
    attr_accessor :lines
    attr_reader :filename

    extend Forwardable

    def_delegator :@lines, :index
    def_delegator :@lines, :[]
    def_delegator :@lines, :[]=

    def self.from_glob(my_glob)
      files = []
      Dir.glob(my_glob).each do |filename|
        File.open(filename) do |fh|
          files << from_filehandle(filename: filename, handle: fh)
        end
      end
      files
    end

    def self.from_file(filename:)
      File.open(filename) do |fh|
        return FileLines.from_filehandle(filename: filename, handle: fh)
      end
    end

    def self.from_contents(filename:, contents:)
      FileLines.new filename: filename, lines: contents.lines
    end

    def self.from_filehandle(filename:, handle:)
      FileLines.new filename: filename, lines: handle.readlines.map(&:chomp)
    end

    def initialize(filename:, lines: [])
      @lines = lines
      @filename = filename
    end

    def as_file
      "#{@lines.join "\n"}\n"
    end

    def gsub!(pattern, replacement)
      @lines.each do |l|
        l.gsub!(pattern, replacement)
      end
    end

    def save
      File.write(filename, as_file)
    end

    def match(pattern)
      @lines.filter { |l| l.match pattern }
    end

    def bare_filename
      File.basename(@filename, ".rb")
    end
  end
end
