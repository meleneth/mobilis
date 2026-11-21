# frozen_string_literal: true

require "digest"
require "prism"

module Diesl
  class Conflict < StandardError; end
  class UnsafeEdit < StandardError; end
  class InvalidSource < StandardError; end

  # Application-independent, immutable source transformation surface.
  # All offsets come from Prism and are byte offsets, not character indices.
  class Source
    attr_reader :text, :parse_result

    def initialize(text)
      @text = String(text).dup.freeze
      @parse_result = Prism.parse(@text)
    end

    def revision
      Digest::SHA256.hexdigest(text)
    end

    def valid?
      parse_result.errors.empty?
    end

    def errors
      parse_result.errors.map do |error|
        "#{error.message} (line #{error.location.start_line}, column #{error.location.start_column + 1})"
      end
    end

    def calls(name: nil)
      names = name && Array(name).map(&:to_sym)
      walk(parse_result.value).select do |node|
        node.is_a?(Prism::CallNode) && (names.nil? || names.include?(node.name))
      end
    end

    def literal(node)
      case node
      when Prism::StringNode then node.unescaped
      when Prism::SymbolNode then node.unescaped.to_sym
      when Prism::IntegerNode then node.value
      when Prism::FloatNode then node.value
      when Prism::TrueNode then true
      when Prism::FalseNode then false
      when Prism::NilNode then nil
      when Prism::ArrayNode then node.elements.map { |element| literal(element) }
      when Prism::HashNode, Prism::KeywordHashNode
        node.elements.to_h do |element|
          raise UnsafeEdit, "Hash splats and dynamic keys are not literal" unless element.respond_to?(:key)
          [literal(element.key), literal(element.value)]
        end
      else
        raise UnsafeEdit, "Cannot safely edit dynamic #{node&.class || 'missing'} expression"
      end
    end

    def replace_literal(node, value, expected_revision:)
      literal(node) # refuse dynamic expressions even if replacement itself is safe
      replace(node.location.start_offset, node.location.end_offset, encode(value),
        expected_revision:)
    end

    def replace(start_byte, end_byte, replacement, expected_revision:)
      raise Conflict, "Source revision changed" unless expected_revision == revision
      raise InvalidSource, errors.join("\n") unless valid?
      raise UnsafeEdit, "Invalid source byte range" unless start_byte.is_a?(Integer) &&
        end_byte.is_a?(Integer) && start_byte >= 0 && end_byte >= start_byte &&
        end_byte <= text.bytesize
      raise UnsafeEdit, "Replacement must be a string" unless replacement.is_a?(String)

      changed = text.b.byteslice(0, start_byte) + replacement.b +
        text.b.byteslice(end_byte, text.bytesize - end_byte)
      candidate = self.class.new(changed.force_encoding(text.encoding))
      raise InvalidSource, candidate.errors.join("\n") unless candidate.valid?

      candidate.text
    end

    def encode(value)
      case value
      when String then value.dump
      when Symbol then ":#{value}"
      when Integer, Float then value.to_s
      when TrueClass then "true"
      when FalseClass then "false"
      when NilClass then "nil"
      when Array then "[#{value.map { |entry| encode(entry) }.join(', ')}]"
      when Hash then "{#{value.map { |key, entry| "#{encode(key)} => #{encode(entry)}" }.join(', ')}}"
      else raise UnsafeEdit, "Cannot represent #{value.class} as a Ruby literal"
      end
    end

    private

    def walk(node, found = [])
      return found unless node

      found << node
      node.compact_child_nodes.each { |child| walk(child, found) }
      found
    end
  end
end
