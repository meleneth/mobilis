# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Kafka < Mobilis::Base::ServiceWriter
      def write
        lines = ["#!/bin/bash", "set -euo pipefail"]
        realized_node.config_node.topics.sort_by { |topic| topic[:name] }.each do |topic|
          name = topic.fetch(:name)
          lines << "/opt/kafka/bin/kafka-topics.sh --bootstrap-server #{realized_node.name}:9092 --create --if-not-exists --topic #{name} --partitions #{topic.fetch(:partitions)} --replication-factor 1 --config retention.ms=#{topic.fetch(:retention_ms)} --config cleanup.policy=#{topic.fetch(:cleanup_policy)}"
          lines << "/opt/kafka/bin/kafka-configs.sh --bootstrap-server #{realized_node.name}:9092 --entity-type topics --entity-name #{name} --alter --add-config retention.ms=#{topic.fetch(:retention_ms)},cleanup.policy=#{topic.fetch(:cleanup_policy)}"
          lines << "actual=$(/opt/kafka/bin/kafka-topics.sh --bootstrap-server #{realized_node.name}:9092 --describe --topic #{name})"
          lines << "[[ \"$actual\" == *'PartitionCount: #{topic.fetch(:partitions)}'* ]] || { echo 'Topic #{name} has wrong partition count' >&2; exit 1; }"
        end
        File.write("provision.sh", lines.join("\n") + "\n")
      end
    end
  end
end
