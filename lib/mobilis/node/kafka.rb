# frozen_string_literal: true

module Mobilis
  module Node
    class Kafka < Mobilis::Base::Node
      TOPIC_NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,248}\z/
      GROUP_NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,248}\z/
      attr_reader :topics, :publish_port

      def initialize(name, topics: [], publish_port: false, **kwargs)
        super(name, **kwargs)
        @topics = []
        Array(topics).each do |entry|
          topic(entry.fetch(:name), partitions: entry.fetch(:partitions),
                retention_ms: entry.fetch(:retention_ms), cleanup_policy: entry.fetch(:cleanup_policy))
        end
        @publish_port = publish_port == true
      end

      def topic(name, partitions:, retention_ms:, cleanup_policy: "delete")
        name = name.to_s
        raise ArgumentError, "Invalid Kafka topic name: #{name}" unless TOPIC_NAME.match?(name) && !%w[. ..].include?(name)
        raise ArgumentError, "Kafka partitions must be positive" unless partitions.is_a?(Integer) && partitions.positive?
        raise ArgumentError, "Kafka retention_ms must be positive" unless retention_ms.is_a?(Integer) && retention_ms.positive?
        raise ArgumentError, "Invalid Kafka cleanup policy" unless %w[delete compact].include?(cleanup_policy)
        raise ArgumentError, "Duplicate Kafka topic #{name}" if topics.any? { |item| item[:name] == name }

        topics << {name: name, partitions: partitions, retention_ms: retention_ms, cleanup_policy: cleanup_policy}
        self
      end

      # subscribe: [{topic: "events", group: "projection"}]
      def validate_connection!(publish:, subscribe:)
        publishes = Array(publish).map(&:to_s)
        consumes = Array(subscribe).map do |item|
          raise ArgumentError, "Kafka subscription needs topic: and group:" unless item.is_a?(Hash)

          entry = item.transform_keys(&:to_sym)
          topic_name = entry.fetch(:topic).to_s
          group = entry.fetch(:group).to_s
          raise ArgumentError, "Invalid Kafka group ID: #{group}" unless GROUP_NAME.match?(group)

          {topic: topic_name, group: group}
        end
        raise ArgumentError, "Kafka connection needs publish: or subscribe:" if publishes.empty? && consumes.empty?
        unknown = (publishes + consumes.map { |item| item[:topic] }).uniq - topics.map { |item| item[:name] }
        raise ArgumentError, "Undeclared Kafka topics: #{unknown.join(', ')}" unless unknown.empty?

        [publishes.uniq, consumes.uniq]
      end

      def to_h
        super.merge(topics: topics, publish_port: publish_port)
      end
    end
  end
end
