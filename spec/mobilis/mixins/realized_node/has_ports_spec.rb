class TestableHasPorts
  include Mobilis::Mixins::RealizedNode::HasEnvVars
  include Mobilis::Mixins::RealizedNode::HasPorts
end

RSpec.describe Mobilis::Mixins::RealizedNode::HasEnvVars do
  let(:subject) { TestableHasPorts.new }

  it "#register_external_port" do
    my_port = subject.register_external_port(2432, "SOME_COOL_PORT", "a very important port in our ecosystem")
    expect(my_port.to_compose).to eq("${SOME_COOL_PORT}:2432")
    env_vars = subject.envfile_vars.data[0].envfile_name
    expect(env_vars).to eq("SOME_COOL_PORT")
  end
end
