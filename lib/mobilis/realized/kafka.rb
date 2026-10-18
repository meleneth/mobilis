# frozen_string_literal: true

module Mobilis
  module Realized
    class Kafka < Mobilis::Base::ImageForm
      INTERNAL_PORT = 9092
      HOST_PORT = 9094

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
        add_compose_raw_var("KAFKA_CONTROLLER_QUORUM_VOTERS", "1@#{name}:9093")
        add_compose_raw_var("KAFKA_CONTROLLER_LISTENER_NAMES", "CONTROLLER")
        add_compose_raw_var("KAFKA_LISTENER_SECURITY_PROTOCOL_MAP", "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,HOST:PLAINTEXT")
        host = node.publish_port
        add_compose_raw_var("KAFKA_LISTENERS", "PLAINTEXT://:9092,CONTROLLER://:9093#{',HOST://:9094' if host}")
        add_compose_raw_var("KAFKA_ADVERTISED_LISTENERS", "PLAINTEXT://#{name}:9092#{',HOST://localhost:9094' if host}")
        add_compose_raw_var("KAFKA_INTER_BROKER_LISTENER_NAME", "PLAINTEXT")
        add_compose_raw_var("KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", "1")
        add_compose_raw_var("KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", "1")
        add_compose_raw_var("KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", "1")
        add_compose_raw_var("KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", "0")
        add_compose_raw_var("KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR", "1")
        add_compose_raw_var("KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR", "1")
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
        result[:services]["#{name}-topics"] = {
          image: Mobilis::ContainerVersions::KAFKA,
          depends_on: {name => {condition: "service_healthy"}},
          volumes: ["./#{name}/provision.sh:/opt/mobilis/provision.sh:ro"],
          entrypoint: ["/bin/bash", "/opt/mobilis/provision.sh"],
          restart: "no",
          labels: broker[:labels]
        }
        result[:volumes] = {"#{name}-data" => {}}
        result
      end
    end
  end
end
