# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Loki < Mobilis::Base::ServiceWriter
      def write
        File.write("loki-config.yaml", ::YAML.dump(config))
      end

      def config
        {
          "auth_enabled" => false,
          "server" => {
            "http_listen_port" => 3100,
            "grpc_listen_port" => 9096
          },
          "limits_config" => {
            "ingestion_rate_mb" => 64,
            "ingestion_burst_size_mb" => 128,
            "reject_old_samples" => false,
            "reject_old_samples_max_age" => "87600h"
          },
          "ingester" => {
            "lifecycler" => {
              "min_ready_duration" => "0s"
            }
          },
          "common" => {
            "instance_addr" => "127.0.0.1",
            "path_prefix" => "/loki",
            "storage" => {
              "filesystem" => {
                "chunks_directory" => "/loki/chunks",
                "rules_directory" => "/loki/rules"
              }
            },
            "replication_factor" => 1,
            "ring" => {
              "kvstore" => {
                "store" => "inmemory"
              }
            }
          },
          "query_range" => {
            "results_cache" => {
              "cache" => {
                "embedded_cache" => {
                  "enabled" => true,
                  "max_size_mb" => 100
                }
              }
            }
          },
          "schema_config" => {
            "configs" => [
              {
                "from" => "2024-01-01",
                "store" => "tsdb",
                "object_store" => "filesystem",
                "schema" => "v13",
                "index" => {
                  "prefix" => "index_",
                  "period" => "24h"
                }
              }
            ]
          },
          "analytics" => {
            "reporting_enabled" => false
          }
        }
      end
    end
  end
end
