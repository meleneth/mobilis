# frozen_string_literal: true

require "json"
require "rdkafka"
require "opentelemetry"

module MobilisKafka
  module_function

  def producer
    Rdkafka::Config.new("bootstrap.servers" => ENV.fetch("KAFKA_BOOTSTRAP_SERVERS"),
                        "enable.idempotence" => true, "acks" => "all").producer
  end

  def publish(client, topic:, key:, event:, headers: {})
    allowed = ENV.fetch("MOBILIS_KAFKA_PUBLISH_TOPICS", "").split(",")
    raise ArgumentError, "Undeclared Kafka topic #{topic}" unless allowed.include?(topic)
    raise ArgumentError, "Kafka message key is required" if key.to_s.empty?

    OpenTelemetry.tracer_provider.tracer("mobilis.kafka").in_span("kafka publish", kind: :producer) do
      carrier = headers.transform_keys(&:to_s).transform_values(&:to_s)
      OpenTelemetry.propagation.inject(carrier)
      client.produce(topic: topic, key: key.to_s, payload: JSON.generate(event), headers: carrier).wait
    end
  end

  def consume(topic:, group:, stop:, &handler)
    allowed = ENV.fetch("MOBILIS_KAFKA_SUBSCRIPTIONS", "").split(",")
    raise ArgumentError, "Undeclared Kafka subscription #{topic}:#{group}" unless allowed.include?("#{topic}:#{group}")

    consumer = Rdkafka::Config.new("bootstrap.servers" => ENV.fetch("KAFKA_BOOTSTRAP_SERVERS"),
                                  "group.id" => group, "enable.auto.commit" => false,
                                  "enable.auto.offset.store" => false,
                                  "auto.offset.reset" => "earliest").consumer
    consumer.subscribe(topic)
    begin
      until stop.call
        message = consumer.poll(500)
        next unless message

        extracted = OpenTelemetry.propagation.extract(message.headers)
        linked_span = OpenTelemetry::Trace.current_span(extracted).context
        links = linked_span.valid? ? [OpenTelemetry::Trace::Link.new(linked_span)] : []
        OpenTelemetry.tracer_provider.tracer("mobilis.kafka").in_span("kafka process", kind: :consumer, links: links) do
          handler.call(JSON.parse(message.payload), message)
        end
        consumer.store_offset(message)
        consumer.commit
      end
    ensure
      consumer.close
    end
  end
end
