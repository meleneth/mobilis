# frozen_string_literal: true

module Mobilis
  module Node
    class GooglePubSub < Mobilis::Base::Node
      RESOURCE_ID = /\A[a-z][a-z0-9-]{2,254}\z/
      PROJECT_ID = /\A[a-z][a-z0-9-]{4,28}[a-z0-9]\z/
      attr_reader :project_id, :topics, :subscriptions, :publish_port

      def initialize(name, project_id: "mobilis-local", topics: [], subscriptions: [], publish_port: false, **kwargs)
        super(name, **kwargs)
        project(project_id)
        @topics = []
        Array(topics).each { |entry| topic(entry) }
        @subscriptions = []
        Array(subscriptions).each do |entry|
          subscription(entry.fetch(:name), topic: entry.fetch(:topic))
        end
        @publish_port = publish_port == true
      end

      def project(value)
        value = value.to_s
        raise ArgumentError, "Invalid local Pub/Sub project ID: #{value}" unless PROJECT_ID.match?(value)

        @project_id = value
        self
      end

      def topic(value)
        value = resource_id!(value, "topic")
        @topics << value unless @topics.include?(value)
        self
      end

      def subscription(name, topic:)
        name = resource_id!(name, "subscription")
        topic = resource_id!(topic, "topic")
        raise ArgumentError, "Pub/Sub subscription #{name} refers to undeclared topic #{topic}" unless topics.include?(topic)

        existing = subscriptions.find { |item| item[:name] == name }
        raise ArgumentError, "Pub/Sub subscription #{name} already uses #{existing[:topic]}" if existing && existing[:topic] != topic

        subscriptions << {name: name, topic: topic} unless existing
        self
      end

      def validate_connection!(publish:, subscribe:)
        publishes = Array(publish).map { |item| resource_id!(item, "topic") }
        consumes = Array(subscribe).map { |item| resource_id!(item, "subscription") }
        raise ArgumentError, "Pub/Sub connection must declare publish: or subscribe:" if publishes.empty? && consumes.empty?
        missing_topics = publishes - topics
        missing_subscriptions = consumes - subscriptions.map { |item| item[:name] }
        raise ArgumentError, "Undeclared Pub/Sub topics: #{missing_topics.join(', ')}" unless missing_topics.empty?
        raise ArgumentError, "Undeclared Pub/Sub subscriptions: #{missing_subscriptions.join(', ')}" unless missing_subscriptions.empty?

        [publishes.uniq, consumes.uniq]
      end

      def to_h
        super.merge(project_id: project_id, topics: topics, subscriptions: subscriptions, publish_port: publish_port)
      end

      private

      def resource_id!(value, kind)
        value = value.to_s
        raise ArgumentError, "Invalid Pub/Sub #{kind} ID: #{value}" unless RESOURCE_ID.match?(value)

        value
      end
    end
  end
end
