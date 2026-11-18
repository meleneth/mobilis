# frozen_string_literal: true

RSpec.describe "playground static server" do
  subject(:configuration) do
    File.read(File.expand_path("../../../playground/nginx.conf", __dir__))
  end

  it "allows the evaluation required by ruby.wasm and its JS bridge" do
    expect(configuration).to include("script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'")
  end

  it "allows Mermaid's generated SVG styles" do
    expect(configuration).to include("style-src 'self' 'unsafe-inline'")
  end

  it "serves WebAssembly with its registered MIME type" do
    expect(configuration).to include("application/wasm wasm")
  end

  it "serves Mermaid ES modules with a JavaScript MIME type" do
    expect(configuration).to include("application/javascript mjs")
  end
end
