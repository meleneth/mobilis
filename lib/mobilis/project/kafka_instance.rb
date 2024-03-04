# frozen_string_literal: true

module Mobilis
  class KafkaInstance < GenericProject
    def generate(git)
    end

    def child_env_vars
      []
    end

    def global_env_vars(environment)
      {
        "#{env_name}_EXTERNAL_PORT_NO": 9999,
        "#{env_name}_INTERNAL_PORT_NO": 9092
      }
    end

    def env_vars
      [
        "KAFKA_CFG_NODE_ID=0",
        "KAFKA_CFG_PROCESS_ROLES=controller,broker",
        "KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093",
        "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT",
        "KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=0@#{name}:9093",
        "KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER"
      ]
    end

    def env_name
      name.upcase
    end

    def has_local_build
      false
    end

    def is_datastore_project?
      true
    end
  end
end
