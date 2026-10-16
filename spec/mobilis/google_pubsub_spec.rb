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
end
