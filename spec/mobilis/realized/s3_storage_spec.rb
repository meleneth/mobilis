# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::S3Storage do
  let(:s3_node) { build(:s3_storage_node, name: "assets", buckets: ["uploads"]) }
  let(:system)  { build(:system, nodes: [s3_node]) }
  let(:env)     { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  subject(:realized_s3) do
    described_class.new(env, s3_node)
  end

  it "sets data volume and service directory flags" do
    expect(realized_s3.has_data_volume).to be true
    expect(realized_s3.has_service_dir).to be true
    expect(realized_s3.has_dockerfile).to be false
  end

  it "constructs S3 consumer variables" do
    Mobilis::Base::RealizedNode.class_variable_set(:@@next_port_no, 42_069)

    keys = realized_s3.envfile_vars.data.map(&:env_repr)
    expect(keys).to eq([
                         "ASSETS_S3_ENDPOINT_URL=http://assets:8333",
                         "ASSETS_S3_ACCESS_KEY_ID=assets-test-access-key",
                         "ASSETS_S3_SECRET_ACCESS_KEY=assets-test-secret-key",
                         "ASSETS_S3_REGION=us-east-1",
                         "ASSETS_S3_BUCKET=uploads",
                         "ASSETS_S3_PORT=42079",
                         "ASSETS_SEAWEEDFS_DATA=./data/test/assets"
                       ])
  end

  it "#compose" do
    expect(realized_s3.compose.clean_shrunk).to eq(
      image: "chrislusf/seaweedfs:4.37",
      ports: [
        "${ASSETS_S3_PORT}:8333"
      ],
      volumes: [
        "${ASSETS_SEAWEEDFS_DATA}:/data",
        "./assets/entrypoint.sh:/usr/local/bin/mobilis-seaweedfs-entrypoint.sh"
      ],
      healthcheck: {
        test: [
          "CMD-SHELL",
          "wget -qO- http://127.0.0.1:9333/cluster/status >/dev/null"
        ],
        interval: "10s",
        timeout: "5s",
        retries: 5,
        start_period: "5s"
      },
      entrypoint: [
        "/bin/sh",
        "/usr/local/bin/mobilis-seaweedfs-entrypoint.sh"
      ]
    )
  end
end
