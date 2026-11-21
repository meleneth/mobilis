# frozen_string_literal: true

require "spec_helper"
require "diesl"
require "mobilis/browser/diesl_editor"

RSpec.describe "Diesl/Mobilis source adapter parity" do
  let(:adapter) { Mobilis::Browser::DIESL_SOURCE_ADAPTER }
  let(:editor) { Mobilis::Browser::DIESL_EDITOR }
  let(:source) do
    <<~RUBY
      # preserve this heading
      Mobilis::DSL.build("diesl-parity") do
        rails("api", api: false) # keep
        postgres("db")
      end
    RUBY
  end

  def apply(source, operation, **arguments)
    adapter.apply(source, operation:, expected_revision: adapter.revision(source), **arguments)
  end

  def document(source) = Mobilis::Browser::SourceDocument.new(source)

  it "declares a generated-artifact workspace without staging source" do
    manifest = editor.workspace.manifest
    expect(manifest.fetch(:source).fetch(:path)).to eq("mobilis.rb")
    expect(manifest.fetch(:git).fetch(:stage)).to eq(["generated"])
    expect(manifest.fetch(:embedded).first.fetch(:call)).to eq("embedded_archive")
    expect(editor.source_adapter).to equal(adapter)
    expect(editor.adapted_session(source:).analysis).to be_valid
  end

  it "matches the original source document for service creation and renaming" do
    added = apply(source, :add_service, type: :redis, name: "cache")
    expect(added).to eq(document(source).add(:redis, "cache"))
    id = document(added).analyze.declarations.find { |item| item.name == "cache" }.id
    renamed = apply(added, :rename_service, id:, name: "sessions")
    expect(renamed).to eq(document(added).rename(id, "sessions"))
    expect(renamed).to include("# preserve this heading", " # keep")
  end

  it "matches the original type switch, property edit and removal" do
    id = document(source).analyze.declarations.first.id
    changed = apply(source, :update_service_property, id:, property: :api, value: true)
    expect(changed).to eq(document(source).update_property(id, :api, true))
    changed = apply(source, :change_service_type, id:, type: :rack)
    expect(changed).to eq(document(source).change_type(id, :rack))
    changed = apply(source, :remove_service, id:)
    expect(changed).to eq(document(source).remove(id))
    expect(document(changed).analyze).to be_valid
  end

  it "round trips relationships against existing Mobilis behavior" do
    connected = apply(source, :add_relationship, from: "api", to: "db")
    expect(connected).to eq(document(source).add_relationship(from: "api", to: "db"))
    id = document(connected).analyze.relationships.first.id
    retargeted = apply(connected, :update_relationship, id:, property: :to, value: "api")
    expect(retargeted).to eq(document(connected).update_relationship(id, :to, "api"))
    id = document(retargeted).analyze.relationships.first.id
    restored = apply(retargeted, :remove_relationship, id:)
    expect(restored).to eq(document(retargeted).remove_relationship(id))
    expect(restored).to eq(source)
  end

  it "preserves archive siblings and source trivia through a revision-guarded transaction" do
    payload = Mobilis::EmbeddedArchive.pack(files: {"src/a.rb" => "before\n", "README.md" => "keep\n"})
    embedded = <<~RUBY
      # preserve root
      Mobilis::DSL.build("archives") do
        rack("app") do |service|
          service.embedded_archive("source", payload: #{payload.dump}) # keep
        end
      end
    RUBY
    archive = document(embedded).analyze.archives.fetch(0)
    changed = apply(embedded, :commit_embedded_document, id: archive.id, path: "src/a.rb",
      content: "after\n", parent_revision: archive.parent_revision)
    expected = document(embedded).commit_embedded_archive(archive.id, "src/a.rb", "after\n",
      parent_revision: archive.parent_revision)
    expect(changed).to eq(expected)
    bundle = document(changed).analyze.archives.first.bundle
    expect(bundle.entry("README.md").content).to eq("keep\n")
    expect(bundle.entry("src/a.rb").content).to eq("after\n")
    expect(changed).to include("# preserve root", "# keep")
  end

  it "keeps the last valid model during invalid typing and supports structured undo/redo" do
    session = editor.adapted_session(source:)
    original_names = session.analysis.declarations.map(&:name)
    expect(session.type_source("Mobilis::DSL.build(", expected_revision: session.revision)).to be(false)
    expect(session.analysis.declarations.map(&:name)).to eq(original_names)
    expect(session.draft_valid?).to be(false)
    expect { session.apply(operation: :add_service, type: :redis, name: "cache",
      expected_revision: session.revision) }.to raise_error(Diesl::Conflict)
    session.undo
    expect(session.apply(operation: :add_service, type: :redis, name: "cache",
      expected_revision: session.revision)).to be(true)
    expect(session.analysis.declarations.map(&:name)).to include("cache")
    session.undo
    expect(session.source).to eq(source)
    session.redo
    expect(session.analysis.declarations.map(&:name)).to include("cache")
  end

  it "rejects stale revisions, unknown mutations and invalid domain edits without writing source" do
    session = editor.adapted_session(source:)
    expect { session.apply(operation: :add_service, type: :redis, name: "cache",
      expected_revision: "stale") }.to raise_error(Diesl::Conflict)
    expect { session.apply(operation: :kernel_eval, expected_revision: session.revision) }
      .to raise_error(Diesl::UnsafeEdit)
    expect { session.apply(operation: :add_service, type: :missing, name: "x",
      expected_revision: session.revision) }.to raise_error(ArgumentError)
    expect(session.source).to eq(source)
  end
end
