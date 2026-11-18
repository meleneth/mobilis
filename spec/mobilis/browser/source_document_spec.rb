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

  it "adds a service before relationships so it can become their target" do
    source = <<~RUBY
      Mobilis::DSL.build("ordered") do
        rack("api")
        redis("cache")
        connect(from: "api", to: "cache")
      end
    RUBY

    changed = described_class.new(source).add(:redis, "queue")
    retargeted = described_class.new(changed).update_relationship(
      described_class.new(changed).analyze.relationships.fetch(0).id,
      :to,
      "queue"
    )

    expect(retargeted.index('redis("queue")')).to be < retargeted.index("connect(")
    expect(described_class.new(retargeted).analyze).to be_valid
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

  it "locates semantic relationship declarations and preserves their options" do
    connected = <<~RUBY
      Mobilis::DSL.build("demo") do
        rack("api")
        kafka("events") { |broker| broker.topic("commands", partitions: 1, retention_ms: 1_000) }
        connect(from: "api", to: "events", publish: "commands") # preserve
      end
    RUBY

    relationship = described_class.new(connected).analyze.relationships.fetch(0)

    expect(relationship.to_h).to include(
      kind: :connect, from: "api", to: "events", editable: true,
      properties: include(publish: "commands")
    )
  end

  it "surgically changes and removes relationship fields without touching comments" do
    connected = <<~RUBY
      Mobilis::DSL.build("demo") do
        rack("api")
        redis("cache")
        postgres("database")
        connect(from: "api", to: "cache", force_skip_health_checks: true) # keep me
      end
    RUBY
    document = described_class.new(connected)
    id = document.analyze.relationships.fetch(0).id
    changed = document.update_relationship(id, :to, "database")
    changed_document = described_class.new(changed)
    changed_id = changed_document.analyze.relationships.fetch(0).id
    changed = changed_document.update_relationship(changed_id, :force_skip_health_checks, nil)

    expect(changed).to include('connect(from: "api", to: "database") # keep me')
    expect(described_class.new(changed).analyze).to be_valid
  end

  it "adds and removes one relationship declaration without regenerating services" do
    document = described_class.new(source)
    connected = document.add_relationship(from: "main-db", to: "main-db", kind: :connect)
    connected_document = described_class.new(connected)
    relationship = connected_document.analyze.relationships.fetch(0)
    restored = connected_document.remove_relationship(relationship.id)

    expect(connected).to include('connect(from: "main-db", to: "main-db")')
    expect(restored).to eq(source)
  end

  it "rejects rewriting a dynamic relationship" do
    dynamic = <<~RUBY
      target = "cache"
      Mobilis::DSL.build("demo") do
        rack("api")
        redis("cache")
        connect(from: "api", to: target)
      end
    RUBY
    document = described_class.new(dynamic)

    expect(document.analyze.relationships.fetch(0).editable).to be(false)
    expect { document.update_relationship(document.analyze.relationships.fetch(0).id, :to, "other") }
      .to raise_error(ArgumentError, /Dynamic relationships/)
  end

  it "locates and atomically commits literal embedded archives" do
    payload = Mobilis::EmbeddedArchive.pack(files: {"lib/app.rb" => "puts :before\n", "README.md" => "keep\n"})
    embedded = <<~RUBY
      # preserve the parent
      Mobilis::DSL.build("embedded") do
        rack("app") do |service|
          service.embedded_archive("source", payload: #{payload.dump}) # preserve this too
        end
      end
    RUBY
    document = described_class.new(embedded)
    archive = document.analyze.archives.fetch(0)
    changed = document.commit_embedded_archive(
      archive.id,
      "lib/app.rb",
      "puts :after\n",
      parent_revision: archive.parent_revision
    )
    reopened = described_class.new(changed).analyze.archives.fetch(0).bundle

    expect(changed).to include("# preserve the parent", "# preserve this too")
    expect(reopened.entry("lib/app.rb").content).to eq("puts :after\n")
    expect(reopened.entry("README.md").content).to eq("keep\n")
    expect(described_class.new(changed).analyze).to be_valid
  end

  it "rejects an embedded archive commit when the parent revision changed" do
    payload = Mobilis::EmbeddedArchive.pack(files: {"app.rb" => "before\n"})
    embedded = <<~RUBY
      Mobilis::DSL.build("embedded") do
        rack("app") { |service| service.embedded_archive("source", payload: #{payload.dump}) }
      end
    RUBY
    opened = described_class.new(embedded).analyze.archives.fetch(0)
    newer = described_class.new("# newer\n#{embedded}")

    expect do
      newer.commit_embedded_archive(opened.id, "app.rb", "after\n", parent_revision: opened.parent_revision)
    end.to raise_error(ArgumentError, /parent Ruby source changed/)
    expect(newer.source).to eq("# newer\n#{embedded}")
  end

  it "reports malformed embedded payloads without rewriting source" do
    embedded = <<~RUBY
      Mobilis::DSL.build("embedded") do
        rack("app") { |service| service.embedded_archive("source", payload: "broken") }
      end
    RUBY

    analysis = described_class.new(embedded).analyze

    expect(analysis).not_to be_valid
    expect(analysis.errors.join).to match(/Base64|archive/i)
    expect(analysis.source).to eq(embedded)
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
