#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

source = ->(name) { File.read(File.join(__dir__, "airflow", name)) }

Mobilis::DSL.generate("airflow-demo") do
  database = postgres("pipeline-db")
  broker = redis("pipeline-broker")
  orchestrator = airflow("orchestrator") do |service|
    domain = service.local_package("mobilis-domain") do |package|
      package.depends_on("opentelemetry-api>=1.25,<2")
      package.write_file("src/mobilis_domain/__init__.py", source.call("domain.py"))
      package.write_file("tests/test_domain.py", source.call("test_domain.py"))
    end
    service.local_package("mobilis-pipeline") do |package|
      package.depends_on("mobilis-domain==0.1.0")
      package.depends_on("psycopg2-binary>=2.9,<3")
      package.depends_on("opentelemetry-api>=1.25,<2")
      package.write_file("src/mobilis_pipeline/__init__.py", source.call("pipeline.py"))
      package.write_file("tests/test_pipeline.py", source.call("test_pipeline.py"))
    end
    %w[ingest aggregate report].each { |dag| service.dag(dag, source: source.call("#{dag}.py")) }
  end
  connect(from: orchestrator, to: database)
  connect(from: orchestrator, to: broker)
  if ENV["AIRFLOW_DEMO_OTEL"] == "1"
    collector = otel_collector("telemetry")
    backend = jaeger("jaeger")
    connect(from: orchestrator, to: collector)
    connect(from: collector, to: backend)
  end
end
