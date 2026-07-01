# frozen_string_literal: true

module Mobilis
  module Node
    class GoAws < Mobilis::Base::Node
      DEFAULT_PORT = 4100

      attr_reader :port, :region, :account_id, :topics, :queues, :subscriptions

      def initialize(name, port: DEFAULT_PORT, region: "us-east-1", account_id: "100010001000",
                     topics: [], queues: [], subscriptions: [], **args)
        super(name, **args)
        @port = port
        @region = region
        @account_id = account_id
        @topics = topics.dup
        @queues = queues.dup
        @subscriptions = subscriptions.dup
      end

      # DSL-ish helpers
      def topic(name)
        @topics << name unless @topics.include?(name)
      end

      def queue(name)
        @queues << name unless @queues.include?(name)
      end

      def sns_sqs(topic_name, queue_names)
        topic(topic_name)
        Array(queue_names).each do |queue_name|
          queue(queue_name)
          subscribe(topic: topic_name, queue: queue_name)
        end
      end

      # subscribe topic -> queue
      # subscribe topic: "events", queue: "incoming"
      def subscribe(topic:, queue:)
        subscription = { topic: topic, queue: queue }
        @subscriptions << subscription unless @subscriptions.include?(subscription)
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

      def to_h
        super.merge(
          port: port,
          region: region,
          account_id: account_id,
          topics: topics,
          queues: queues,
          subscriptions: subscriptions
        )
      end
    end
  end
end
