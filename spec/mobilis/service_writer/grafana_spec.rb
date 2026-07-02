# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Grafana do
  let(:manifest) { build(:manifest, system: build(:system, :with_observable_rails_and_databases), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("grafana") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "adds datasources for generated observability and database services" do
    datasources = writer.datasources.to_serial.fetch("datasources")
    expect(datasources).to include(
      {
        "name" => "Loki",
        "type" => "loki",
        "uid" => "loki_loki_ds",
        "access" => "proxy",
        "url" => "http://loki:3100",
        "isDefault" => false
      }
    )
    expect(datasources).to include(
      hash_including(
        "name" => "PostgreSQL userdb",
        "type" => "postgres",
        "url" => "userdb:5432",
        "jsonData" => hash_including("database" => "userdb_test")
      )
    )
    expect(datasources).to include(
      hash_including(
        "name" => "MySQL legacydb",
        "type" => "mysql",
        "url" => "legacydb:3306",
        "jsonData" => hash_including("database" => "legacydb_test")
      )
    )
    expect(datasources).to include(
      hash_including(
        "name" => "Jaeger",
        "type" => "jaeger",
        "url" => "http://jaeger:16686"
      )
    )
  end

  it "builds dashboards from generated services and filtered ActiveResource affordances" do
    dashboards = writer.dashboards
    expect(dashboards.keys).to include(
      "mobilis-overview.json",
      "mobilis-filtered-activeresource.json"
    )

    filtered_dashboard = dashboards.fetch("mobilis-filtered-activeresource.json")
    expect(filtered_dashboard[:panels].first[:options][:content]).to include("Filter fields: id, account_id, email")
  end

  it "writes datasource and dashboard provisioning files" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        writer.write

        expect(File).to exist("provisioning/datasources/mobilis.yml")
        expect(File).to exist("provisioning/dashboards/mobilis.yml")
        expect(File).to exist("provisioning/dashboards/mobilis-overview.json")
        expect(File).to exist("provisioning/dashboards/mobilis-filtered-activeresource.json")
      end
    end
  end

  context "with S3 storage" do
    let(:manifest) { build(:manifest, system: build(:system, :with_observable_s3_storage), suppress_plugins: true) }

    it "adds generated log and metric panels for SeaweedFS-backed S3 storage" do
      overview = writer.dashboards.fetch("mobilis-overview.json")
      panel_titles = overview[:panels].map { |panel| panel[:title] }

      expect(panel_titles).to include("assets logs")
      expect(panel_titles).to include("assets SeaweedFS up")
      expect(overview[:panels]).to include(
        hash_including(
          title: "assets SeaweedFS up",
          targets: [
            hash_including(expr: 'up{job="assets_seaweedfs"}')
          ]
        )
      )
    end

    it "does not add S3 panels when the storage node is not wired to observability" do
      manifest = build(
        :manifest,
        system: build(:system, :with_otel, :with_s3_storage),
        suppress_plugins: true
      )
      realized_env = manifest.realized_env(:test)
      realized_node = realized_env.find_realized_node_by_name("grafana")
      writer = described_class.new(manifest, realized_env, realized_node)
      overview = writer.dashboards.fetch("mobilis-overview.json")
      panel_titles = overview[:panels].map { |panel| panel[:title] }

      expect(panel_titles).not_to include("assets logs")
      expect(panel_titles).not_to include("assets SeaweedFS up")
    end
  end
end
