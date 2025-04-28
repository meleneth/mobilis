# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Base::RealizedNode do
  let(:node) { Mobilis::Base::Node.new("some_node") }
  let(:realized_node) { Mobilis::Base::RealizedNode.new(Mobilis::ExecutionEnvironment.new(:test), node) }

  describe "#env_var_realized" do
    it "returns DockerEnvVar for name" do
      realized_node.add_docker_env_var("SOME_VAR", "SOME_NODE_SOME_VAR", "some_value")
      expect(realized_node.env_var_resolved("SOME_VAR").specific_name).to eq("SOME_NODE_SOME_VAR")
    end
  end
end
