# frozen_string_literal: true

module Mobilis
  module Node
    class Cassandra < Mobilis::Base::Node
      IDENTIFIER = /\A[a-z][a-z0-9_]*\z/
      attr_reader :datacenter_name, :keyspace_name, :schema_path, :version_tag

      def initialize(name, datacenter_name: "datacenter1", keyspace_name: nil, schema_path: nil,
                     version_tag: nil, **kwargs)
        super(name, **kwargs)
        datacenter(datacenter_name)
        keyspace(keyspace_name) if keyspace_name
        schema_file(schema_path) if schema_path
        version(version_tag) if version_tag
      end

      def datacenter(value)
        value = value.to_s
        raise ArgumentError, "Cassandra datacenter must be an identifier" unless IDENTIFIER.match?(value)
        @datacenter_name = value
        self
      end

      def keyspace(value)
        value = value.to_s
        raise ArgumentError, "Cassandra keyspace must be an identifier" unless IDENTIFIER.match?(value)
        @keyspace_name = value
        self
      end

      def schema_file(path)
        raise ArgumentError, "Cassandra schema file must be a readable .cql file" unless path.is_a?(String) && path.end_with?(".cql") && File.file?(path)
        @schema_path = File.expand_path(path)
        self
      end

      def version(tag)
        raise ArgumentError, "Invalid Cassandra image version" unless tag.is_a?(String) && tag.match?(/\A[0-9]+(?:\.[0-9]+){0,2}(?:-[a-z0-9.-]+)?\z/)
        @version_tag = tag
        self
      end

      def to_h
        super.merge(datacenter_name: datacenter_name, keyspace_name: keyspace_name,
                    schema_path: schema_path, version_tag: version_tag)
      end
    end
  end
end
