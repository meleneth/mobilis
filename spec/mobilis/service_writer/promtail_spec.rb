# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Promtail do
  let(:manifest) { build(:manifest, system: build(:system, :with_otel), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("promtail") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "uses docker discovery scoped to generated compose projects" do
    scrape = writer.config.fetch("scrape_configs").first
    docker_sd = scrape.fetch("docker_sd_configs").first
    expect(docker_sd.fetch("host")).to eq("unix:///var/run/docker.sock")
    expect(docker_sd.fetch("filters")).to eq(
      [
        {
          "name" => "label",
          "values" => [
            "com.docker.compose.project=generate-test",
            "com.docker.compose.project=generate-development",
            "com.docker.compose.project=generate-production"
          ]
        }
      ]
    )
    expect(scrape.fetch("relabel_configs")).to include(
      {
        "source_labels" => ["__meta_docker_container_label_com_docker_compose_project"],
        "regex" => "generate-(test|development|production)",
        "action" => "keep"
      },
      {
        "source_labels" => ["__meta_docker_container_label_com_docker_compose_service"],
        "target_label" => "service_name"
      }
    )
    expect(writer.config.fetch("clients").first.fetch("url")).to eq("http://loki:3100/loki/api/v1/push")
  end
end
