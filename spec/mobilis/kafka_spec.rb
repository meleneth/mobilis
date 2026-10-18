# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Kafka generation" do
  def topology
    system = Mobilis::System.new("exchange")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.kafka("events", publish_port: true) do |node|
      node.topic("exchange.commands", partitions: 5, retention_ms: 604_800_000)
      node.topic("exchange.executions", partitions: 5, retention_ms: 604_800_000)
    end
    api = dsl.go_http("trading")
    projection = dsl.fastapi("market")
    dsl.connect(from: api, to: broker, publish: "exchange.commands")
    dsl.connect(from: projection, to: broker, subscribe: [{topic: "exchange.executions", group: "market-v1"},
                                                        {topic: "exchange.executions", group: "market-replay"}])
    system
  end

  it "round trips topic and group declarations" do
    loaded = Mobilis::System.from_json(topology.to_json)
    broker = loaded.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::Kafka) }
    expect(broker.topics.map { |topic| topic[:partitions] }).to eq([5, 5])
    consumer = loaded.config_nodes.values.find { |node| node.name == "market" }
    expect(consumer.extra_depends_on.first[:kafka_subscribe].map { |item| item[:group] }).to eq(%w[market-v1 market-replay])
  end

  it "rejects invalid topics, undeclared connections and missing group IDs" do
    system = Mobilis::System.new("invalid")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.kafka("broker") { |node| node.topic("valid", partitions: 2, retention_ms: 1000) }
    client = dsl.go_http("client")
    expect { broker.topic("bad/name", partitions: 2, retention_ms: 1000) }.to raise_error(ArgumentError)
    expect { broker.topic("other", partitions: 0, retention_ms: 1000) }.to raise_error(ArgumentError)
    expect { dsl.kafka("even", brokers: 2) }.to raise_error(ArgumentError, /odd/)
    expect { broker.topic("over-replicated", partitions: 2, retention_ms: 1000, replication_factor: 2) }.to raise_error(ArgumentError, /replication/)
    expect { dsl.connect(from: client, to: broker, publish: "missing") }.to raise_error(ArgumentError, /Undeclared/)
    expect { dsl.connect(from: client, to: broker, subscribe: [{topic: "valid"}]) }.to raise_error(KeyError)
  end

  it "generates one three-broker KRaft cluster with replicated topics and host listeners" do
    system = Mobilis::System.new("cluster")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.kafka("events", brokers: 3, publish_port: true) do |node|
      node.topic("commands", partitions: 5, retention_ms: 1000)
    end
    producer = dsl.go_http("producer")
    dsl.connect(from: producer, to: broker, publish: "commands")
    loaded = Mobilis::System.from_json(system.to_json)
    expect(loaded.config_nodes.values.grep(Mobilis::Node::Kafka).first.brokers).to eq(3)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:development))
    realized = env.realized_node_by_name("events")
    compose = realized.service_wrapped_compose
    expect(compose[:services].keys).to include("events", "events-2", "events-3", "events-topics")
    expect(compose[:volumes].keys).to contain_exactly("events-data", "events-2-data", "events-3-data")
    quorum = "KAFKA_CONTROLLER_QUORUM_VOTERS=1@events:9093,2@events-2:9093,3@events-3:9093"
    (1..3).each do |index|
      service = compose[:services].fetch(index == 1 ? "events" : "events-#{index}")
      expect(service[:environment]).to include(quorum, "KAFKA_NODE_ID=#{index}",
                                               "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=3",
                                               "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=2")
      expect(service[:environment].join).to include("HOST://localhost:#{9093 + index}")
      expect(service[:ports].join).to include("#{9093 + index}:9094") if index > 1
    end
    expect(compose[:services]["events-topics"][:depends_on].keys).to contain_exactly("events", "events-2", "events-3")
    client = env.realized_node_by_name("producer")
    expect(client.compose.clean_shrunk[:environment]).to include("KAFKA_BOOTSTRAP_SERVERS=events:9092,events-2:9092,events-3:9092")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { realized.service_writer.new(nil, env, realized).write }
      expect(File.read("#{dir}/provision.sh")).to include("--replication-factor 3", "min.insync.replicas=2")
    end
  end

  it "rejects a declared service that collides with a generated broker name" do
    system = Mobilis::System.new("collision")
    dsl = Mobilis::DSL::DSLContext.new(system)
    dsl.kafka("events", brokers: 3) { |node| node.topic("commands", partitions: 3, retention_ms: 1000) }
    dsl.redis("events-2")
    expect { Mobilis::Manifest.new(system, suppress_plugins: true) }.to raise_error(ArgumentError, /events-2/)
  end

  it "rejects multi-broker Kubernetes output before materialization" do
    system = Mobilis::System.new("kubernetes-cluster")
    dsl = Mobilis::DSL::DSLContext.new(system)
    dsl.kafka("events", brokers: 3) { |node| node.topic("commands", partitions: 3, retention_ms: 1000) }
    dsl.deploy_kubernetes("*.example.test")
    expect { Mobilis::Manifest.new(system, suppress_plugins: true) }.to raise_error(ArgumentError, /Docker Compose/)
  end

  it "writes KRaft broker, deterministic topics and ready dependencies" do
    env = Mobilis::RealizedEnv.new(topology, Mobilis::ExecutionEnvironment.new(:development))
    broker = env.realized_node_by_name("events")
    api = env.realized_node_by_name("trading")
    projection = env.realized_node_by_name("market")
    config = broker.compose.clean_shrunk
    expect(config[:image]).to eq("apache/kafka:4.2.2")
    expect(config[:environment]).to include("KAFKA_PROCESS_ROLES=broker,controller", "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
                                            "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1",
                                            "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://events:9092,HOST://localhost:9094")
    expect(config[:volumes]).to include("events-data:/var/lib/kafka/data")
    expect(broker.service_wrapped_compose[:volumes]).to have_key("events-data")
    expect(broker.service_wrapped_compose[:services]).to have_key("events-topics")
    expect(api.compose.clean_shrunk[:depends_on][:'events-topics'][:condition]).to eq("service_completed_successfully")
    expect(projection.compose.clean_shrunk[:environment]).to include("MOBILIS_KAFKA_SUBSCRIPTIONS=exchange.executions:market-v1,exchange.executions:market-replay")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { broker.service_writer.new(nil, env, broker).write }
      script = File.read("#{dir}/provision.sh")
      expect(script).to include("--partitions 5", "retention.ms=604800000", "cleanup.policy=delete")
    end
  end

  it "generates Go and Python clients with manual commits and trace links" do
    env = Mobilis::RealizedEnv.new(topology, Mobilis::ExecutionEnvironment.new(:test))
    %w[trading market].each do |name|
      node = env.realized_node_by_name(name)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { node.service_writer.new(nil, env, node).write }
        source = if name == "trading"
                   expect(File.read("#{dir}/go.mod")).to include("github.com/twmb/franz-go v1.21.6")
                   File.read("#{dir}/internal/app/kafka.go")
                 else
                   expect(File.read("#{dir}/pyproject.toml")).to include("kafka-python==3.0.11")
                   expect(File.read("#{dir}/Dockerfile")).to include("vendor/kafka_python-3.0.11-py3-none-any.whl")
                   expect(File.read("#{dir}/Dockerfile")).to include("vendor/prometheus_client-0.26.0-py3-none-any.whl")
                   File.read("#{dir}/src/service_market/kafka_client.py")
                 end
        expect(source).to include("Kafka")
        expect(source).to include(name == "trading" ? "CommitRecords" : "consumer.commit({partition: OffsetAndMetadata")
        expect(source).to include(name == "trading" ? "trace.WithLinks" : "Link(parent_span)")
      end
    end
  end

  it "adds pinned Ruby client dependencies and preserves both independent groups" do
    system = Mobilis::System.new("ruby-kafka")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.kafka("events") { |node| node.topic("fills", partitions: 2, retention_ms: 86_400_000) }
    rack = dsl.rack("reporter")
    dsl.connect(from: rack, to: broker, subscribe: [{topic: "fills", group: "reporting"},
                                                      {topic: "fills", group: "audit"}])
    loaded = Mobilis::System.from_json(system.to_json)
    reporter = loaded.config_nodes.values.find { |node| node.name == "reporter" }
    expect(reporter.models.grep(Mobilis::Model::RubyGem).map(&:gemfile_line)).to include('gem "rdkafka", "= 0.29.0"')
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    realized = env.realized_node_by_name("reporter")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("reporter")
        Dir.chdir("reporter") { realized.service_writer.new(nil, env, realized).write }
      end
      expect(File.read("#{dir}/reporter/Gemfile")).to include('gem "rdkafka", "= 0.29.0"')
      expect(File.read("#{dir}/reporter/kafka_client.rb")).to include("consumer.store_offset(message)", "OpenTelemetry.propagation.extract")
    end
  end

  it "packages the Kafka client for legacy Flask projects" do
    system = Mobilis::System.new("flask-kafka")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.kafka("events") { |node| node.topic("requests", partitions: 2, retention_ms: 1000) }
    app = dsl.flask("client")
    dsl.connect(from: app, to: broker, publish: "requests")
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
    realized = env.realized_node_by_name("client")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { realized.service_writer.new(double(commit_all: nil), env, realized).write }
      expect(File.read("#{dir}/requirements.txt")).to include("kafka-python==3.0.11")
      expect(File.read("#{dir}/Dockerfile")).to include("RUN pip install --no-cache-dir /app/vendor/kafka_python")
      expect(File).to exist("#{dir}/vendor/kafka_python-3.0.11-py3-none-any.whl")
      expect(File).to exist("#{dir}/vendor/redis-7.2.0-py3-none-any.whl")
    end
  end

  it "packages Redis for FastAPI projections that do not use Kafka" do
    system = Mobilis::System.new("redis-projection")
    dsl = Mobilis::DSL::DSLContext.new(system)
    cache = dsl.redis("cache")
    app = dsl.fastapi("projection")
    dsl.connect(from: app, to: cache)
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
    realized = env.realized_node_by_name("projection")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { realized.service_writer.new(nil, env, realized).write }
      expect(File.read("#{dir}/Dockerfile")).to include("/app/vendor/redis-7.2.0-py3-none-any.whl")
      expect(File).to exist("#{dir}/vendor/redis-7.2.0-py3-none-any.whl")
    end
  end
end
