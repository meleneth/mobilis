# frozen_string_literal: true

require "prism"

module Mobilis
  module Browser
    class SourceDocument
      SERVICE_TYPES = %i[
        airflow alloy cassandra envoy fastapi flask go_http goaws google_pubsub
        grafana grafbase jaeger kafka localstack loki mysql otel_collector
        pgadmin postgres prometheus rack rails redis s3 s3_storage
      ].freeze
      PROPERTY_SCHEMAS = {
        rails: {api: {kind: :boolean, default: false}},
        rack: {instances: {kind: :integer, default: 1}},
        s3: {buckets: {kind: :strings, default: []}},
        s3_storage: {buckets: {kind: :strings, default: []}},
        kafka: {brokers: {kind: :integer, default: 1}, publish_port: {kind: :boolean, default: false}},
        google_pubsub: {project: {kind: :string, default: "mobilis-local"}, publish_port: {kind: :boolean, default: false}},
        fastapi: {port: {kind: :integer, default: 8000}, publish_port: {kind: :boolean, default: true}},
        go_http: {port: {kind: :integer, default: 8080}, publish_port: {kind: :boolean, default: true}},
        envoy: {port: {kind: :integer, default: 8080}, verification_port: {kind: :integer, default: nil}},
        grafbase: {port: {kind: :integer, default: nil}}
      }.freeze

      Declaration = Data.define(
        :id, :type, :name, :editable, :start_offset, :end_offset, :properties
      )
      Analysis = Data.define(:source, :system, :declarations, :errors) do
        def valid? = errors.empty?
      end

      attr_reader :source, :parse_result

      def initialize(source)
        @source = source
        @parse_result = Prism.parse(source)
      end

      def analyze
        syntax_errors = parse_result.errors.map do |error|
          "#{error.message} (line #{error.location.start_line}, column #{error.location.start_column + 1})"
        end
        return Analysis.new(source:, system: nil, declarations: [], errors: syntax_errors) unless syntax_errors.empty?

        system = evaluate
        unless system.is_a?(Mobilis::System)
          return Analysis.new(source:, system: nil, declarations: [], errors: ["Source must define a system with Mobilis::DSL.generate or Mobilis::DSL.build"])
        end

        Analysis.new(source:, system:, declarations: declarations, errors: [])
      rescue ArgumentError, KeyError, LoadError, NameError, NotImplementedError,
        RuntimeError, SecurityError, SyntaxError, SystemCallError, TypeError => error
        Analysis.new(source:, system: nil, declarations: [], errors: ["#{error.class}: #{error.message}"])
      end

      def rename(id, name)
        declaration, node = editable_declaration(id)
        raise ArgumentError, "Service name cannot be empty" if name.strip.empty?

        string = name_node(node)
        replace(string.content_loc.start_offset, string.content_loc.end_offset, escape_string(name, string))
      end

      def change_type(id, type)
        _declaration, node = editable_declaration(id)
        type = type.to_sym
        raise ArgumentError, "Unsupported service type #{type}" unless SERVICE_TYPES.include?(type)

        replace(node.message_loc.start_offset, node.message_loc.end_offset, type.to_s)
      end

      def remove(id)
        declaration, = editable_declaration(id)
        ranges = [line_range(declaration.start_offset, declaration.end_offset)]
        ranges.concat(relationship_nodes.filter_map do |node|
          line_range(node.location.start_offset, node.location.end_offset) if relationship_names(node).include?(normalize_name(declaration.name))
        end)
        ranges.uniq.sort_by(&:first).reverse_each.reduce(source) do |changed, (start_offset, end_offset)|
          replace_in(changed, start_offset, end_offset, "")
        end
      end

      def update_property(id, property, value)
        declaration, node = editable_declaration(id)
        property = property.to_sym
        schema = PROPERTY_SCHEMAS.fetch(declaration.type, {}).fetch(property) do
          raise ArgumentError, "#{declaration.type} does not expose #{property} as a visual property"
        end
        replacement = property_source(value, schema.fetch(:kind))
        keyword_hash = node.arguments&.arguments&.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        existing = keyword_hash&.elements&.find { |element| keyword_name(element) == property }

        if existing
          if literal_value(existing.value) == :dynamic
            raise ArgumentError, "Dynamic property expressions cannot be safely rewritten"
          end
          return replace(existing.value.location.start_offset, existing.value.location.end_offset, replacement)
        end

        closing = node.closing_loc
        raise ArgumentError, "Properties can only be added to a parenthesized service call" unless closing

        replace(closing.start_offset, closing.start_offset, ", #{property}: #{replacement}")
      end

      def add(type, name)
        type = type.to_sym
        raise ArgumentError, "Unsupported service type #{type}" unless SERVICE_TYPES.include?(type)
        raise ArgumentError, "Service name cannot be empty" if name.strip.empty?

        block = root_call&.block
        raise ArgumentError, "Source must contain a Mobilis::DSL.generate or .build block" unless block

        insertion = block.closing_loc.start_offset
        indent = declaration_nodes.first&.then { |node| source[line_start(node.location.start_offset)...node.location.start_offset] } || "  "
        replace(insertion, insertion, "#{indent}#{type}(#{name.dump})\n")
      end

      def add_dependency(from:, to:)
        block = root_call&.block
        raise ArgumentError, "Source must contain a Mobilis::DSL.generate or .build block" unless block

        insertion = block.closing_loc.start_offset
        replace(insertion, insertion, "  connect(from: #{from.dump}, to: #{to.dump})\n")
      end

      private

      def evaluate
        call = root_call
        evaluation_source = source
        if call&.name == :generate
          location = call.message_loc
          evaluation_source = replace(location.start_offset, location.end_offset, "build")
        end
        eval(evaluation_source, TOPLEVEL_BINDING, "mobilis-playground.rb", 1) # rubocop:disable Security/Eval
      end

      def declarations
        declaration_nodes.filter_map do |node|
          string = name_node(node)
          name = string&.unescaped
          Declaration.new(
            id: node.location.start_offset.to_s,
            type: node.name,
            name: name || "dynamic expression",
            editable: !string.nil?,
            start_offset: node.location.start_offset,
            end_offset: node.location.end_offset,
            properties: keyword_properties(node)
          )
        end
      end

      def root_call
        parse_result.value.statements.body.find do |node|
          node.is_a?(Prism::CallNode) && %i[build generate].include?(node.name) && node.receiver
        end
      end

      def declaration_nodes
        body = root_call&.block&.body
        return [] unless body.is_a?(Prism::StatementsNode)

        body.body.select do |node|
          node.is_a?(Prism::CallNode) && node.receiver.nil? && SERVICE_TYPES.include?(node.name)
        end
      end

      def relationship_nodes
        body = root_call&.block&.body
        return [] unless body.is_a?(Prism::StatementsNode)

        body.body.select do |node|
          node.is_a?(Prism::CallNode) && node.receiver.nil? && %i[connect route].include?(node.name)
        end
      end

      def relationship_names(node)
        keyword_hash = node.arguments&.arguments&.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        return [] unless keyword_hash

        keyword_hash.elements.filter_map do |element|
          next unless %i[from to candidate shadow].include?(keyword_name(element))

          value = literal_value(element.value)
          normalize_name(value) unless value == :dynamic
        end
      end

      def name_node(node)
        argument = node.arguments&.arguments&.first
        argument if argument.is_a?(Prism::StringNode)
      end

      def keyword_properties(node)
        keyword_hash = node.arguments&.arguments&.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        return {} unless keyword_hash

        keyword_hash.elements.to_h do |element|
          key = keyword_name(element)
          [key, literal_value(element.value)]
        end
      end

      def literal_value(node)
        case node
        when Prism::StringNode then node.unescaped
        when Prism::IntegerNode then node.value
        when Prism::TrueNode then true
        when Prism::FalseNode then false
        when Prism::NilNode then nil
        when Prism::ArrayNode
          values = node.elements.map { |element| literal_value(element) }
          values.include?(:dynamic) ? :dynamic : values
        else :dynamic
        end
      end

      def keyword_name(element)
        raw = element.key.respond_to?(:value) ? element.key.value : element.key.slice.delete_suffix(":")
        raw.to_sym
      end

      def property_source(value, kind)
        case kind
        when :boolean
          value == true || value.to_s == "true" ? "true" : "false"
        when :integer
          return "nil" if value.nil? || value.to_s.empty?

          Integer(value, 10).to_s
        when :string
          value.to_s.dump
        when :strings
          Array(value).flat_map { |entry| entry.to_s.split(",") }.map(&:strip).reject(&:empty?).map(&:dump).join(", ").then { |items| "[#{items}]" }
        else
          raise ArgumentError, "Unknown property kind #{kind}"
        end
      rescue ArgumentError
        raise ArgumentError, "#{value.inspect} is not a valid #{kind} value"
      end

      def editable_declaration(id)
        node = declaration_nodes.find { |candidate| candidate.location.start_offset.to_s == id.to_s }
        raise ArgumentError, "Service declaration is no longer present" unless node

        declaration = declarations.find { |candidate| candidate.id == id.to_s }
        raise ArgumentError, "Dynamic service names cannot be safely rewritten" unless declaration&.editable

        [declaration, node]
      end

      def escape_string(value, string_node)
        quote = string_node.opening_loc&.slice == "'" ? "'" : '"'
        value.to_s.gsub("\\", "\\\\").gsub(quote, "\\#{quote}")
      end

      def line_start(offset)
        source.rindex("\n", offset - 1)&.+(1) || 0
      end

      def line_range(start_offset, end_offset)
        start_offset = line_start(start_offset)
        end_offset = source.index("\n", end_offset) || end_offset
        end_offset += 1 if end_offset < source.length
        [start_offset, end_offset]
      end

      def normalize_name(name)
        name.to_s.tr("_", "-")
      end

      def replace(start_offset, end_offset, replacement)
        replace_in(source, start_offset, end_offset, replacement)
      end

      def replace_in(content, start_offset, end_offset, replacement)
        content.byteslice(0, start_offset) + replacement + content.byteslice(end_offset, content.bytesize - end_offset).to_s
      end
    end
  end
end
