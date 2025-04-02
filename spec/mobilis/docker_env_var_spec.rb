require "spec_helper"

RSpec.describe Mobilis::DockerEnvVar do
  let(:subject) do
    Mobilis::DockerEnvVar.new("DATABASE_URL", "USER_DATABASE_URL", "postgres:blah")
  end
  it "#docker_repr" do
    expect(subject.docker_repr).to eq("DATABASE_URL: ${USER_DATABASE_URL}")
  end
  it "#env_repr" do
    expect(subject.env_repr).to eq("USER_DATABASE_URL=postgres:blah")
  end
end
