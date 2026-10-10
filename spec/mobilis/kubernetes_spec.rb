# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Kubernetes deployment" do
  def system_for(project = "initial", &block)
    system = Mobilis::System.new(project)
    Mobilis::DSL::DSLContext.new(system).instance_exec(&block)
    system
  end

  def demo_system(script = "21_kubernetes_initial.rb")
    configured = nil
    manifest = instance_double(Mobilis::Manifest, materialize: nil)
    allow(Mobilis::Manifest).to receive(:new) do |system|
      configured = system
      manifest
    end
    load File.expand_path("../../scripts/#{script}", __dir__)
    allow(Mobilis::Manifest).to receive(:new).and_call_original
    configured
  end

  def write_service_files(manifest, directory)
    env = manifest.realized_env(:test)
    env.realized_nodes.each do |node|
      next unless node.has_service_dir
      FileUtils.mkdir_p(File.join(directory, node.name))
      Dir.chdir(File.join(directory, node.name)) do
        node.service_writer.new(manifest, env, node).write unless node.is_a?(Mobilis::Realized::Rails)
        node.each_model_of_type(Mobilis::Model::File, &:write_file)
      end
    end
  end

  it "uses generate's project identity and parses Istio exposures independently of declaration order" do
    system = demo_system
    expect(system.meta_project_name).to eq("initial")
    expect(system.kubernetes_deployment.base_domain).to eq("deva.station")
    expect(system.kubernetes_deployment.exposures).to eq([
      {name: "app", root: true}, {name: "jaeger", root: false}, {name: "grafana", root: false}
    ])
    expect(system.node_count).to eq(7)
    expect(system.config_nodes.values.find { |node| node.name == "app" }.has_connected_depends_on_class?(Mobilis::Node::OtelCollector)).to be_truthy
  end

  it "derives dev/test/prod namespaces and project-first flat hosts" do
    manifest = Mobilis::Manifest.new(demo_system)
    expect(manifest.kubernetes_universes.map(&:environment)).to contain_exactly("dev", "test", "prod")
    manifest.kubernetes_universes.each do |universe|
      expect(universe.namespace).to eq("initial-#{universe.environment}")
      expect(universe.domain).to eq("initial.#{universe.environment}.deva.station")
      expect(universe.public_services).to eq(
        "app" => universe.domain,
        "jaeger" => "initial-jaeger.#{universe.environment}.deva.station",
        "grafana" => "initial-grafana.#{universe.environment}.deva.station"
      )
    end
  end

  it "allows deployment without exposures and never infers public services from published Compose ports" do
    system = system_for do
      deploy_kubernetes "*.deva.station"
      grafana "dashboard"
    end
    manifest = Mobilis::Manifest.new(system)
    Dir.mktmpdir do |directory|
      write_service_files(manifest, directory)
      generator = Mobilis::Kubernetes::Generator.new(manifest, directory)
      universe = manifest.kubernetes_universes.first
      resources = generator.resources_for(universe)
      expect(universe.public_services).to be_empty
      expect(resources.map { |resource| resource["kind"] }).not_to include("Gateway", "VirtualService")
      expect(resources.find { |resource| resource["kind"] == "Service" }.dig("spec", "type")).to eq("ClusterIP")
    end
  end

  it "serializes Kubernetes intent alongside the existing graph" do
    system = demo_system
    loaded = Mobilis::System.from_json(system.to_json)
    expect(loaded.kubernetes_deployment.to_h).to eq(system.kubernetes_deployment.to_h)
    expect(Mobilis::Manifest.new(loaded).kubernetes_universes.map(&:public_services)).to eq(Mobilis::Manifest.new(system).kubernetes_universes.map(&:public_services))
    ordinary = system_for { rails "app" }
    expect(ordinary.to_h).not_to have_key(:deploy_kubernetes)
    expect(Mobilis::Manifest.new(ordinary).kubernetes_universes).to be_empty
  end

  it "rejects invalid wildcard domains" do
    [nil, "deva.station", "*deva.station", "*.localhost", "*.Deva.station", "*.deva..station", "*.bad_.station", "*.deva.station.", "*.#{"a" * 64}.station"].each do |domain|
      expect { system_for { deploy_kubernetes domain } }.to raise_error(ArgumentError, /domain/)
    end
  end

  it "rejects invalid project and derived names without rewriting them" do
    ["Initial", "initial_demo", "-initial", "initial-", "initial.other", "", "x" * 60].each do |project|
      expect { Mobilis::Manifest.new(system_for(project) { deploy_kubernetes "*.deva.station" }) }.to raise_error(ArgumentError, /name/)
    end
    system = system_for("x" * 50) do
      deploy_kubernetes "*.deva.station" do
        istio { expose "long-service-name" }
      end
      grafana "long-service-name"
    end
    expect { Mobilis::Manifest.new(system) }.to raise_error(ArgumentError, /hostname/)
  end

  it "rejects duplicate declarations, exposures, and multiple root services" do
    expect do
      system_for do
        deploy_kubernetes "*.deva.station"
        deploy_kubernetes "*.deva.station"
      end
    end.to raise_error(ArgumentError, /one deploy_kubernetes/)
    expect do
      system_for do
        deploy_kubernetes "*.deva.station" do
          istio do
            expose "app", root: true
            expose "jaeger", root: true
          end
        end
      end
    end.to raise_error(ArgumentError, /one exposed/)
    expect do
      system_for {
        deploy_kubernetes("*.deva.station") {
          istio {
            expose "app"
            expose "app"
          }
        }
      }
    end.to raise_error(ArgumentError, /Duplicate exposure/)
    expect do
      system_for {
        deploy_kubernetes("*.deva.station") {
          istio {}
          istio {}
        }
      }
    end.to raise_error(ArgumentError, /one istio/)
  end

  it "resolves normalized service names and rejects unknown and non-HTTP exposures" do
    system = system_for do
      deploy_kubernetes("*.deva.station") { istio { expose "my_app", root: true } }
      rails "my_app"
    end
    expect(Mobilis::Manifest.new(system).kubernetes_universes.first.public_services.keys).to eq(["my-app"])
    unknown = system_for { deploy_kubernetes("*.deva.station") { istio { expose "missing" } } }
    expect { Mobilis::Manifest.new(unknown) }.to raise_error(ArgumentError, /Unknown exposed service/)
    invalid = system_for do
      deploy_kubernetes("*.deva.station") { istio { expose "db" } }
      postgres "db"
    end
    expect { Mobilis::Manifest.new(invalid) }.to raise_error(ArgumentError, /Invalid exposed resource type/)
  end

  it "detects namespace and flattened hostname collisions across deployment universes" do
    first = Mobilis::Manifest.new(system_for("initial") { deploy_kubernetes "*.deva.station" }).kubernetes_universes
    expect { Mobilis::Kubernetes::Universe.validate_collisions!(first + first) }.to raise_error(ArgumentError, /namespace collision/)
    first = Mobilis::Manifest.new(system_for("initial") do
      deploy_kubernetes("*.deva.station") { istio { expose "jaeger" } }
      jaeger "jaeger"
    end).kubernetes_universes
    second = Mobilis::Manifest.new(system_for("initial-jaeger") do
      deploy_kubernetes("*.deva.station") { istio { expose "app", root: true } }
      rails "app"
    end).kubernetes_universes
    expect { Mobilis::Kubernetes::Universe.validate_collisions!(first + second) }.to raise_error(ArgumentError, /hostname collision/)
    other = Mobilis::Manifest.new(system_for("other") { deploy_kubernetes "*.deva.station" }).kubernetes_universes
    expect { Mobilis::Kubernetes::Universe.validate_collisions!(first + other) }.not_to raise_error
  end

  it "generates all demo workloads, internal discovery, configuration, and only explicit Istio routes deterministically" do
    system = demo_system
    manifest = Mobilis::Manifest.new(system)
    Dir.mktmpdir do |directory|
      write_service_files(manifest, directory)
      generator = Mobilis::Kubernetes::Generator.new(manifest, directory)
      universe = manifest.kubernetes_universes.find { |env| env.environment == "dev" }
      resources = generator.resources_for(universe)
      workloads = resources.select { |resource| resource["kind"] == "Deployment" }
      expect(workloads.map { |resource| resource.dig("metadata", "name") }).to contain_exactly("app", "grafana", "jaeger", "loki", "otel-collector", "prometheus", "alloy")
      services = resources.select { |resource| resource["kind"] == "Service" }
      expect(services.size).to eq(7)
      expect(services.map { |resource| resource.dig("spec", "type") }.uniq).to eq(["ClusterIP"])
      routes = resources.select { |resource| resource["kind"] == "VirtualService" }
      expect(routes.map { |resource| resource.dig("metadata", "name") }).to contain_exactly("app", "jaeger", "grafana")
      expect(routes.find { |route| route.dig("metadata", "name") == "app" }.dig("spec", "http", 0, "route", 0, "destination")).to eq("host" => "app.initial-dev.svc.cluster.local", "port" => {"number" => 80})
      collector = services.find { |service| service.dig("metadata", "name") == "otel-collector" }
      expect(collector.dig("spec", "ports").map { |port| port["port"] }).to contain_exactly(4317, 4318, 9464)
      jaeger = services.find { |service| service.dig("metadata", "name") == "jaeger" }
      expect(jaeger.dig("spec", "ports").map { |port| port["port"] }).to contain_exactly(16686, 4317)
      app = workloads.find { |workload| workload.dig("metadata", "name") == "app" }
      container = app.dig("spec", "template", "spec", "containers", 0)
      expect(container).not_to have_key("command")
      expect(container.fetch("ports")).to include({"name" => "http-80", "containerPort" => 8080})
      app_service = services.find { |service| service.dig("metadata", "name") == "app" }
      expect(app_service.dig("spec", "ports")).to eq([{"name" => "http-80", "port" => 80, "targetPort" => 8080}])
      env = app.dig("spec", "template", "spec", "containers", 0, "env")
      expect(env).to include({"name" => "OTEL_EXPORTER_OTLP_ENDPOINT", "value" => "http://otel-collector:4318"}, {"name" => "RAILS_ENV", "value" => "development"}, {"name" => "THRUSTER_HTTP_PORT", "value" => "8080"})
      configs = resources.select { |resource| resource["kind"] == "ConfigMap" }.to_h { |resource| [resource.dig("metadata", "name"), resource.fetch("data").values.join] }
      expect(configs["otel-collector"]).to include("jaeger:4317", "0.0.0.0:9464")
      expect(configs["grafana"]).to include("http://loki:3100", "http://prometheus:9090", "http://jaeger:16686")
      expect(configs["prometheus"]).to include("app:80", "otel-collector:9464")
      expect(configs["alloy"]).to include('loki.source.kubernetes "pods"', 'names = ["initial-dev"]', "http://loki:3100")
      expect(configs["alloy"]).not_to include("docker.sock", "discovery.docker")
      role = resources.find { |resource| resource["kind"] == "Role" }
      expect(role["rules"]).to eq([{"apiGroups" => [""], "resources" => ["pods", "pods/log"], "verbs" => ["get", "list", "watch"]}])
      expect(resources.map { |resource| resource.dig("metadata", "labels", "mobilis.io/project") }.uniq).to eq(["initial"])
      expect(resources.map { |resource| resource["kind"] }).not_to include("Secret", "Ingress", "ClusterRole")
      compose_before = universe.services.map { |node| node.compose.clean_shrunk }
      generator.write
      bytes = File.binread("#{directory}/kubernetes/dev/resources.yml")
      generator.write
      expect(File.binread("#{directory}/kubernetes/dev/resources.yml")).to eq(bytes)
      expect(generator.resources_for(universe)).to eq(resources)
      loaded_manifest = Mobilis::Manifest.new(Mobilis::System.from_json(system.to_json))
      loaded_universe = loaded_manifest.kubernetes_universes.find { |env| env.environment == "dev" }
      expect(Mobilis::Kubernetes::Generator.new(loaded_manifest, directory).resources_for(loaded_universe)).to eq(resources)
      expect(universe.services.map { |node| node.compose.clean_shrunk }).to eq(compose_before)
      expect(File.executable?("#{directory}/deploy-kubernetes")).to be(true)
      expect(generator.builds_for(universe)).to eq([{service: "app", image: "registry.deva.station/initial/app:dev", build: {context: "./app"}}])
      other = Mobilis::Manifest.new(system_for("another") {
        deploy_kubernetes "*.deva.station"
        rails "app"
      })
      expect(Mobilis::Kubernetes::Generator.new(other, directory).image_for(other.kubernetes_universes.first, other.realized_env(:test).realized_node_by_name("app"))).to eq("registry.deva.station/another/app:test")
    end
  end

  it "retains build options from the shared realized build model" do
    manifest = Mobilis::Manifest.new(system_for {
      deploy_kubernetes "*.deva.station"
      rails "app"
    })
    node = manifest.realized_env(:test).realized_node_by_name("app")
    node.set_compose_build_context("./")
    node.compose[:build][:dockerfile] = "./app/Dockerfile"
    node.compose[:build][:args][:MODE] = "demo"
    node.compose[:build][:target] = "final"
    generator = Mobilis::Kubernetes::Generator.new(manifest, "/tmp")
    expect(generator.builds_for(manifest.kubernetes_universes.first).first[:build]).to eq(context: "./", dockerfile: "./app/Dockerfile", args: {MODE: "demo"}, target: "final")
  end

  it "keeps the existing Rails OTEL demo Compose-only with its original graph" do
    system = demo_system("05_rails_otel_system.rb")
    expect(system.meta_project_name).to eq("generate")
    expect(system.kubernetes_deployment).to be_nil
    expect(system.config_nodes.values.map(&:name)).to contain_exactly(
      "user-service", "user-db", "otel-collector", "grafana", "jaeger", "loki", "prometheus", "alloy"
    )
    expect(Mobilis::Manifest.new(system).kubernetes_universes).to be_empty
  end
end
