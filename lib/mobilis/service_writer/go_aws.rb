# frozen_string_literal: true

require "yaml"
require "fileutils"

module Mobilis
  module ServiceWriter
    class GoAws < Mobilis::Base::ServiceWriter
      def write
        FileUtils.mkdir_p(service_dir)

        File.write(
          "#{service_dir}/goaws.yaml",
          ::YAML.dump(
            Mobilis::YAML.deep_stringify_keys(goaws_yaml.to_serial)
          )
        )
      end

      private

      def service_dir
        "./#{realized_node.name}"
      end

      def goaws_yaml
        data = Mobilis::AutoVivify.new

        data["Local"]["Host"] = realized_node.name
        data["Local"]["Port"] = realized_node.exposed_port_no
        data["Local"]["Region"] = region
        data["Local"]["AccountId"] = account_id
        data["Local"]["LogToFile"] = log_to_file
        data["Local"]["EnableDuplicates"] = enable_duplicates

        # Keep these defaults from your sample (fine to hardcode for now)
        data["Local"]["QueueAttributeDefaults"]["VisibilityTimeout"] = 30
        data["Local"]["QueueAttributeDefaults"]["ReceiveMessageWaitTimeSeconds"] = 0
        data["Local"]["QueueAttributeDefaults"]["MaximumMessageSize"] = 262_144

        queues.each do |qname|
          data["Local"]["Queues"] << { "Name" => qname }
        end

        topics.each do |t|
          topic = Mobilis::AutoVivify.new
          topic["Name"] = t.fetch("Name")

          Array(t["Subscriptions"]).each do |sub|
            topic["Subscriptions"] << {
              "QueueName" => sub.fetch("QueueName"),
              "Raw" => sub.fetch("Raw", false),
            }
          end

          data["Local"]["Topics"] << topic
        end

        data
      end

      # ---- pull from config_node, safely ----
      #
      # I don’t know your config_node’s concrete type; this supports:
      # - hash-ish nodes (cfg["Queues"])
      # - method-ish nodes (cfg.queues)
      #
      def cfg
        realized_node.config_node
      end

      def cfg_get(key, default = nil)
        return default if cfg.nil?

        if cfg.respond_to?(:[])
          v = cfg[key] rescue nil
          return v unless v.nil?
        end

        meth = key.to_s
          .gsub(/([a-z])([A-Z])/, '\1_\2')
          .downcase

        return cfg.public_send(meth) if cfg.respond_to?(meth)

        default
      end

      def region
        cfg_get("Region", "us-east-1")
      end

      def account_id
        cfg_get("AccountId", "100010001000")
      end

      def log_to_file
        cfg_get("LogToFile", false)
      end

      def enable_duplicates
        cfg_get("EnableDuplicates", false)
      end

      # Accept either:
      # Queues:
      #   - Name: foo
      #   - Name: bar
      # or
      # Queues: ["foo","bar"]
      def queues
        raw = cfg_get("Queues", [])
        Array(raw).map { |e| e.is_a?(Hash) ? e.fetch("Name") : e.to_s }
      end

      # Accept either the full structure, or a simplified internal structure.
      def topics
        raw = cfg_get("Topics", [])
        Array(raw).map do |e|
          next normalize_topic_hash(e) if e.is_a?(Hash)
          { "Name" => e.to_s, "Subscriptions" => [] }
        end
      end

      def normalize_topic_hash(h)
        {
          "Name" => h.fetch("Name"),
          "Subscriptions" => Array(h["Subscriptions"]).map do |s|
            if s.is_a?(Hash)
              { "QueueName" => s.fetch("QueueName"), "Raw" => s.fetch("Raw", false) }
            else
              { "QueueName" => s.to_s, "Raw" => false }
            end
          end
        }
      end
    end
  end
end
