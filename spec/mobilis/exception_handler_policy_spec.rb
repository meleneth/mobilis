# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "exception handler policy" do
  PYTHON_HANDLER = /\bexcept\*?\s*(?:\([^)]*\b(?:BaseException|Exception)\b|(?:BaseException|Exception)\b|:)/.freeze
  RUBY_HANDLER = /\brescue\s+[^\n#]*\b(?:Exception|StandardError)\b|\brescue(?:\s*$|\s+=>|\s+(?![A-Z:]))|\bwhen\s+(?:::)?Exception\b/.freeze

  def violations(paths)
    paths.flat_map do |path|
      pattern = File.extname(path) == ".py" ? PYTHON_HANDLER : Regexp.union(PYTHON_HANDLER, RUBY_HANDLER)
      File.readlines(path).each_with_index.filter_map do |line, index|
        "#{path}:#{index + 1}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  it "has no base or bare exception handlers in source or generator templates" do
    root = File.expand_path("../..", __dir__)
    paths = %w[lib scripts].flat_map { |directory| Dir.glob(File.join(root, directory, "**", "*.{py,rb}")) }
    expect(violations(paths)).to be_empty
  end

  it "emits no base or bare exception handlers in connected Python services" do
    system = Mobilis::System.new("exception-audit")
    dsl = Mobilis::DSL::DSLContext.new(system)
    database = dsl.cassandra("history") { |node| node.keyspace("records") }
    broker = dsl.google_pubsub("events") do |node|
      node.topic("requests")
      node.subscription("worker", topic: "requests")
    end
    api = dsl.fastapi("api")
    dsl.connect(from: api, to: database)
    dsl.connect(from: api, to: broker, publish: "requests", subscribe: "worker")
    dsl.connect(from: api, to: dsl.otel_collector("telemetry"))
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:development))

    Dir.mktmpdir do |root|
      Dir.chdir(root) do
        events = env.realized_node_by_name("events")
        events.service_writer.new(nil, env, events).write
        FileUtils.mkdir_p("api")
        Dir.chdir("api") do
          realized_api = env.realized_node_by_name("api")
          realized_api.service_writer.new(nil, env, realized_api).write
        end
      end
      expect(violations(Dir.glob(File.join(root, "**", "*.py")))).to be_empty
    end
  end
end
