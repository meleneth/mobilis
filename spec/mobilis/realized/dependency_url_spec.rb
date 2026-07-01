# frozen_string_literal: true

require "spec_helper"

RSpec.describe "realized dependency URL exports" do
  let(:provider) { Mobilis::Node::Rails.new("service-y") }
  let(:consumer_node) { Mobilis::Node::Rails.new("service-x") }
  let(:system) do
    Mobilis::System.new("generate").tap do |sys|
      consumer_node.has_extra_depends_on(provider)
      sys << provider
      sys << consumer_node
    end
  end

  let(:realized_env) { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test)) }
  let(:consumer) { realized_env.realized_node_by_name("service-x") }

  it "exports a namespaced envfile URL and provider-named container variable" do
    expect(consumer.compose_environment.as_json).to include("SERVICE_Y_URL=${SERVICE_X__SERVICE_Y_URL}")
    expect(envfile_lines(consumer)).to include("SERVICE_X__SERVICE_Y_URL=http://service-y:3000")
  end

  it "uses the provider scheme override" do
    provider.internal_url_scheme = "https"

    expect(envfile_lines(consumer)).to include("SERVICE_X__SERVICE_Y_URL=https://service-y:3000")
  end

  def envfile_lines(realized_node)
    realized_node.env_vars_for_env_file.map(&:env_repr)
  end
end
