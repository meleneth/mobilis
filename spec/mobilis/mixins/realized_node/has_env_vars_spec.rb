class TestableHasEnvVars
  include Mobilis::Mixins::RealizedNode::HasEnvVars
end

RSpec.describe Mobilis::Mixins::RealizedNode::HasEnvVars do
  let(:subject) { TestableHasEnvVars.new }
  it "#add_env_only_var" do
    subject.add_env_only_var("SOME_VALUE", 5)
    env_vars = subject.envfile_vars.data.map(&:env_repr)
    expect(env_vars).to eq(["SOME_VALUE=5"])
  end
  it "#add_docker_aliased_var" do
    subject.add_compose_aliased_var("SOME_VALUE", "USER_SOME_VALUE", 5)
    env_vars = subject.envfile_vars.envfile_vars.map(&:env_repr)
    expect(env_vars).to eq(["USER_SOME_VALUE=5"])
    env_vars = subject.compose_environment.as_json
    expect(env_vars).to eq(["SOME_VALUE=${USER_SOME_VALUE}"])
  end
  it "#add_docker_raw_var" do
    subject.add_compose_raw_var("RAILS_MAX_THREADS", 5)
    env_vars = subject.compose_environment.as_json
    expect(env_vars).to eq(["RAILS_MAX_THREADS=5"])
  end
  it "all 3 but only two come out in all_envfile_vars" do
    subject.add_compose_raw_var("RAILS_MAX_THREADS", 5)
    subject.add_compose_aliased_var("SOME_VALUE", "USER_SOME_VALUE", 3)
    subject.add_env_only_var("SOME_VALUE", 4)
    seen = {}
    subject.env_vars_for_env_file { |emit_var| seen[emit_var.envfile_name] = emit_var.value }
    expect(seen).to eq({ "SOME_VALUE" => 4, "USER_SOME_VALUE" => 3 })
  end
end
