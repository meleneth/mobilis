#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("airflow-demo") do
  database = postgres("pipeline-db")
  broker = redis("pipeline-broker")
  orchestrator = airflow("orchestrator") do |service|
    service.local_package("mobilis-domain") do |package|
      package.depends_on("opentelemetry-api>=1.25,<2")
    end
    service.local_package("mobilis-pipeline") do |package|
      package.depends_on("mobilis-domain==0.1.0")
      package.depends_on("psycopg2-binary>=2.9,<3")
      package.depends_on("opentelemetry-api>=1.25,<2")
    end
    service.embedded_archive("local-packages", destination_prefix: "../packages", payload: Mobilis::EmbeddedArchive.pack(files: {
      "mobilis-domain/src/mobilis_domain/__init__.py" => File.binread(File.join(__dir__, "domain.py")),
      "mobilis-domain/tests/test_domain.py" => File.binread(File.join(__dir__, "test_domain.py")),
      "mobilis-pipeline/src/mobilis_pipeline/__init__.py" => File.binread(File.join(__dir__, "pipeline.py")),
      "mobilis-pipeline/tests/test_pipeline.py" => File.binread(File.join(__dir__, "test_pipeline.py"))
    }))
    service.embedded_archive("dags", payload: Mobilis::EmbeddedArchive.pack(files: {
      "dags/ingest.py" => File.binread(File.join(__dir__, "ingest.py")),
      "dags/aggregate.py" => File.binread(File.join(__dir__, "aggregate.py")),
      "dags/report.py" => File.binread(File.join(__dir__, "report.py")),
      "demo/verify_traces.py" => File.binread(File.join(__dir__, "verify_traces.py"))
    }))
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
