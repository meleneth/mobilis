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

  it "delegates parse and revisions to Diesl without normalizing source bytes" do
    document = described_class.new(source)
    expect(document.parse_result).to be_a(Prism::ParseResult)
    expect(document.revision).to eq(Diesl::Source.new(source).revision)
    expect(document.analyze.source).to eq(source)
  end

  it "preserves source offsets for multibyte Ruby literals" do
    unicode = <<~RUBY
      # spacecraft 🪐
      Mobilis::DSL.build("unicode") do
        redis("mémoire")
      end
    RUBY
    document = described_class.new(unicode)
    changed = document.rename(document.analyze.declarations.first.id, "cache")
    expect(changed).to include("# spacecraft 🪐")
    expect(changed).to include('redis("cache")')
    expect(described_class.new(changed).analyze).to be_valid
  end

  it "uses byte offsets when inserting after Unicode source content" do
    unicode = <<~RUBY
      # ☃️ source heading
      Mobilis::DSL.build("unicode") do
        postgres("database")
        redis("session")
        connect(from: "session", to: "database")
      end
    RUBY
    document = described_class.new(unicode)
    added = document.add(:redis, "cache")
    expect(added).to include("# ☃️ source heading")
    expect(added).to include("  redis(\"session\")\n  redis(\"cache\")\n  connect(from: \"session\", to: \"database\")\n")
    expect(described_class.new(added).analyze).to be_valid
  end

  it "preserves string-keyed nested relationship literals when encoding through Diesl" do
    document = described_class.new(source)
    literal = document.send(:ruby_literal, {topics: [{group: "consumer"}]})
    expect(literal).to eq('{"topics" => [{"group" => "consumer"}]}')
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

  it "implicitly binds repeated literals in DSL content during an AST service rename" do
    connected = <<~RUBY
      # cache remains a comment
      outside = "cache"
      Mobilis::DSL.build("cache") do
        redis("cache")
        postgres("database")
        display_name = "cache"
        aliases = ["cache", "unrelated"]
        connect(from: "cache", to: "database")
      end
    RUBY
    document = described_class.new(connected)
    changed = connected.sub('redis("cache")', 'redis("canhe")')
    synchronized = document.propagate_service_rename(changed)

    expect(synchronized).to include('redis("canhe")')
    expect(synchronized).to include('display_name = "canhe"')
    expect(synchronized).to include('aliases = ["canhe", "unrelated"]')
    expect(synchronized).to include('connect(from: "canhe", to: "database")')
    expect(synchronized).to include('outside = "cache"')
    expect(synchronized).to include('Mobilis::DSL.build("cache")')
    expect(synchronized).to include('# cache remains a comment')
    expect(described_class.new(synchronized).analyze).to be_valid
  end

  it "returns nil instead of guessing when an edit is outside a service-name literal" do
    connected = <<~RUBY
      Mobilis::DSL.build("demo") do
        redis("cache")
        postgres("database")
        alias_name = "cache"
        connect(from: "cache", to: "database")
      end
    RUBY
    document = described_class.new(connected)
    edited = connected.sub('alias_name = "cache"', 'alias_name = "cache2"')

    expect(document.propagate_service_rename(edited)).to be_nil
  end

  it "atomically renames a service and every bound literal using its declaration ID" do
    connected = <<~RUBY
      Mobilis::DSL.build("browser-demo") do
        postgres("database")
        redis("casz")
        connect(from: "casz", to: "database")
      end
    RUBY
    document = described_class.new(connected)
    declaration = document.analyze.declarations.find { |candidate| candidate.name == "casz" }

    changed = document.rename_with_references(declaration.id, "cas2")

    expect(changed).to include('redis("cas2")')
    expect(changed).to include('connect(from: "cas2", to: "database")')
    expect(changed).not_to include('"casz"')
    expect(described_class.new(changed).analyze).to be_valid
  end

  it "refuses a duplicate identity rather than changing unrelated declarations" do
    connected = <<~RUBY
      Mobilis::DSL.build("demo") do
        redis("cache")
        postgres("database")
        connect(from: "cache", to: "database")
      end
    RUBY
    document = described_class.new(connected)
    declaration = document.analyze.declarations.find { |candidate| candidate.name == "cache" }

    expect { document.rename_with_references(declaration.id, "database") }
      .to raise_error(ArgumentError, /already declared/)
  end

  it "propagates a single DSL keystroke through the same atomic rename as the builder" do
    original = <<~RUBY
      Mobilis::DSL.build("browser-demo") do
        postgres("database")
        redis("casz")
        connect(from: "casz", to: "database")
      end
    RUBY
    document = described_class.new(original)
    edited = original.sub('redis("casz")', 'redis("cas2z")')

    synchronized = document.propagate_service_rename(edited)

    expect(synchronized).to include('redis("cas2z")')
    expect(synchronized).to include('connect(from: "cas2z", to: "database")')
    expect(described_class.new(synchronized).analyze).to be_valid
  end

  it "does not infer a rename when a paste changes anything outside the declaration" do
    original = <<~RUBY
      Mobilis::DSL.build("demo") do
        postgres("database")
        redis("cache")
        connect(from: "cache", to: "database")
      end
    RUBY
    edited = original.sub('redis("cache")', 'redis("cache2")')
      .sub('connect(from: "cache"', 'connect(from: "cache2"')

    expect(described_class.new(original).propagate_service_rename(edited)).to be_nil
  end

  it "replaces only the explicit starting port literal without changing its surrounding source" do
    source = <<~RUBY
      # preserve this header
      Mobilis::DSL.generate("demo", starting_port: 11_000) do
        redis("cache")
      end
    RUBY
    document = described_class.new(source)

    expect(document.starting_port_editable?).to be(true)
    updated = document.update_starting_port("12000")
    expect(updated).to include('Mobilis::DSL.generate("demo", starting_port: 12000) do')
    expect(updated).to include("# preserve this header")
    expect(described_class.new(updated).analyze.system.starting_port).to eq(12_000)
  end

  it "adds a starting port keyword when the root uses the default" do
    document = described_class.new(source)
    updated = document.update_starting_port("12500")

    expect(updated).to include('Mobilis::DSL.build("demo", starting_port: 12500) do')
    expect(described_class.new(updated).analyze.system.starting_port).to eq(12_500)
  end

  it "blocks invalid port values and dynamic port expressions" do
    document = described_class.new(source)
    %w[0 65536 3.5 abc].each do |value|
      expect { document.update_starting_port(value) }.to raise_error(ArgumentError, /Starting port/)
    end

    dynamic = <<~RUBY
      port = 12_000
      Mobilis::DSL.build("demo", starting_port: port) do
        redis("cache")
      end
    RUBY
    document = described_class.new(dynamic)
    expect(document.starting_port_editable?).to be(false)
    expect { document.update_starting_port("13000") }.to raise_error(ArgumentError, /computed/)
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
