# frozen_string_literal: true

require "haml"
require_relative "../../../playground/app/renderer"

RSpec.describe MobilisPlayground::Renderer do
  it "renders Haml components without a server framework" do
    html = described_class.new.render(
      :diagnostics,
      errors: [],
      status: "Runtime initialized"
    )

    expect(html).to include("Runtime initialized")
    expect(html).to include("border-teal-950")
  end

  it "renders Turbo Stream messages for targeted updates" do
    stream = described_class.new.stream(action: "replace", target: "diagnostics-region", html: "<p>ok</p>")

    expect(stream).to eq('<turbo-stream action="replace" target="diagnostics-region"><template><p>ok</p></template></turbo-stream>')
  end

  it "renders a first-class stale state without changing the retained topology" do
    analysis = Mobilis::Browser::SourceDocument.new(<<~RUBY).analyze
      Mobilis::DSL.build("diagram") do
        postgres("database")
      end
    RUBY
    topology = Mobilis::Browser::Topology.from_analysis(analysis)
    html = described_class.new.render(:architecture, topology:, stale: true)

    expect(html).to include("Stale — source is invalid")
    expect(html).to include("1 nodes · 0 edges")
    expect(html).to include("id='architecture-canvas'")
  end

  it "renders the full inspector with distinct connection and dependency sections" do
    analysis = Mobilis::Browser::SourceDocument.new(<<~RUBY).analyze
      Mobilis::DSL.build("inspect") do
        rack("api")
        redis("cache")
        connect(from: "api", to: "cache")
      end
    RUBY
    topology = Mobilis::Browser::Topology.from_analysis(analysis)
    services = Mobilis::Browser::ServiceInspector.new(analysis, topology).services
    documents = Mobilis::Browser::VirtualDocument.new(analysis)
    html = described_class.new.render(:inspector, services:, documents:, archives: analysis.archives)

    expect(html).to include("Semantic outgoing connections")
    expect(html).to include("Operational dependencies")
    expect(html).to include("Complete validated configuration")
    expect(html).to include("relationship-editor")
  end
end
