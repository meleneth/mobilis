# frozen_string_literal: true

require "json"
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
      Relationship = Data.define(
        :id, :kind, :from, :to, :editable, :start_offset, :end_offset, :properties
      )
      ArchiveDeclaration = Data.define(
        :id, :name, :editable, :payload, :payload_start_offset, :payload_end_offset,
        :start_offset, :end_offset, :parent_revision, :bundle
      )
      Analysis = Data.define(:source, :system, :declarations, :relationships, :archives, :errors) do
        def valid? = errors.empty?
      end

      attr_reader :source, :parse_result

      def initialize(source)
        # The native Mobilis generator does not require browser authoring gems.
        # Load Diesl only when the browser SourceDocument is instantiated.
        require "diesl"
        @source = source
        # Diesl owns parsing, revisioning and source-range replacement.
        # Mobilis only interprets the parsed tree as a system definition.
        @diesl_source = Diesl::Source.new(source)
        @parse_result = @diesl_source.parse_result
      end

      def analyze
        syntax_errors = @diesl_source.errors
        return invalid_analysis(syntax_errors) unless syntax_errors.empty?

        system = evaluate
        unless system.is_a?(Mobilis::System)
          return invalid_analysis(["Source must define a system with Mobilis::DSL.generate or Mobilis::DSL.build"])
        end

        Analysis.new(source:, system:, declarations: declarations, relationships: relationships, archives: archives, errors: [])
      rescue ArgumentError, KeyError, LoadError, NameError, NotImplementedError,
        RuntimeError, SecurityError, SyntaxError, SystemCallError, TypeError => error
        invalid_analysis(["#{error.class}: #{error.message}"])
      end

      def rename(id, name)
        declaration, node = editable_declaration(id)
        raise ArgumentError, "Service name cannot be empty" if name.strip.empty?

        string = name_node(node)
        replace(string.content_loc.start_offset, string.content_loc.end_offset, escape_string(name, string))
      end

      # Form edits already carry the declaration identity. Never infer a
      # service rename from a diff when we have that identity: rewrite the
      # declaration and its Prism-resolved literal bindings in one transaction.
      def rename_with_references(id, name)
        declaration, node = editable_declaration(id)
        raise ArgumentError, "Service name cannot be empty" if name.strip.empty?

        old_name = declaration.name
        return source if name == old_name
        if declarations.any? { |candidate|
          candidate.id != declaration.id && normalize_name(candidate.name) == normalize_name(name)
        }
          raise ArgumentError, "Service name #{name.inspect} is already declared"
        end
        unless declarations.count { |candidate| normalize_name(candidate.name) == normalize_name(old_name) } == 1
          raise ArgumentError, "Service identity #{old_name.inspect} is ambiguous"
        end

        replacements = service_name_literals(old_name).map do |literal|
          [literal.content_loc.start_offset, literal.content_loc.end_offset, escape_string(name, literal)]
        end
        # The declaration must itself be a member of the indexed occurrences.
        declaration_range = name_node(node).content_loc
        unless replacements.any? { |start_offset, end_offset,|
          start_offset == declaration_range.start_offset && end_offset == declaration_range.end_offset
        }
          raise ArgumentError, "Service declaration is missing from the reference index"
        end

        changed = replacements.sort_by { |start_offset,| -start_offset }.reduce(source) do |current, (start_offset, end_offset, replacement)|
          replace_in(current, start_offset, end_offset, replacement)
        end
        analysis = self.class.new(changed).analyze
        raise ArgumentError, analysis.errors.join("\n") unless analysis.valid?

        changed
      end

      # Compare successive Prism ASTs to find an isolated edit of one service
      # declaration. Reuse the same atomic identity-aware rename used by the
      # visual builder, rather than guessing dependent offsets from a text diff.
      #
      # A paste with unrelated changes is not an implicit refactor. Keeping
      # that distinction protects deliberate DSL edits from accidental rewrites.
      def propagate_service_rename(edited_source)
        return nil unless parse_result.errors.empty?
        return nil if edited_source == source

        updated_document = self.class.new(edited_source)
        return nil unless updated_document.parse_result.errors.empty?

        old_nodes = declaration_nodes
        new_nodes = updated_document.send(:declaration_nodes)
        return nil unless old_nodes.length == new_nodes.length

        candidates = old_nodes.zip(new_nodes).filter_map do |original, updated|
          next unless original.name == updated.name

          old_literal = name_node(original)
          new_literal = updated_document.send(:name_node, updated)
          next unless old_literal && new_literal
          next if old_literal.unescaped == new_literal.unescaped

          [original, old_literal, new_literal]
        end
        return nil unless candidates.length == 1

        original_node, old_literal, new_literal = candidates.first
        old_start = old_literal.content_loc.start_offset
        old_end = old_literal.content_loc.end_offset
        new_start = new_literal.content_loc.start_offset
        new_end = new_literal.content_loc.end_offset

        # Excluding the edited string's contents must leave the exact same
        # source bytes. This distinguishes a single keystroke from a paste
        # that modifies multiple independent expressions.
        return nil unless source.byteslice(0, old_start) == edited_source.byteslice(0, new_start)
        return nil unless source.byteslice(old_end..) == edited_source.byteslice(new_end..)

        rename_with_references(original_node.location.start_offset.to_s, new_literal.unescaped)
      rescue ArgumentError
        nil
      end

      # Collect literal occurrences, not textual matches. Their exact source
      # ranges come from Prism, and an embedded archive is opaque even when
      # its encoded payload happens to resemble a service name.
      def service_name_literals(name)
        block = root_call&.block
        return [] unless block

        result = []
        visit = lambda do |node|
          next unless node

          if node.is_a?(Prism::CallNode) && node.name == :embedded_archive
            next
          end

          if node.is_a?(Prism::StringNode) && normalize_name(node.unescaped) == normalize_name(name)
            result << node
          end
          node.compact_child_nodes.each { |child| visit.call(child) }
        end
        visit.call(block.body)
        result
      end

      # System-wide root arguments have their own editing affordances.
      # Do not rewrite a dynamic Ruby expression simply because evaluation
      # happened to yield an integer.
      def starting_port_editable?
        call = root_call
        return false unless call&.closing_loc && parse_result.errors.empty?

        element = keyword_elements(call).find { |entry| keyword_name(entry) == :starting_port }
        element.nil? || element.value.is_a?(Prism::IntegerNode)
      end

      def update_starting_port(value)
        raw = value.to_s.strip
        raise ArgumentError, "Starting port must be an integer between 1 and 65535" unless /\A[0-9]+\z/.match?(raw)

        number = Integer(raw, 10)
        raise ArgumentError, "Starting port must be an integer between 1 and 65535" unless (1..65_535).cover?(number)

        call = root_call
        raise ArgumentError, "System definition must use a parenthesized build/generate call" unless call&.closing_loc

        entry = keyword_elements(call).find { |candidate| keyword_name(candidate) == :starting_port }
        if entry
          unless entry.value.is_a?(Prism::IntegerNode)
            raise ArgumentError, "Cannot safely rewrite a computed starting_port expression"
          end

          node = entry.value
          return replace(node.location.start_offset, node.location.end_offset, number.to_s)
        end

        separator = call.arguments&.arguments&.empty? == false ? ", " : ""
        position = call.closing_loc.start_offset
        replace(position, position, "#{separator}starting_port: #{number}")
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

        insertion = relationship_nodes.first&.location&.start_offset || block.closing_loc.start_offset
        indent = declaration_nodes.first&.then { |node| source[line_start(node.location.start_offset)...node.location.start_offset] } || "  "
        replace(insertion, insertion, "#{indent}#{type}(#{name.dump})\n")
      end

      def add_relationship(from:, to:, kind: :connect, properties: {})
        block = root_call&.block
        raise ArgumentError, "Source must contain a Mobilis::DSL.generate or .build block" unless block
        kind = kind.to_sym
        raise ArgumentError, "Relationship type must be connect or route" unless %i[connect route].include?(kind)

        insertion = block.closing_loc.start_offset
        options = properties.filter_map do |key, value|
          next if value.nil? || value == ""

          ", #{key}: #{ruby_literal(value)}"
        end.join
        replace(insertion, insertion, "  #{kind}(from: #{from.dump}, to: #{to.dump}#{options})\n")
      end

      def update_relationship(id, property, value)
        relationship, node = editable_relationship(id)
        property = property.to_sym
        if property == :kind
          kind = value.to_sym
          raise ArgumentError, "Relationship type must be connect or route" unless %i[connect route].include?(kind)
          if kind != relationship.kind && (relationship.properties.keys - %i[from to]).any?
            raise ArgumentError, "Remove relationship-specific options before changing its type"
          end
          return replace(node.message_loc.start_offset, node.message_loc.end_offset, kind.to_s)
        end

        allowed = relationship.kind == :connect ? %i[to force_skip_health_checks publish subscribe] : %i[to candidate shadow mirror_percent candidate_percent]
        raise ArgumentError, "#{property} is not supported by #{relationship.kind}" unless allowed.include?(property)

        element = keyword_elements(node).find { |candidate| keyword_name(candidate) == property }
        if value.nil? || value == ""
          raise ArgumentError, "A relationship target cannot be empty" if property == :to
          return source unless element

          start_offset, end_offset = optional_keyword_range(node, element)
          return replace(start_offset, end_offset, "")
        end

        replacement = relationship_property_source(property, value)
        if element
          raise ArgumentError, "Dynamic relationship expressions cannot be safely rewritten" if literal_value(element.value) == :dynamic

          replace(element.value.location.start_offset, element.value.location.end_offset, replacement)
        else
          closing = node.closing_loc
          raise ArgumentError, "Relationship options require a parenthesized call" unless closing

          replace(closing.start_offset, closing.start_offset, ", #{property}: #{replacement}")
        end
      end

      def remove_relationship(id)
        _relationship, node = editable_relationship(id)
        start_offset, end_offset = line_range(node.location.start_offset, node.location.end_offset)
        replace(start_offset, end_offset, "")
      end

      def commit_embedded_archive(id, path, content, parent_revision:)
        raise ArgumentError, "The parent Ruby source changed after this archive was opened" unless parent_revision == revision

        archive = archives.find { |candidate| candidate.id == id.to_s }
        raise ArgumentError, "Embedded archive declaration is no longer present" unless archive
        raise ArgumentError, "Dynamic embedded archive payloads cannot be safely rewritten" unless archive.editable

        payload = Mobilis::EmbeddedArchive.replace(archive.payload, path, content)
        changed = replace(archive.payload_start_offset, archive.payload_end_offset, payload)
        validation = self.class.new(changed).analyze
        raise ArgumentError, validation.errors.join("\n") unless validation.valid?

        changed
      end

      def revision = @diesl_source.revision

      private

      def invalid_analysis(errors)
        Analysis.new(source:, system: nil, declarations: [], relationships: [], archives: [], errors:)
      end

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

      def relationships
        relationship_nodes.map do |node|
          properties = keyword_properties(node)
          from = properties[:from]
          to = properties[:to]
          Relationship.new(
            id: "relationship-#{node.location.start_offset}",
            kind: node.name,
            from: from == :dynamic ? "dynamic expression" : normalize_name(from),
            to: to == :dynamic ? "dynamic expression" : normalize_name(to),
            editable: from != :dynamic && to != :dynamic,
            start_offset: node.location.start_offset,
            end_offset: node.location.end_offset,
            properties:
          )
        end
      end

      def archives
        archive_nodes.map do |node|
          name_node = node.arguments&.arguments&.first
          payload_element = keyword_elements(node).find { |element| keyword_name(element) == :payload }
          payload_node = payload_element&.value
          editable = name_node.is_a?(Prism::StringNode) && payload_node.is_a?(Prism::StringNode)
          payload = payload_node.unescaped if payload_node.is_a?(Prism::StringNode)
          ArchiveDeclaration.new(
            id: "archive-#{node.location.start_offset}",
            name: name_node.is_a?(Prism::StringNode) ? name_node.unescaped : "dynamic archive",
            editable:,
            payload:,
            payload_start_offset: payload_node&.content_loc&.start_offset,
            payload_end_offset: payload_node&.content_loc&.end_offset,
            start_offset: node.location.start_offset,
            end_offset: node.location.end_offset,
            parent_revision: revision,
            bundle: payload ? Mobilis::EmbeddedArchive.unpack(payload) : nil
          )
        end
      end

      def archive_nodes
        each_prism_node(root_call&.block).select do |node|
          node.is_a?(Prism::CallNode) && node.name == :embedded_archive
        end
      end

      def each_prism_node(node, result = [])
        return result unless node

        result << node
        node.compact_child_nodes.each { |child| each_prism_node(child, result) }
        result
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
        keyword_elements(node).to_h do |element|
          key = keyword_name(element)
          [key, literal_value(element.value)]
        end
      end

      def keyword_elements(node)
        keyword_hash = node.arguments&.arguments&.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
        keyword_hash ? keyword_hash.elements : []
      end

      # Preserve the Mobilis projection's :dynamic marker while delegating
      # actual Ruby literal interpretation to Diesl.
      def literal_value(node)
        @diesl_source.literal(node)
      rescue Diesl::UnsafeEdit
        :dynamic
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

      def editable_relationship(id)
        node = relationship_nodes.find { |candidate| "relationship-#{candidate.location.start_offset}" == id.to_s }
        raise ArgumentError, "Relationship declaration is no longer present" unless node

        relationship = relationships.find { |candidate| candidate.id == id.to_s }
        raise ArgumentError, "Dynamic relationships cannot be safely rewritten" unless relationship&.editable

        [relationship, node]
      end

      def relationship_property_source(property, value)
        case property
        when :to, :candidate, :shadow then value.to_s.dump
        when :force_skip_health_checks then value == true || value.to_s == "true" ? "true" : "false"
        when :mirror_percent, :candidate_percent then Integer(value, 10).to_s
        when :publish, :subscribe
          parsed = if value.is_a?(String) && value.lstrip.start_with?("[", "{")
                     JSON.parse(value)
                   else
                     value
                   end
          ruby_literal(parsed)
        else
          raise ArgumentError, "Unsupported relationship property #{property}"
        end
      rescue JSON::ParserError, ArgumentError => error
        raise ArgumentError, "Invalid #{property}: #{error.message}"
      end

      # Mobilis's relationship options historically serialize map keys as
      # strings, even when the caller passed symbols. Preserve that domain
      # convention while Diesl owns the actual Ruby literal serialization.
      def ruby_literal(value)
        @diesl_source.encode(stringify_map_keys(value))
      rescue Diesl::UnsafeEdit => error
        raise ArgumentError, error.message
      end

      def stringify_map_keys(value)
        case value
        when Array then value.map { |entry| stringify_map_keys(entry) }
        when Hash then value.to_h { |key, entry| [key.to_s, stringify_map_keys(entry)] }
        else value
        end
      end

      def optional_keyword_range(node, element)
        elements = keyword_elements(node)
        index = elements.index(element)
        raise ArgumentError, "Relationship option is no longer present" unless index

        previous_end = index.zero? ? node.opening_loc.end_offset : elements[index - 1].location.end_offset
        comma = source.index(",", previous_end)
        raise ArgumentError, "Cannot safely locate relationship option separator" unless comma && comma < element.location.start_offset

        [comma, element.location.end_offset]
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
        @diesl_source.replace(start_offset, end_offset, replacement, expected_revision: revision)
      end

      def replace_in(content, start_offset, end_offset, replacement)
        document = Diesl::Source.new(content)
        document.replace(start_offset, end_offset, replacement, expected_revision: document.revision)
      end
    end
  end
end
