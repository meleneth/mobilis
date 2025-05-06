class TestableHasEnvVars
  include Mobilis::Mixins::RealizedNode::HasEnvVars
end

RSpec.describe Mobilis::Mixins::RealizedNode::HasEnvVars do
  let(:subject) { TestableHasEnvVars.new }
  it "#add_env_only_var" do
    subject.add_env_only_var("SOME_VALUE", 5)
    env_vars = subject.env_vars_for_env_file.to_a.map(&:env_repr)
    expect(env_vars).to eq(["SOME_VALUE=5"])
  end
  it "#add_docker_aliased_var" do
    subject.add_docker_aliased_var("SOME_VALUE", "USER_SOME_VALUE", 5)
    env_vars = subject.env_vars_for_env_file.to_a.map(&:env_repr)
    expect(env_vars).to eq(["USER_SOME_VALUE=5"])
    env_vars = subject.env_vars_for_docker_environment.to_a.map(&:compose_repr)
    expect(env_vars).to eq(["SOME_VALUE=${USER_SOME_VALUE}"])
  end
  it "#add_docker_raw_var" do
    subject.add_docker_raw_var("RAILS_MAX_THREADS", 5)
    env_vars = subject.env_vars_for_docker_environment.to_a.map(&:compose_repr)
    expect(env_vars).to eq(["RAILS_MAX_THREADS=5"])
  end
end
