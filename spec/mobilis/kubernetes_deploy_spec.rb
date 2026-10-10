# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"
require "rbconfig"

RSpec.describe "Generated Kubernetes deployment helper" do
  let(:labels) { {"app.kubernetes.io/managed-by" => "mobilis", "mobilis.io/project" => "initial", "mobilis.io/environment" => "dev"} }

  def run_helper(namespace: nil, routes: [], stale: [])
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p("#{directory}/kubernetes/dev")
      FileUtils.mkdir_p("#{directory}/bin")
      FileUtils.cp(File.expand_path("../../lib/mobilis/kubernetes/deploy.rb", __dir__), "#{directory}/deploy-kubernetes")
      File.write("#{directory}/kubernetes/dev/universe.json", JSON.dump(
        project: "initial", namespace: "initial-dev", public: {app: "initial.dev.deva.station"}
      ))
      File.write("#{directory}/kubernetes/dev/builds.json", JSON.dump([
        {service: "app", image: "registry.deva.station/initial/app:dev",
         build: {context: "./", dockerfile: "app/Dockerfile", args: {VALUE: "literal $(touch unwanted)"}, labels: {"mobilis.project" => "initial"}, target: "final"}}
      ]))
      File.write("#{directory}/kubernetes/dev/resources.yml", YAML.dump("kind" => "Deployment", "metadata" => {"name" => "app"}))
      File.write("#{directory}/fixtures.json", JSON.dump(namespace: namespace, routes: routes, stale: stale))
      stub = <<~RUBY
        #!#{RbConfig.ruby}
        require "json"
        File.open(ENV.fetch("COMMAND_LOG"), "a") { |file| file.puts JSON.dump([File.basename($PROGRAM_NAME), *ARGV]) }
        fixture = JSON.parse(File.read(ENV.fetch("FIXTURES")))
        if File.basename($PROGRAM_NAME) == "kubectl" && ARGV.include?("get")
          kind = ARGV[ARGV.index("get") + 1]
          if kind == "namespace"
            unless fixture["namespace"]
              warn "Error from server (NotFound): namespace not found"
              exit 1
            end
            puts JSON.dump(fixture["namespace"])
          elsif kind == "virtualservices.networking.istio.io"
            puts JSON.dump(items: fixture["routes"])
          elsif kind.include?(",")
            puts JSON.dump(items: fixture["stale"])
          else
            puts "{}"
          end
        end
      RUBY
      %w[kubectl docker].each do |command|
        path = "#{directory}/bin/#{command}"
        File.write(path, stub)
        FileUtils.chmod("+x", path)
      end
      output, error, status = Open3.capture3(
        {"PATH" => "#{directory}/bin:#{ENV.fetch("PATH")}", "COMMAND_LOG" => "#{directory}/commands.jsonl",
         "FIXTURES" => "#{directory}/fixtures.json", "MOBILIS_KUBE_CONTEXT" => "kind-devastation"},
        RbConfig.ruby, "#{directory}/deploy-kubernetes", "dev"
      )
      commands = File.readlines("#{directory}/commands.jsonl").map { |line| JSON.parse(line) }
      yield output, error, status, commands
    end
  end

  it "uses shared build options as literal argv, pushes to the registry, applies resources, and waits for rollout" do
    run_helper do |output, error, status, commands|
      expect(status).to be_success, error
      expect(commands).to include(["docker", "build", "-t", "registry.deva.station/initial/app:dev", "-f", "./app/Dockerfile",
        "--target", "final", "--build-arg", "VALUE=literal $(touch unwanted)", "--label", "mobilis.project=initial", "./"])
      expect(commands).to include(["docker", "push", "registry.deva.station/initial/app:dev"])
      expect(commands).to include(["kubectl", "--context", "kind-devastation", "apply", "-f", "kubernetes/dev/resources.yml"])
      expect(output).to include("app: http://initial.dev.deva.station")
    end
  end

  it "rejects a namespace owned by another project before builds or mutations" do
    run_helper(namespace: {metadata: {labels: labels.merge("mobilis.io/project" => "another")}}) do |_output, error, status, commands|
      expect(status).not_to be_success
      expect(error).to include("Namespace collision")
      expect(commands.all? { |command| command.first == "kubectl" && command.include?("get") }).to be(true)
    end
  end

  it "rejects colliding hostnames owned by another namespace before builds or mutations" do
    route = {metadata: {namespace: "another-dev", labels: labels}, spec: {hosts: ["initial.dev.deva.station"]}}
    run_helper(routes: [route]) do |_output, error, status, commands|
      expect(status).not_to be_success
      expect(error).to include("Hostname collision")
      expect(commands.all? { |command| command.first == "kubectl" && command.include?("get") }).to be(true)
    end
  end

  it "does not prune resources or manage workload restarts" do
    run_helper do |_output, error, status, commands|
      expect(status).to be_success, error
      expect(commands.none? { |command| command.include?("delete") || command.include?("restart") }).to be(true)
    end
  end
end
