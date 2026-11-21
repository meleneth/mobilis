# frozen_string_literal: true

require "diesl"

RSpec.describe Diesl::Source do
  let(:source) { described_class.new("config('old', enabled: true) # keep this comment\n") }

  it "discovers calls without executing the DSL" do
    expect(source.calls(name: :config).length).to eq(1)
    expect(source.valid?).to be(true)
  end

  it "preserves surrounding source exactly when changing a literal" do
    node = source.calls(name: :config).first.arguments.arguments.first
    expect(source.replace_literal(node, "new", expected_revision: source.revision))
      .to eq('config("new", enabled: true) # keep this comment' + "\n")
    expect(source.text).to include("'old'")
  end

  it "rejects revisions from a different source" do
    expect { source.replace(0, 0, "# note\n", expected_revision: "stale") }
      .to raise_error(Diesl::Conflict)
  end

  it "refuses computed values" do
    document = described_class.new("config(prefix + suffix)\n")
    node = document.calls(name: :config).first.arguments.arguments.first
    expect { document.replace_literal(node, "override", expected_revision: document.revision) }
      .to raise_error(Diesl::UnsafeEdit)
  end

  it "rejects replacements that would invalidate Ruby" do
    expect { source.replace(0, 6, "if", expected_revision: source.revision) }
      .to raise_error(Diesl::InvalidSource)
  end

  it "does not corrupt multibyte text when Prism gives byte offsets" do
    document = described_class.new("config('☃', enabled: true)\n")
    node = document.calls(name: :config).first.arguments.arguments.first
    expect(document.replace_literal(node, "☀", expected_revision: document.revision))
      .to eq("config(\"☀\", enabled: true)\n")
  end
end
