# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Airflow generation" do
  def graph(traced: false)
    system = Mobilis::System.new("airflow-spec")
    context = Mobilis::DSL::DSLContext.new(system)
    database = context.postgres("metadata")
    broker = context.redis("broker")
    airflow = context.airflow("orchestrator") do |service|
      service.local_package("sample-domain") do |package|
        package.write_file("src/sample_domain/__init__.py", "ANSWER = 42\n")
      end
      service.dag("sample", source: "from airflow.sdk import DAG\n")
    end
    context.connect(from: airflow, to: database)
    context.connect(from: airflow, to: broker)
    context.connect(from: airflow, to: context.otel_collector("telemetry")) if traced
    system
  end

  it "round trips the DSL, package, DAG and connections" do
    restored = Mobilis::System.from_json(graph.to_json)
    node = restored.each_config_node.find { |item| item.is_a?(Mobilis::Node::Airflow) }
    expect(node.models.grep(Mobilis::Model::LocalPythonPackage).first.files.first.content).to eq("ANSWER = 42\n")
    expect(node.extra_depends_on.map { |edge| edge[:target].name }).to contain_exactly("metadata", "broker")
  end

  [false, true].each do |traced|
    it "renders the complete component topology with telemetry #{traced}" do
      env = Mobilis::RealizedEnv.new(graph(traced: traced), Mobilis::ExecutionEnvironment.new(:development))
      node = env.realized_node_by_name("orchestrator")
      services = node.service_wrapped_compose[:services]
      expect(services["orchestrator"][:build]).to include(context: ".", dockerfile: "orchestrator/Dockerfile")
      expect(services.keys).to contain_exactly("orchestrator-init", "orchestrator", "orchestrator-scheduler",
                                               "orchestrator-dag-processor", "orchestrator-worker", "orchestrator-triggerer")
      expect(services["orchestrator-worker"][:depends_on]["orchestrator-init"][:condition]).to eq("service_completed_successfully")
      expect(services["orchestrator"][:depends_on].keys.map(&:to_s)).to include("metadata", "broker")
      environment = services["orchestrator-worker"][:environment].join("\n")
      expect(environment.include?("AIRFLOW__TRACES__OTEL_ON")).to eq(traced)
      expect(environment).to include("AIRFLOW__CELERY__BROKER_URL")
      expect(environment).to include("MOBILIS_PIPELINE_DATABASE_URL")
    end
  end

  it "writes installable source distributions, DAG source and a constrained image" do
    system = graph
    manifest = Mobilis::Manifest.new(system, suppress_plugins: true)
    env = manifest.realized_env(:development)
    node = env.realized_node_by_name("orchestrator")
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p("#{root}/orchestrator")
      Dir.chdir("#{root}/orchestrator") do
        Mobilis::ServiceWriter::Airflow.new(manifest, env, node).write
        expect(File.read("../packages/sample-domain/pyproject.toml")).to include('name = "sample-domain"')
        expect(File.read("../packages/sample-domain/src/sample_domain/__init__.py")).to eq("ANSWER = 42\n")
        expect(File.read("dags/sample.py")).to include("airflow.sdk")
        expect(File.read("Dockerfile")).to include("constraints-3.1.0/constraints-3.12.txt")
        expect(File.read("validate_dags.py")).to include("DagBag")
      end
    end
  end

  it "shares a package with a second Python runtime" do
    package = Mobilis::Model::LocalPythonPackage.new("shared-records")
    package.write_file("src/shared_records/__init__.py", "VALUE = 7\n")
    api = Mobilis::Node::FastAPI.new("reader")
    api.use_local_package(package)
    system = Mobilis::System.new("shared-python")
    system << api
    manifest = Mobilis::Manifest.new(system, suppress_plugins: true)
    env = manifest.realized_env(:development)
    node = env.realized_node_by_name("reader")
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p("#{root}/reader")
      Dir.chdir("#{root}/reader") do
        Mobilis::ServiceWriter::FastAPI.new(manifest, env, node).write
        expect(node.compose.clean_shrunk[:build]).to include(context: ".", dockerfile: "reader/Dockerfile")
        expect(File.read("Dockerfile")).to include("./packages/shared-records .")
        expect(File.read("../packages/shared-records/src/shared_records/__init__.py")).to eq("VALUE = 7\n")
      end
    end
  end

  it "declares three real DAGs and two nonempty packages in the numbered example" do
    system = nil
    allow(Mobilis::DSL).to receive(:generate) do |name, &block|
      system = Mobilis::System.new(name)
      Mobilis::DSL::DSLContext.new(system).instance_exec(&block)
    end
    load File.expand_path("../../scripts/23_airflow.rb", __dir__)
    node = system.each_config_node.find { |item| item.is_a?(Mobilis::Node::Airflow) }
    expect(node.models.grep(Mobilis::Model::LocalPythonPackage).map(&:name)).to contain_exactly("mobilis-domain", "mobilis-pipeline")
    dags = node.models.grep(Mobilis::Model::File)
    expect(dags.map(&:path)).to contain_exactly("dags/ingest.py", "dags/aggregate.py", "dags/report.py")
    expect(dags.map(&:content).join).to include("@dag", "@task", "persist_report", "persist_sales")
  end
end
