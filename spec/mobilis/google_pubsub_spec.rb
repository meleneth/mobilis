# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Google Pub/Sub emulator topology" do
  def system_with_roles
    system = Mobilis::System.new("pubsub-demo")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.google_pubsub("events", project: "mobilis-local", publish_port: true) do |node|
      node.topic("requests")
      node.subscription("worker-a", topic: "requests")
      node.subscription("worker-b", topic: "requests")
    end
    publisher = dsl.fastapi("publisher")
    subscriber = dsl.go_http("worker")
    dsl.connect(from: publisher, to: broker, publish: "requests")
    dsl.connect(from: subscriber, to: broker, subscribe: "worker-a")
    system
  end

  it "round trips declared resources and connection roles" do
    loaded = Mobilis::System.from_json(system_with_roles.to_json)
    broker = loaded.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::GooglePubSub) }
    expect(broker.project_id).to eq("mobilis-local")
    expect(broker.topics).to eq(["requests"])
    expect(broker.subscriptions).to eq([{name: "worker-a", topic: "requests"}, {name: "worker-b", topic: "requests"}])
    publisher = loaded.config_nodes.values.find { |node| node.name == "publisher" }
    expect(publisher.extra_depends_on.first).to include(pubsub_publish: ["requests"], pubsub_subscribe: [])
  end

  it "rejects undeclared resources and ambiguous authority" do
    system = Mobilis::System.new("pubsub")
    dsl = Mobilis::DSL::DSLContext.new(system)
    broker = dsl.google_pubsub("events") { |node| node.topic("requests") }
    consumer = dsl.fastapi("consumer")
    expect { broker.subscription("worker", topic: "missing") }.to raise_error(ArgumentError, /undeclared/)
    expect { dsl.connect(from: consumer, to: broker) }.to raise_error(ArgumentError, /publish:/)
    expect { dsl.connect(from: consumer, to: broker, subscribe: "missing") }.to raise_error(ArgumentError, /Undeclared/)
    expect { dsl.connect(from: consumer, to: broker, publish: "missing") }.to raise_error(ArgumentError, /Undeclared/)
    expect { dsl.connect(from: consumer, to: dsl.postgres("db"), publish: "requests") }.to raise_error(ArgumentError, /Google Pub\/Sub/)
  end

  it "generates official emulator Compose configuration and scoped consumer variables" do
    system = system_with_roles
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:development))
    broker = env.realized_node_by_name("events")
    publisher = env.realized_node_by_name("publisher")
    consumer = env.realized_node_by_name("worker")
    expect(broker.compose.clean_shrunk[:build]).to eq(context: "./events")
    expect(broker.compose.clean_shrunk[:healthcheck][:test].last).to include("health.py")
    expect(broker.compose.clean_shrunk[:ports].length).to eq(1)
    expect(broker.env_vars_for_env_file.map(&:env_repr).any? { |entry| entry.start_with?("EVENTS_PUBSUB_HOST_ENDPOINT=localhost:") }).to be(true)
    expect(publisher.compose.clean_shrunk[:environment]).to include("PUBSUB_EMULATOR_HOST=events:8085", "MOBILIS_PUBSUB_PUBLISH_TOPICS=requests", "MOBILIS_PUBSUB_SUBSCRIPTIONS=")
    expect(consumer.compose.clean_shrunk[:environment]).to include("MOBILIS_PUBSUB_PUBLISH_TOPICS=", "MOBILIS_PUBSUB_SUBSCRIPTIONS=worker-a")
    expect(consumer.compose.clean_shrunk[:depends_on][:events][:condition]).to eq("service_healthy")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { broker.service_writer.new(nil, env, broker).write }
      expect(File.read("#{dir}/Dockerfile")).to include(Mobilis::ContainerVersions::GOOGLE_CLOUD_EMULATORS)
      expect(JSON.parse(File.read("#{dir}/topology.json"))["subscriptions"].length).to eq(2)
      expect(File.read("#{dir}/bootstrap.py")).to include("except AlreadyExists", "existing.topic != topic_path")
      expect(system("python3", "-m", "py_compile", "#{dir}/bootstrap.py", "#{dir}/health.py")).to be(true)
    end
  end

  [false, true].each do |telemetry|
    it "generates Python client wiring with telemetry #{telemetry}" do
      system = Mobilis::System.new("pubsub-python")
      dsl = Mobilis::DSL::DSLContext.new(system)
      broker = dsl.google_pubsub("events") do |node|
        node.topic("requests")
        node.subscription("worker-a", topic: "requests")
      end
      api = dsl.fastapi("api")
      dsl.connect(from: api, to: broker, publish: "requests", subscribe: "worker-a")
      dsl.connect(from: api, to: dsl.otel_collector("traces")) if telemetry
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
      realized = env.realized_node_by_name("api")
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { realized.service_writer.new(nil, env, realized).write }
        source = File.read("#{dir}/src/service_api/pubsub_client.py")
        expect(source).to include("PublisherClient", "SubscriberClient", "modify_ack_deadline", "def ack", "def nack")
        expect(source.include?("TraceContextTextMapPropagator")).to eq(telemetry)
        expect(source.include?("links=links")).to eq(telemetry)
        expect(source).not_to include("messaging.message.payload", "record_exception=True")
        expect(File.read("#{dir}/pyproject.toml")).to include("google-cloud-pubsub")
        expect(system("python3", "-m", "compileall", "-q", "#{dir}/src")).to be(true)
      end
    end
  end

  [false, true].each do |telemetry|
    it "generates Go client wiring with telemetry #{telemetry}" do
      system = Mobilis::System.new("pubsub-go")
      dsl = Mobilis::DSL::DSLContext.new(system)
      broker = dsl.google_pubsub("events") do |node|
        node.topic("requests")
        node.subscription("worker-a", topic: "requests")
      end
      api = dsl.go_http("worker")
      dsl.connect(from: api, to: broker, publish: "requests", subscribe: "worker-a")
      dsl.connect(from: api, to: dsl.otel_collector("traces")) if telemetry
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
      realized = env.realized_node_by_name("worker")
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { realized.service_writer.new(nil, env, realized).write }
        source = File.read("#{dir}/internal/app/pubsub.go")
        expect(source).to include("cloud.google.com/go/pubsub/v2", "message *pubsub.Message", "Ack or Nack each message")
        expect(source.include?("trace.WithLinks")).to eq(telemetry)
        expect(File.read("#{dir}/go.mod")).to include("cloud.google.com/go/pubsub/v2 v2.7.0")
        if ENV["PUBSUB_GO_BUILD"] == "1"
          Dir.chdir(dir) do
            go_env = {"GOPATH" => "/tmp/mobilis-go-pubsub", "GOMODCACHE" => "/tmp/mobilis-go-pubsub/pkg/mod", "GOCACHE" => "/tmp/mobilis-go-pubsub/cache"}
            expect(system(go_env, "go", "mod", "tidy")).to be(true)
            expect(system(go_env, "go", "test", "./...")).to be(true)
          end
        end
      end
    end
  end
end

RSpec.describe "Pub/Sub numbered example" do
  it "declares one publisher, independent subscriptions, and competing consumers" do
    configured = nil
    manifest = instance_double(Mobilis::Manifest, materialize: nil)
    allow(Mobilis::Manifest).to receive(:new) do |system|
      configured = system
      manifest
    end
    load File.expand_path("../../scripts/23_google_pubsub.rb", __dir__)
    expect(manifest).to have_received(:materialize)
    broker = configured.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::GooglePubSub) }
    expect(broker.topics).to eq(["requests"])
    expect(broker.subscriptions.map { |item| item[:name] }).to eq(%w[alpha beta])
    expect(configured.config_nodes.values.map(&:name)).to eq(%w[events publisher alpha-one alpha-two beta-worker])
    publisher = configured.config_nodes.values.find { |node| node.name == "publisher" }
    verifier = publisher.models.find { |model| model.is_a?(Mobilis::Model::File) && model.path == "demo/verify.py" }
    expect(verifier.executable).to be(true)
    expect(verifier.content).to include("nack", "redelivery verified")
  end
end
