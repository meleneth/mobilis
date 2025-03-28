module Mobilis
  module OutputFiles
    class KafkaService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "bitnami/kafka:latest",
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "environment" => [
            "KAFKA_CFG_NODE_ID=0",
            "KAFKA_CFG_PROCESS_ROLES=controller,broker",
            "KAFKA_CFG_LISTENERS=PLAINTEXT://:${#{project.env_name}_INTERNAL_PORT_NO},CONTROLLER://:9093",
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT",
            "KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@#{project.name}:9093",
            "KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER"
          ]
        }
      end
    end
  end
end
