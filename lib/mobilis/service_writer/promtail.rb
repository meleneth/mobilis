# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Promtail < Mobilis::Base::ServiceWriter
      def write
        File.write("promtail-config.yaml", ::YAML.dump(config))
      end

      def config
        {
          "server" => {
            "http_listen_port" => 9080,
            "grpc_listen_port" => 0
          },
          "positions" => {
            "filename" => "/tmp/promtail-positions.yaml"
          },
          "clients" => [
            {
              "url" => "http://#{loki_name}:3100/loki/api/v1/push"
            }
          ],
          "scrape_configs" => [
            {
              "job_name" => "docker",
              "docker_sd_configs" => [
                {
                  "host" => "unix:///var/run/docker.sock",
                  "refresh_interval" => "5s",
                  "filters" => [
                    {
                      "name" => "label",
                      "values" => generated_project_labels
                    }
                  ]
                }
              ],
              "relabel_configs" => [
                {
                  "source_labels" => ["__meta_docker_container_label_com_docker_compose_project"],
                  "regex" => generated_project_regex,
                  "action" => "keep"
                },
                {
                  "source_labels" => ["__meta_docker_container_label_com_docker_compose_project"],
                  "target_label" => "compose_project"
                },
                {
                  "source_labels" => ["__meta_docker_container_label_com_docker_compose_service"],
                  "target_label" => "service"
                },
                {
                  "source_labels" => ["__meta_docker_container_label_com_docker_compose_service"],
                  "target_label" => "service_name"
                },
                {
                  "source_labels" => ["__meta_docker_container_name"],
                  "regex" => "/(.*)",
                  "target_label" => "container"
                }
              ],
              "pipeline_stages" => [
                { "docker" => {} }
              ]
            }
          ]
        }
      end

      def generated_project_regex
        "#{Regexp.escape(realized_env.meta_project_name)}-(test|development|production)"
      end

      def generated_project_labels
        %w[test development production].map do |env|
          "com.docker.compose.project=#{realized_env.meta_project_name}-#{env}"
        end
      end

      def loki_name
        realized_node.loki&.name || "loki"
      end
    end
  end
end
