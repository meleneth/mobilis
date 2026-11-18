# frozen_string_literal: true

RSpec.describe Mobilis::Browser::VirtualDocument do
  let(:payload) do
    Mobilis::EmbeddedArchive.pack(
      files: {
        "README.md" => "hello\n",
        "assets/icon.bin" => "\xFF\x00".b
      },
      entrypoint: "README.md"
    )
  end
  let(:source) do
    <<~RUBY
      Mobilis::DSL.build("documents") do
        rack("api") do |service|
          service.embedded_archive("sources", payload: #{payload.dump})
        end
      end
    RUBY
  end
  let(:analysis) { Mobilis::Browser::SourceDocument.new(source).analyze }
  subject(:documents) { described_class.new(analysis) }

  it "projects source, archive, and stable member identities without copying authority" do
    archive = documents.archives.fetch(0)
    members = documents.members(archive.id)

    expect(documents.documents.fetch(0)).to have_attributes(
      id: "ruby-source", kind: :source, parent_id: nil, editable: true, dirty: false
    )
    expect(archive).to have_attributes(
      kind: :archive, parent_id: "ruby-source", editable: false, parent_revision: analysis.archives.fetch(0).parent_revision
    )
    expect(members.map(&:path)).to eq(["README.md", "assets/icon.bin"])
    expect(members.first).to have_attributes(kind: :member, editable: true, content_type: "text/plain; charset=utf-8")
    expect(members.last).to have_attributes(editable: false, content_type: "application/octet-stream")
    expect(described_class.new(analysis).members(archive.id).map(&:id)).to eq(members.map(&:id))
  end
end
