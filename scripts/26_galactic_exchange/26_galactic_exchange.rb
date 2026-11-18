#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"
require "yaml"
require "json"
require "fileutils"

root = File.expand_path(ARGV.fetch(0, "."))
FileUtils.mkdir_p(root)
Dir.chdir(root)
system = Mobilis::System.new("galactic-exchange")
dsl = Mobilis::DSL::DSLContext.new(system)
broker = dsl.kafka("events", brokers: 3) do |node|
  node.topic("exchange.commands", partitions: 5, retention_ms: 604_800_000, cleanup_policy: "delete")
  node.topic("exchange.executions", partitions: 5, retention_ms: 604_800_000, cleanup_policy: "delete")
end
trading_db = dsl.postgres("trading-db")
portfolio_db = dsl.postgres("portfolio-db")
replay_db = dsl.postgres("portfolio-replay-db")
market_db = dsl.postgres("market-db")
leaderboard = dsl.redis("leaderboard")

trading = dsl.go_http("trading-api", port: 8080)
matching = dsl.fastapi("matching-engine", publish_port: false)
portfolio = dsl.rails("portfolio", primary_database: portfolio_db, api: true)
market = dsl.fastapi("market", port: 8000)

dsl.connect(from: trading, to: trading_db)
dsl.connect(from: trading, to: broker, publish: "exchange.commands")
dsl.connect(from: matching, to: broker, publish: "exchange.executions",
            subscribe: [{topic: "exchange.commands", group: "matching-v1"}])
dsl.connect(from: portfolio, to: broker, subscribe: [
  {topic: "exchange.executions", group: "portfolio-v1"},
  {topic: "exchange.executions", group: "portfolio-replay-v1"}
])
dsl.connect(from: market, to: market_db)
dsl.connect(from: market, to: leaderboard)
dsl.connect(from: market, to: broker, subscribe: [{topic: "exchange.executions", group: "market-v1"}])

collector = dsl.otel_collector("otel-collector")
traces = dsl.jaeger("jaeger")
metrics = dsl.prometheus("prometheus")
dashboard = dsl.grafana("grafana")
[trading, matching, portfolio, market].each { |service| dsl.connect(from: service, to: collector) }
dsl.connect(from: collector, to: traces)
dsl.connect(from: metrics, to: collector)
dsl.connect(from: dashboard, to: metrics)

trading.embedded_archive("trading-source", payload: Mobilis::EmbeddedArchive.pack(files: {
  "internal/app/routes.go" => File.binread(File.join(__dir__, "trading/routes.go"))
}))
trading.embedded_archive("verification", destination_prefix: "..", payload: Mobilis::EmbeddedArchive.pack(files: {
  "verify-galactic-exchange.py" => File.binread(File.join(__dir__, "verification/verify.py")),
  "GALACTIC-EXCHANGE.md" => File.binread(File.join(__dir__, "README.md"))
}))
matching.embedded_archive("matching-source", payload: Mobilis::EmbeddedArchive.pack(files: {
  "src/service_matching_engine/worker.py" => File.binread(File.join(__dir__, "matching/worker.py"))
}))
market.embedded_archive("market-source", payload: Mobilis::EmbeddedArchive.pack(files: {
  "src/service_market/worker.py" => File.binread(File.join(__dir__, "market/worker.py")),
  "src/service_market/routes.py" => File.binread(File.join(__dir__, "market/routes.py"))
}))
portfolio.embedded_archive("portfolio-source", payload: Mobilis::EmbeddedArchive.pack(files: {
  "db/migrate/20261018000000_create_projection.rb" => File.binread(File.join(__dir__, "portfolio/20261018000000_create_projection.rb")),
  "app/models/position.rb" => File.binread(File.join(__dir__, "portfolio/position.rb")),
  "app/models/processed_execution.rb" => File.binread(File.join(__dir__, "portfolio/processed_execution.rb")),
  "app/controllers/positions_controller.rb" => File.binread(File.join(__dir__, "portfolio/positions_controller.rb")),
  "config/routes.rb" => File.binread(File.join(__dir__, "portfolio/routes.rb")),
  "lib/portfolio_consumer.rb" => File.binread(File.join(__dir__, "portfolio/consumer.rb"))
}))

manifest = Mobilis::Manifest.new(system)
development = manifest.realized_env(:development)
market_url = development.realized_node_by_name("market-db").url
portfolio_url = development.realized_node_by_name("portfolio-db").url
replay_url = development.realized_node_by_name("portfolio-replay-db").url
collector_url = development.realized_node_by_name("otel-collector").internal_url
manifest.materialize

Dir.chdir(File.join(root, "generate")) do
  common = {
    "KAFKA_BOOTSTRAP_SERVERS" => "events:9092,events-2:9092,events-3:9092",
    "OTEL_EXPORTER_OTLP_ENDPOINT" => collector_url,
    "OTEL_EXPORTER_OTLP_PROTOCOL" => "http/protobuf",
    "OTEL_PROPAGATORS" => "tracecontext,baggage"
  }
  services = {
    "matching-worker" => {
      "image" => "galactic-exchange/matching-engine",
      "command" => ["python", "-m", "service_matching_engine.worker"],
      "environment" => common.merge("OTEL_SERVICE_NAME" => "matching-worker",
                                    "MOBILIS_KAFKA_PUBLISH_TOPICS" => "exchange.executions",
                                    "MOBILIS_KAFKA_SUBSCRIPTIONS" => "exchange.commands:matching-v1"),
      "depends_on" => {"events-topics" => {"condition" => "service_completed_successfully"}},
      "restart" => "unless-stopped"
    },
    "market-worker" => {
      "image" => "galactic-exchange/market",
      "command" => ["python", "-m", "service_market.worker"],
      "environment" => common.merge("OTEL_SERVICE_NAME" => "market-worker", "DATABASE_URL" => market_url,
                                    "LEADERBOARD_URL" => "redis://leaderboard:6379",
                                    "MOBILIS_KAFKA_PUBLISH_TOPICS" => "",
                                    "MOBILIS_KAFKA_SUBSCRIPTIONS" => "exchange.executions:market-v1"),
      "depends_on" => {"events-topics" => {"condition" => "service_completed_successfully"},
                       "market-db" => {"condition" => "service_healthy"},
                       "leaderboard" => {"condition" => "service_healthy"}},
      "restart" => "unless-stopped"
    },
    "portfolio-consumer" => {
      "image" => "galactic-exchange/portfolio",
      "command" => ["bash", "-lc", "bin/rails db:prepare && bin/rails runner lib/portfolio_consumer.rb"],
      "environment" => common.merge("OTEL_SERVICE_NAME" => "portfolio-consumer",
                                    "RAILS_ENV" => "development", "DATABASE_URL" => portfolio_url,
                                    "MOBILIS_KAFKA_SUBSCRIPTIONS" => "exchange.executions:portfolio-v1,exchange.executions:portfolio-replay-v1"),
      "depends_on" => {"events-topics" => {"condition" => "service_completed_successfully"},
                       "portfolio-db" => {"condition" => "service_healthy"}},
      "restart" => "unless-stopped"
    },
    "portfolio-replay-consumer" => {
      "image" => "galactic-exchange/portfolio",
      "command" => ["bash", "-lc", "bin/rails db:prepare && bin/rails runner lib/portfolio_consumer.rb"],
      "environment" => common.merge("OTEL_SERVICE_NAME" => "portfolio-replay-consumer",
                                    "RAILS_ENV" => "development", "DATABASE_URL" => replay_url,
                                    "PORTFOLIO_GROUP_ID" => "portfolio-replay-v1",
                                    "MOBILIS_KAFKA_SUBSCRIPTIONS" => "exchange.executions:portfolio-v1,exchange.executions:portfolio-replay-v1"),
      "depends_on" => {"events-topics" => {"condition" => "service_completed_successfully"},
                       "portfolio-replay-db" => {"condition" => "service_healthy"}},
      "profiles" => ["replay"]
    }
  }
  File.write("galactic-exchange.compose.yml", YAML.dump({"services" => services}))
  prometheus_config = YAML.load_file("prometheus/prometheus.yml")
  prometheus_config.fetch("scrape_configs") << {
    "job_name" => "galactic-exchange-workers",
    "static_configs" => [{"targets" => ["matching-worker:9000", "market-worker:9000"]}]
  }
  File.write("prometheus/prometheus.yml", YAML.dump(prometheus_config))
  panels = [
    ["Matching commands/s", "rate(exchange_commands_processed_total[5m])"],
    ["Market executions/s", "rate(exchange_market_events_processed_total[5m])"],
    ["Market processed offset", "exchange_market_last_offset"]
  ].each_with_index.map do |(title, expression), index|
    {id: index + 1, title: title, type: "timeseries", datasource: {type: "prometheus", uid: "prometheus_prometheus_ds"},
     targets: [{expr: expression, refId: "A"}], gridPos: {x: (index % 2) * 12, y: (index / 2) * 8, w: 12, h: 8}}
  end
  dashboard_json = {uid: "galactic-exchange", title: "Galactic Exchange", tags: ["mobilis", "kafka"],
                    schemaVersion: 39, version: 1, panels: panels, time: {from: "now-1h", to: "now"}}
  File.write("grafana/provisioning/dashboards/galactic-exchange.json", JSON.pretty_generate(dashboard_json))
end
