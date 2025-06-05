class TestableHasCommand
  def meta_project_name
    "meta_testable_has_command"
  end

  def name
    "testable_has_command"
  end

  include Mobilis::Mixins::RealizedNode::HasHealthCheck
  include Mobilis::Mixins::RealizedNode::HasVolumes
  include Mobilis::Mixins::RealizedNode::HasEnvVars
  include Mobilis::Mixins::RealizedNode::HasPorts
  include Mobilis::Mixins::RealizedNode::HasCompose
  include Mobilis::Mixins::RealizedNode::HasCommand
end

RSpec.describe Mobilis::Mixins::RealizedNode::HasCommand do
  let(:subject) { TestableHasCommand.new }

  it "#set_command" do
    subject.set_command("ls -la")
    expect(subject.command_override[0]).to eq("ls -la")
  end
end
