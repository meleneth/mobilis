# frozen_string_literal: true

require_relative "mobilis_kafka"

stop = false
Signal.trap("TERM") { stop = true }
Signal.trap("INT") { stop = true }

MobilisKafka.consume(topic: "exchange.executions", group: ENV.fetch("PORTFOLIO_GROUP_ID", "portfolio-v1"), stop: -> { stop }) do |event, message|
  ActiveRecord::Base.transaction do
    unless ProcessedExecution.exists?(execution_id: event.fetch("execution_id"))
      ProcessedExecution.create!(execution_id: event.fetch("execution_id"))
      quantity = Integer(event.fetch("quantity"))
      [[event.fetch("buyer"), quantity], [event.fetch("seller"), -quantity]].each do |account, delta|
        position = Position.find_or_initialize_by(account: account, commodity: event.fetch("commodity"))
        position.quantity += delta
        position.save!
      end
    end
  end
  puts({processed: event.fetch("execution_id"), partition: message.partition, offset: message.offset}.to_json)
end
