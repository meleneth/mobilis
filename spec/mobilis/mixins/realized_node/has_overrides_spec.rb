# frozen_string_literal: true

require "spec_helper"

class TestableHasOverrides
  include Mobilis::Mixins::RealizedNode::HasDependsOn
  include Mobilis::Mixins::RealizedNode::HasEnvVars
  include Mobilis::Mixins::RealizedNode::HasPorts
  include Mobilis::Mixins::RealizedNode::HasVolumes
  include Mobilis::Mixins::RealizedNode::HasOverrides
end

RSpec.describe Mobilis::Mixins::RealizedNode::HasOverrides do
  let(:subject) { TestableHasOverrides.new }

  it "builds the standard compose override sections" do
    overrides = subject.compose_overrides

    expect(overrides[:environment]).to be(subject.compose_environment_override)
    expect(overrides[:ports]).to be(subject.compose_ports_override)
    expect(overrides[:depends_on]).to be(subject.compose_depends_on_overrides)
    expect(overrides[:volumes]).to be(subject.compose_volumes_overrides)
  end

  it "adds a single override to compose_overrides" do
    expect { subject.add_override(:profiles, ["debug"]) }.not_to raise_error

    expect(subject.compose_overrides.to_h[:profiles]).to eq(["debug"])
  end

  it "merges overrides into compose_overrides" do
    expect do
      subject.merge_overrides(labels: { "com.example.role" => "worker" })
    end.not_to raise_error

    expect(subject.compose_overrides.to_h[:labels]).to eq({ "com.example.role" => "worker" })
  end
end
