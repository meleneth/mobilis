# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Kubernetes demo on Devastation", if: ENV["MOBILIS_KUBERNETES_LIVE"] == "1" do
  it "serves Istio routes and delivers Rails traces, metrics, and logs while keeping infrastructure private" do
    verifier = File.expand_path("../../scripts/kubernetes/verify.rb", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, verifier)
    expect(status).to be_success, output
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
