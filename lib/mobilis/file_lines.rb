# frozen_string_literal: true

module Mobilis
  class FileLines
    attr_reader :filename, :lines

    def self.from(filename)
      new(filename).load
    end

    def self.edit(filename, &block)
      instance = from(filename)
      instance.instance_eval(&block)
      instance.save
    end

    def self.create(filename, &block)
      instance = new(filename)
      instance.instance_eval(&block)
      instance.save
    end

    def initialize(filename)
      @filename = filename
      @lines = []
    end

    def load
      @lines = File.readlines(filename, chomp: true)
      self
    end

    def replace_line(pattern)
      lines.map! do |line|
        if line.match?(pattern)
          yield(line)
        else
          line
        end
      end
      self
    end

    def insert_before(pattern, *new_lines)
      index = lines.index { |line| line.match?(pattern) }
      raise "No line matches #{pattern.inspect}" unless index

      lines.insert(index, *new_lines)
      self
    end

    def insert_after(pattern, *new_lines)
      index = lines.index { |line| line.match?(pattern) }
      raise "No line matches #{pattern.inspect}" unless index

      lines.insert(index + 1, *new_lines)
      self
    end

    def delete_if(&block)
      lines.reject!(&block)
      self
    end

    def gsub_lines(pattern, replacement)
      lines.map! { |line| line.gsub(pattern, replacement) }
      self
    end

    def save(path_override = nil)
      File.write(path_override || filename, lines.join("\n") + "\n")
      self
    end

    def set_comment_char(char)
      @comment_char = char
    end

    def comment_char
      @comment_char ||= detect_comment_char_from_filename
    end

    def block_comment(position, comment_lines)
      index = case position
              when Integer
                position
              when Regexp
                lines.index { |l| l.match?(position) }
              else
                raise ArgumentError, "position must be Integer or Regexp"
              end

      raise "No matching line for #{position.inspect}" unless index

      base = lines[index]
      padding = base.length + 2
      comment_lines = comment_lines.map.with_index do |line, i|
        if i == 0
          "#{base} #{comment_char} #{line}".rstrip
        else
          " " * padding + "#{comment_char} #{line}".rstrip
        end
      end

      lines[index, 1] = comment_lines
      self
    end

    private

    def detect_comment_char_from_filename
      ext = File.extname(filename).downcase
      case ext
      when ".rb", ".py", ".yml", ".yaml", ".env"
        "#"
      when ".js", ".ts", ".jsx", ".tsx", ".c", ".cpp", ".h", ".java"
        "//"
      when ".sh"
        "#"
      when ".toml"
        "#"
      else
        "#"
      end
    end
  end
end
