# frozen_string_literal: true

module Mobilis
  module Realized
    class Kafka < Mobilis::Base::ImageForm
      INTERNAL_PORT = 9092
      HOST_PORT = 9094

      def broker_count
        config_node.brokers
      end

      def broker_names
        (1..broker_count).map { |index| broker_name(index) }
      end

      def broker_name(index)
        index == 1 ? name : "#{name}-#{index}"
      end

      def bootstrap_servers
        broker_names.map { |broker| "#{broker}:#{INTERNAL_PORT}" }.join(",")
      end

      def min_insync_replicas
        broker_count == 1 ? 1 : (broker_count / 2) + 1
      end

      def initialize(env, node)
        super(env, node, Mobilis::ContainerVersions::KAFKA)
        @has_service_dir = true
        # Docker initializes named volumes with the image directory ownership.
        # The Apache image runs as uid 1000 and cannot format a root-owned bind mount.
        add_volume("#{name}-data", "/var/lib/kafka/data")
        declare_storage("data", "/var/lib/kafka/data")
        add_compose_raw_var("CLUSTER_ID", "MkU3OEVBNTcwNTJENDM2Qk")
        add_compose_raw_var("KAFKA_NODE_ID", "1")
        add_compose_raw_var("KAFKA_PROCESS_ROLES", "broker,controller")
        add_compose_raw_var("KAFKA_CONTROLLER_QUORUM_VOTERS", broker_names.each_with_index.map { |broker, index| "#{index + 1}@#{broker}:9093" }.join(","))
        add_compose_raw_var("KAFKA_CONTROLLER_LISTENER_NAMES", "CONTROLLER")
        add_compose_raw_var("KAFKA_LISTENER_SECURITY_PROTOCOL_MAP", "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,HOST:PLAINTEXT")
        host = node.publish_port
        add_compose_raw_var("KAFKA_LISTENERS", "PLAINTEXT://:9092,CONTROLLER://:9093#{',HOST://:9094' if host}")
        add_compose_raw_var("KAFKA_ADVERTISED_LISTENERS", "PLAINTEXT://#{name}:9092#{',HOST://localhost:9094' if host}")
        add_compose_raw_var("KAFKA_INTER_BROKER_LISTENER_NAME", "PLAINTEXT")
        add_compose_raw_var("KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", broker_count.to_s)
        add_compose_raw_var("KAFKA_DEFAULT_REPLICATION_FACTOR", broker_count.to_s)
        add_compose_raw_var("KAFKA_MIN_INSYNC_REPLICAS", min_insync_replicas.to_s)
        add_compose_raw_var("KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", broker_count.to_s)
        add_compose_raw_var("KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", min_insync_replicas.to_s)
        add_compose_raw_var("KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", "0")
        add_compose_raw_var("KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR", broker_count.to_s)
        add_compose_raw_var("KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR", min_insync_replicas.to_s)
        add_compose_raw_var("KAFKA_LOG_DIRS", "/var/lib/kafka/data")
        add_compose_raw_var("KAFKA_AUTO_CREATE_TOPICS_ENABLE", "false")
        compose_ports.add(Mobilis::Primitives::PortMap.new(HOST_PORT, HOST_PORT, "#{name} developer Kafka port")) if host
        set_healthcheck_command("/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >/dev/null 2>&1",
                                interval: "5s", timeout: "5s", retries: 30, start_period: "15s")
      end

      def service_writer
        Mobilis::ServiceWriter::Kafka
      end

      def service_wrapped_compose
        result = super
        broker = result[:services].fetch(name)
        (2..broker_count).each do |index|
          service_name = broker_name(index)
          additional = broker.dup
          additional[:environment] = broker[:environment].map do |setting|
            if setting.start_with?("KAFKA_NODE_ID=")
              "KAFKA_NODE_ID=#{index}"
            elsif setting.start_with?("KAFKA_ADVERTISED_LISTENERS=")
              "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://#{service_name}:9092#{",HOST://localhost:#{HOST_PORT + index - 1}" if config_node.publish_port}"
            else
              setting
            end
          end
          additional[:volumes] = ["#{service_name}-data:/var/lib/kafka/data"]
          additional[:labels] = broker[:labels].merge("mobilis.io/service" => service_name)
          additional[:ports] = ["#{HOST_PORT + index - 1}:#{HOST_PORT}"] if config_node.publish_port
          result[:services][service_name] = additional
        end
        result[:services]["#{name}-topics"] = {
          image: Mobilis::ContainerVersions::KAFKA,
          depends_on: broker_names.to_h { |broker_name| [broker_name, {condition: "service_healthy"}] },
          volumes: ["./#{name}/provision.sh:/opt/mobilis/provision.sh:ro"],
          entrypoint: ["/bin/bash", "/opt/mobilis/provision.sh"],
          restart: "no",
          labels: broker[:labels]
        }
        result[:volumes] = broker_names.to_h { |broker_name| ["#{broker_name}-data", {}] }
        result
      end
    end
  end
end
