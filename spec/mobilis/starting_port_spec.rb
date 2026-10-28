# frozen_string_literal: true

require "spec_helper"

RSpec.describe "starting_port" do
  def ports_for(starting_port)
    system = Mobilis::System.new("syracuse-three", starting_port: starting_port)
    system << Mobilis::Node::PostgreSQL.new("telemetry-db")
    system << Mobilis::Node::FastAPI.new("query", port: 8000)
    manifest = Mobilis::Manifest.new(system, suppress_plugins: true)
    manifest.realized_envs.to_h do |env|
      [env.environment.to_s, env.realized_nodes.flat_map do |node|
        node.envfile_vars.data.filter_map do |var|
          var.value if var.envfile_name&.end_with?("_PORT")
        end
      end]
    end
  end

  it "preserves the original starting port and increments across environments" do
    expect(ports_for(11_000)).to eq(
      "test" => [11_000, 11_010],
      "development" => [11_020, 11_030],
      "production" => [11_040, 11_050]
    )
  end

  it "allocates independent, collision-free Syracuse environments" do
    values = [11_000, 21_000, 31_000].flat_map { |start| ports_for(start).values.flatten }
    expect(values.uniq).to eq(values)
    expect(values).to include(11_000, 21_000, 31_000)
  end

  it "retains explicit internal ports and serializes the configured start" do
    system = Mobilis::System.new("example", starting_port: 31_000)
    system << Mobilis::Node::FastAPI.new("api", port: 8765)
    loaded = Mobilis::System.from_json(system.to_json)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:development))
    node = env.realized_node_by_name("api")
    expect(loaded.starting_port).to eq(31_000)
    expect(node.exposed_port_no).to eq(8765)
    expect(node.envfile_vars.data.find { |var| var.envfile_name == "API_WEB_PORT" }.value).to eq(31_000)
  end

  it "rejects invalid starting ports and exhausted ranges" do
    expect { Mobilis::System.new("bad", starting_port: 0) }.to raise_error(ArgumentError)
    expect { ports_for(65_530) }.to raise_error(ArgumentError, /exceed/)
  end
end
