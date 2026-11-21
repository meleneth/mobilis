# frozen_string_literal: true

require_relative "../../../playground/app/projection_invalidator"

RSpec.describe MobilisPlayground::ProjectionInvalidator do
  subject(:invalidator) { described_class.new }

  it "renders all dependent regions once for an accepted source edit" do
    expect(invalidator.affected(:source, :system, :validation)).to eq([
      ["editor-region", :render_editor],
      ["builder-region", :render_builder],
      ["inspector-region", :render_inspector],
      ["architecture-region", :render_architecture],
      ["diagnostics-region", :render_diagnostics]
    ])
  end

  it "preserves the last valid inspector when source validation fails" do
    expect(invalidator.affected(:validation)).to eq([
      ["architecture-region", :render_architecture],
      ["diagnostics-region", :render_diagnostics]
    ])
  end

  it "deduplicates multiple changed inputs within one transaction" do
    expect(invalidator.affected(:generated_files, :selected_file, :generation)).to eq([
      ["diagnostics-region", :render_diagnostics],
      ["files-region", :render_files],
      ["file-content-region", :render_file_content]
    ])
  end

  it "rejects undeclared dependencies without silent fallback" do
    expect(invalidator.affected).to eq([])
    expect { invalidator.affected(:sytem) }.to raise_error(ArgumentError, /sytem/)
  end
end
