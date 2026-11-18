# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::SourceDocument do
  let(:source) do
    <<~RUBY
      # project heading
      Mobilis::DSL.build("demo") do
        # keep this database comment
        postgres( "main-db" ) # inline note

        helper = 40 + 2
      end
    RUBY
  end

  it "evaluates source into the real declaration model" do
    analysis = described_class.new(source).analyze

    expect(analysis).to be_valid
    expect(analysis.system.config_nodes.values.map(&:name)).to eq(["main-db"])
    expect(analysis.declarations.first.to_h).to include(type: :postgres, name: "main-db", editable: true)
  end

  it "round trips byte-identically without a visual change" do
    expect(described_class.new(source).analyze.source).to eq(source)
  end

  it "surgically renames a service while preserving comments and unrelated source" do
    document = described_class.new(source)
    changed = document.rename(document.analyze.declarations.first.id, "accounts")

    expect(changed).to include("postgres( \"accounts\" ) # inline note")
    expect(changed).to include("# keep this database comment")
    expect(changed).to include("helper = 40 + 2")
  end

  it "changes only the service call when changing type" do
    document = described_class.new(source)
    changed = document.change_type(document.analyze.declarations.first.id, :redis)

    expect(changed).to include("redis( \"main-db\" ) # inline note")
  end

  it "reports invalid source without creating a model" do
    analysis = described_class.new("Mobilis::DSL.build( do").analyze

    expect(analysis).not_to be_valid
    expect(analysis.system).to be_nil
    expect(analysis.errors).not_to be_empty
  end

  it "does not rewrite unsupported dynamic service names" do
    dynamic = <<~RUBY
      name = "database"
      Mobilis::DSL.build("demo") do
        postgres(name)
      end
    RUBY
    document = described_class.new(dynamic)
    declaration = document.analyze.declarations.first

    expect(declaration.editable).to be(false)
    expect { document.rename(declaration.id, "other") }
      .to raise_error(ArgumentError, /cannot be safely rewritten/)
    expect(document.source).to eq(dynamic)
  end

  it "adds services inside the build block without regenerating existing source" do
    changed = described_class.new(source).add(:redis, "cache")

    expect(changed).to include("  redis(\"cache\")\nend")
    expect(changed).to start_with("# project heading")
  end

  it "removes static connections associated with a visually removed service" do
    connected = <<~RUBY
      Mobilis::DSL.build("demo") do
        rack("api")
        redis("cache")
        postgres("database")
        connect(from: "api", to: "cache")
        connect(from: "cache", to: "database") # removed with cache
      end
    RUBY
    document = described_class.new(connected)
    cache = document.analyze.declarations.find { |declaration| declaration.name == "cache" }
    changed = document.remove(cache.id)

    expect(changed).to include('rack("api")')
    expect(changed).to include('postgres("database")')
    expect(changed).not_to include('redis("cache")')
    expect(changed).not_to include("connect(")
    expect(described_class.new(changed).analyze).to be_valid
  end

  it "authors Rails while evaluating generate declarations without materializing" do
    rails_source = <<~RUBY
      # locally executable definition
      Mobilis::DSL.generate("rails-demo") do
        rails("web", api: true)
      end
    RUBY

    analysis = described_class.new(rails_source).analyze

    expect(analysis).to be_valid
    expect(analysis.declarations.first.to_h).to include(type: :rails, name: "web")
    expect(analysis.system.config_nodes.values.first).to be_a(Mobilis::Node::Rails)
    expect(analysis.source).to eq(rails_source)
  end

  it "updates literal service properties without reformatting the declaration" do
    property_source = <<~RUBY
      Mobilis::DSL.build("demo") do
        rails( "web", api: false ) # preserve
      end
    RUBY
    document = described_class.new(property_source)
    changed = document.update_property(document.analyze.declarations.first.id, :api, true)

    expect(changed).to include('rails( "web", api: true ) # preserve')
  end

  it "refuses to overwrite dynamic property expressions" do
    property_source = <<~RUBY
      api_mode = ENV["API"]
      Mobilis::DSL.build("demo") do
        rails("web", api: api_mode)
      end
    RUBY
    document = described_class.new(property_source)

    expect { document.update_property(document.analyze.declarations.first.id, :api, true) }
      .to raise_error(ArgumentError, /Dynamic property/)
  end
end
