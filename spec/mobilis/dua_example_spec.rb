# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Department of Unnecessary Approvals example" do
  [false, true].each do |telemetry|
    it "declares the same domain graph with optional collector connections (#{telemetry})" do
      configured = nil
      manifest = instance_double(Mobilis::Manifest, materialize: nil)
      allow(Mobilis::Manifest).to receive(:new) do |system|
        configured = system
        manifest
      end
      original = ENV["DUA_OTEL"]
      ENV["DUA_OTEL"] = telemetry ? "1" : nil
      begin
        load File.expand_path("../../scripts/25_department_of_unnecessary_approvals.rb", __dir__)
      ensure
        ENV["DUA_OTEL"] = original
      end
      expect(manifest).to have_received(:materialize)
      nodes = configured.config_nodes.values.to_h { |node| [node.name, node] }
      expect(nodes["approval-events"].topics).to eq(["applications"])
      expect(nodes["approval-events"].subscriptions).to eq([{name: "bureaucrat", topic: "applications"}])
      expect(nodes["decisions-db"].keyspace_name).to eq("approvals")
      expect(nodes["applications"].graphql_subgraph_name).to eq("applications")
      expect(nodes["decisions"].graphql_subgraph_name).to eq("decisions")
      expect(nodes["gateway"].extra_depends_on.map { |edge| edge[:target].name }.first(2)).to eq(%w[applications decisions])
      expect(nodes.key?("telemetry")).to eq(telemetry)

      env = Mobilis::RealizedEnv.new(configured, Mobilis::ExecutionEnvironment.new(:development))
      application = env.realized_node_by_name("applications")
      worker = env.realized_node_by_name("bureaucrat")
      expect(application.pubsub.name).to eq("approval-events")
      expect(worker.cassandra.name).to eq("decisions-db")
      expect(worker.otel_enabled?).to eq(telemetry)
      expect(nodes["bureaucrat"].models.find { |model| model.path == "internal/app/decision_recording.go" }.content.include?("go.opentelemetry.io/otel")).to eq(telemetry)
    end
  end
end
