module Mobilis
  module OutputFiles
    class KafkaService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "bitnami/kafka:latest",
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "environment" => [
            "KAFKA_CFG_NODE_ID=0",
            "KAFKA_CFG_PROCESS_ROLES=controller,broker",
            "KAFKA_CFG_LISTENERS=PLAINTEXT://:${#{service.env_name}_INTERNAL_PORT_NO},CONTROLLER://:9093",
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT",
            "KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@#{service.name}:9093",
            "KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER"
          ]
        }
      end
    end
  end
end
