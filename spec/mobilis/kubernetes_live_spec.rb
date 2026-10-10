# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"
require "json"

RSpec.describe "Kubernetes demo on Devastation", if: ENV["MOBILIS_KUBERNETES_LIVE"] == "1" do
  it "serves Istio routes and delivers Rails traces, metrics, and logs while keeping infrastructure private" do
    verifier = File.expand_path("../../scripts/kubernetes/verify.rb", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, verifier)
    expect(status).to be_success, output
  end

  it "identifies generated application images using their declared ownership labels" do
    root = ENV.fetch("MOBILIS_ARTIFACT_ROOT", File.expand_path("../../generate", __dir__))
    environment = ENV.fetch("MOBILIS_ENV", "dev")
    builds = JSON.parse(File.read(File.join(root, "kubernetes", environment, "builds.json")))
    expect(builds).not_to be_empty
    builds.each do |build|
      output, status = Open3.capture2e("docker", "image", "inspect", build.fetch("image"), "--format", "{{json .Config.Labels}}")
      expect(status).to be_success, output
      expect(JSON.parse(output)).to include(build.fetch("build").fetch("labels"))
    end
  end
end

RSpec.describe "Kubernetes demo storage", if: ENV["MOBILIS_KUBERNETES_STORAGE_LIVE"] == "1" do
  it "preserves dev state and discards test state when their database pods are replaced" do
    verifier = File.expand_path("../../scripts/kubernetes/verify_storage.rb", __dir__)
    %w[dev test].each do |environment|
      output, status = Open3.capture2e({"MOBILIS_ENV" => environment}, RbConfig.ruby, verifier, "--replace-pod")
      expect(status).to be_success, output
    end
  end
end

RSpec.describe Mobilis::Plugin::RailsDBLibSupport do
  it "does not try to commit database Dockerfile changes for a database-free Rails app" do
    system = Mobilis::System.new("initial")
    system << Mobilis::Node::Rails.new("app")
    manifest = Mobilis::Manifest.new(system)
    plugin = described_class.new(manifest)
    expect(manifest).not_to receive(:commit_all)
    plugin.hook_after_services_written
  end
end
