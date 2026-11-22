# frozen_string_literal: true

module Mobilis
  module Node
    class Kafka < Mobilis::Base::Node
      TOPIC_NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,248}\z/
      GROUP_NAME = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,248}\z/
      attr_reader :topics, :publish_port, :brokers

      def initialize(name, topics: [], publish_port: false, brokers: 1, **kwargs)
        super(name, **kwargs)
        unless brokers.is_a?(Integer) && (brokers == 1 || (brokers >= 3 && brokers.odd?))
          raise ArgumentError, "Kafka brokers must be 1 or an odd number of at least 3"
        end
        @brokers = brokers
        @topics = []
        Array(topics).each do |entry|
          topic(entry.fetch(:name), partitions: entry.fetch(:partitions),
                retention_ms: entry.fetch(:retention_ms), cleanup_policy: entry.fetch(:cleanup_policy),
                replication_factor: entry[:replication_factor])
        end
        @publish_port = publish_port == true
      end

      def topic(name, partitions:, retention_ms:, cleanup_policy: "delete", replication_factor: nil)
        name = name.to_s
        raise ArgumentError, "Invalid Kafka topic name: #{name}" unless TOPIC_NAME.match?(name) && !%w[. ..].include?(name)
        raise ArgumentError, "Kafka partitions must be positive" unless partitions.is_a?(Integer) && partitions.positive?
        raise ArgumentError, "Kafka retention_ms must be positive" unless retention_ms.is_a?(Integer) && retention_ms.positive?
        raise ArgumentError, "Invalid Kafka cleanup policy" unless %w[delete compact].include?(cleanup_policy)
        replication_factor ||= brokers
        unless replication_factor.is_a?(Integer) && replication_factor.between?(1, brokers)
          raise ArgumentError, "Kafka topic replication factor must be between 1 and #{brokers}"
        end
        raise ArgumentError, "Duplicate Kafka topic #{name}" if topics.any? { |item| item[:name] == name }

        topics << {name: name, partitions: partitions, retention_ms: retention_ms,
                   cleanup_policy: cleanup_policy, replication_factor: replication_factor}
        self
      end

      # subscribe: [{topic: "events", group: "projection"}]
      def validate_connection!(publish:, subscribe:)
        publishes = publish.is_a?(Array) ? publish.map { |item| item.to_s } : (publish ? [publish.to_s] : [])
        subscriptions = subscribe || []
        consumes = subscriptions.map do |item|
          raise ArgumentError, "Kafka subscription needs topic: and group:" unless item.is_a?(Hash)

          topic_name = (item[:topic] || item["topic"] || raise(KeyError, "key not found: :topic")).to_s
          group = (item[:group] || item["group"] || raise(KeyError, "key not found: :group")).to_s
          raise ArgumentError, "Invalid Kafka group ID: #{group}" unless GROUP_NAME.match?(group)

          {topic: topic_name, group: group}
        end
        raise ArgumentError, "Kafka connection needs publish: or subscribe:" if publishes.empty? && consumes.empty?
        unknown = (publishes + consumes.map { |item| item[:topic] }).uniq - topics.map { |item| item[:name] }
        raise ArgumentError, "Undeclared Kafka topics: #{unknown.join(', ')}" unless unknown.empty?

        [publishes.uniq, consumes.uniq]
      end

      def to_h
        super.merge(topics: topics, publish_port: publish_port, brokers: brokers)
      end
    end
  end
end
