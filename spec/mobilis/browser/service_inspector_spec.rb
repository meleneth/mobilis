# frozen_string_literal: true

require "spec_helper"
require "mobilis/browser/diesl_editor"

RSpec.describe Mobilis::Browser::ServiceInspector do
  let(:analysis) do
    Mobilis::Browser::SourceDocument.new(<<~RUBY).analyze
      Mobilis::DSL.build("inspect") do
        postgres("database")
        rails("web", primary_database: named("database"), api: true)
        redis("cache")
        connect(from: "web", to: "cache", force_skip_health_checks: true)
      end
    RUBY
  end

  subject(:services) do
    topology = Mobilis::Browser::Topology.from_analysis(analysis)
    described_class.new(analysis, topology).services
  end

  it "composes source declarations with the complete validated node configuration" do
    web = services.find { |service| service.name == "web" }

    expect(web.declaration.type).to eq(:rails)
    expect(web.editable_properties).to include(:api)
    expect(JSON.parse(web.configuration)).to include(
      "name" => "web",
      "type" => "Mobilis::Node::Rails",
      "api_mode" => true
    )
  end

  it "honors Diesl field metadata provided by the live editor instead of duplicate UI rules" do
    topology = Mobilis::Browser::Topology.from_analysis(analysis)
    fields = Mobilis::Browser::DIESL_EDITOR.entities.fetch(:rails).fields
    properties = {rails: fields.reject { |field| field.name == :name }.to_h { |field|
      [field.name, {kind: field.type, default: field.default}]
    }}
    projected = described_class.new(analysis, topology, property_schemas: properties).services
    web = projected.find { |service| service.name == "web" }
    expect(web.editable_properties).to eq(api: {kind: :boolean, default: false})
    expect(projected.find { |service| service.name == "cache" }.editable_properties).to be_empty
  end

  it "keeps semantic connections, operational dependencies, and references distinct" do
    web = services.find { |service| service.name == "web" }
    cache = services.find { |service| service.name == "cache" }

    expect(web.outgoing.map(&:to)).to eq(["cache"])
    expect(web.dependencies.map { |dependency| [dependency.target, dependency.kind] }).to eq([["cache", :operational]])
    expect(web.references.map { |reference| [reference.target, reference.kind] }).to eq([["database", :primary_database]])
    expect(cache.incoming.map(&:from)).to eq(["web"])
  end

  it "represents every evaluated service even when a nested declaration has no direct visual range" do
    nested = Mobilis::Browser::SourceDocument.new(<<~RUBY).analyze
      Mobilis::DSL.build("nested") do
        rails("web", primary_database: postgres("database"))
      end
    RUBY
    topology = Mobilis::Browser::Topology.from_analysis(nested)
    projected = described_class.new(nested, topology).services

    expect(projected.map(&:name)).to contain_exactly("web", "database")
    expect(projected.find { |service| service.name == "database" }.declaration).to be_nil
  end
end
