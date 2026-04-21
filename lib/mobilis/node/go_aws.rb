# frozen_string_literal: true

module Mobilis
  module Node
    class GoAws < Mobilis::Base::Node
      DEFAULT_PORT = 4100

      attr_reader :name, :port, :region, :topics, :queues, :subscriptions

      # DSL-ish helpers
      def topic(name) = @topics << name
      def queue(name) = @queues << name

      # subscribe topic -> queue
      # subscribe topic: "events", queue: "incoming"
      def subscribe(topic:, queue:)
        @subscriptions << { topic: topic, queue: queue }
      end

      def service_name
        # Keep it stable and docker-friendly
        "goaws-#{name}"
      end

      def endpoint_url
        "http://#{service_name}:#{port}"
      end

      def env_exports
        {
          "AWS_REGION" => region,
          "AWS_ACCESS_KEY_ID" => "dummy",
          "AWS_SECRET_ACCESS_KEY" => "dummy",
          "AWS_ENDPOINT" => endpoint_url
        }
      end
    end
  end
end
