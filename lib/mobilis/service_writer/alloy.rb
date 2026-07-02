# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Alloy < Mobilis::Base::ServiceWriter
      def write
        File.write("config.alloy", config)
      end

      def config
        <<~ALLOY
          logging {
            level = "info"
          }

          discovery.docker "containers" {
            host             = "unix:///var/run/docker.sock"
            refresh_interval = "5s"
          }

          discovery.relabel "generated_containers" {
            targets = discovery.docker.containers.targets

            rule {
              source_labels = ["__meta_docker_container_label_com_docker_compose_project"]
              regex         = "#{generated_project_regex}"
              action        = "keep"
            }

            rule {
              source_labels = ["__meta_docker_container_label_com_docker_compose_project"]
              target_label  = "compose_project"
            }

            rule {
              source_labels = ["__meta_docker_container_label_com_docker_compose_service"]
              target_label  = "service"
            }

            rule {
              source_labels = ["__meta_docker_container_label_com_docker_compose_service"]
              target_label  = "service_name"
            }

            rule {
              source_labels = ["__meta_docker_container_name"]
              regex         = "/(.*)"
              target_label  = "container"
            }
          }

          loki.source.docker "containers" {
            host       = "unix:///var/run/docker.sock"
            targets    = discovery.relabel.generated_containers.output
            forward_to = [loki.write.default.receiver]
          }

          loki.write "default" {
            endpoint {
              url = "http://#{loki_name}:3100/loki/api/v1/push"
            }
          }
        ALLOY
      end

      def generated_project_regex
        escaped_name = Regexp.escape(realized_env.meta_project_name).gsub("\\-", "-")
        "#{escaped_name.gsub("\\", "\\\\")}-(test|development|production)"
      end

      def loki_name
        realized_node.loki&.name || "loki"
      end
    end
  end
end
