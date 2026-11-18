# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::Topology do
  def analyze(source)
    Mobilis::Browser::SourceDocument.new(source).analyze.tap do |analysis|
      expect(analysis.errors).to be_empty
    end
  end

  def topology(source)
    described_class.from_analysis(analyze(source))
  end

  let(:source) do
    <<~RUBY
      Mobilis::DSL.build("diagram") do
        postgres("database")
        redis("cache")
        rack("api")
        connect(from: "api", to: "cache")
        connect(from: "cache", to: "database")
      end
    RUBY
  end

  it "projects multiple service types, connections, and disconnected services from the validated system" do
    result = topology(source)

    expect(result.nodes.map { |node| [node.name, node.label, node.category] }).to contain_exactly(
      ["api", "Rack: api", :application],
      ["cache", "Redis: cache", :data],
      ["database", "PostgreSQL: database", :data]
    )
    expect(result.edges.map { |edge| [result.node(edge.from).name, result.node(edge.to).name] }).to contain_exactly(
      ["api", "cache"],
      ["cache", "database"]
    )
  end

  it "projects declared reference relationships in addition to connect calls" do
    result = topology(<<~RUBY)
      Mobilis::DSL.build("references") do
        rails("web", primary_database: postgres("primary"))
        alloy("logs", loki: loki("loki"))
      end
    RUBY

    relationships = result.edges.to_h do |edge|
      [[result.node(edge.from).name, result.node(edge.to).name], edge.relationship]
    end
    expect(relationships).to include(
      ["web", "primary"] => "primary database",
      ["logs", "loki"] => "loki"
    )
  end

  it "covers every service type exposed by the browser authoring model" do
    calls = Mobilis::Browser::SourceDocument::SERVICE_TYPES.map.with_index do |type, index|
      "  #{type}(\"service-#{index}\")"
    end
    result = topology((["Mobilis::DSL.build(\"all\") do"] + calls + ["end", ""]).join("\n"))

    expect(result.nodes.length).to eq(Mobilis::Browser::SourceDocument::SERVICE_TYPES.length)
    expect(result.nodes).to all(satisfy { |node| node.label.end_with?(node.name) && node.category })
  end

  it "uses deterministic safe identifiers independent of service names and random model IDs" do
    unsafe_source = <<~'RUBY'
      Mobilis::DSL.build("safe") do
        rack("quotes \" brackets ] <script> | ampersand &")
      end
    RUBY
    first = topology(unsafe_source)
    second = topology(unsafe_source)

    expect(first.nodes.map(&:id)).to eq(second.nodes.map(&:id))
    expect(first.nodes.first.id).to match(/\Aservice_[0-9a-f]{16}\z/)
    expect(first.nodes.first.id).not_to include(first.nodes.first.name)
  end

  it "removes nodes and edges when the validated source no longer contains them" do
    original = topology(source)
    changed = source.lines.reject { |line| line.include?('rack("api")') || line.include?('from: "api"') }.join
    updated = topology(changed)

    expect(original.nodes.map(&:name)).to include("api")
    expect(updated.nodes.map(&:name)).not_to include("api")
    expect(updated.edges.length).to eq(1)
  end
end

RSpec.describe Mobilis::Browser::MermaidDiagram do
  let(:source) do
    <<~'RUBY'
      Mobilis::DSL.build("diagram") do
        rack("<api> | \"edge\"")
        postgres("database")
        connect(from: "<api> | \"edge\"", to: "database")
      end
    RUBY
  end

  it "renders deterministic Mermaid with escaped labels and safe node identifiers" do
    analysis = Mobilis::Browser::SourceDocument.new(source).analyze
    topology = Mobilis::Browser::Topology.from_analysis(analysis)
    first = described_class.new(topology).source
    second = described_class.new(Mobilis::Browser::Topology.from_analysis(analysis)).source

    expect(first).to eq(second)
    expect(first).to start_with("flowchart LR\n")
    expect(first).to include("&lt;api&gt; &#124; &quot;edge&quot;")
    expect(first).not_to include('rack("<api>')
    expect(first).to match(/service_[0-9a-f]{16} --> service_[0-9a-f]{16}/)
  end
end
