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

  it "permits only the pinned production CDN used by the runtime configuration" do
    expect(configuration).to include("connect-src 'self' https://cdn.jsdelivr.net")
  end

  it "does not cache mutable manifests and caches content-addressed application archives" do
    expect(configuration).to include("location = /runtime-config.json")
    expect(configuration).to include("location = /mobilis-app-manifest.json")
    expect(configuration.scan('add_header Cache-Control "no-store"')).to have_attributes(length: 2)
    expect(configuration).to include('location ~* "^/mobilis-app-[a-f0-9]{64}\\.tar$"')
    expect(configuration).to include("application/x-tar tar")
    expect(configuration).to include("gzip_types application/javascript application/json application/wasm application/x-tar text/css")
  end

  it "serves Mermaid ES modules with a JavaScript MIME type" do
    expect(configuration).to include("application/javascript mjs")
  end
end
