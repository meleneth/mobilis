# frozen_string_literal: true

require "bundler"

RSpec.describe "playground Ruby WASM runtime container" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:runtime_dockerfile) { File.read(File.join(root, "Dockerfile.playground-runtime")) }
  let(:application_dockerfile) { File.read(File.join(root, "Dockerfile.playground")) }
  let(:runtime_lock) { Bundler::LockfileParser.new(File.read(File.join(root, "native_wasm/Gemfile.lock"))) }

  it "keeps compilation in the dedicated runtime image" do
    expect(runtime_dockerfile).to include("native_wasm/bin/build build")
    expect(runtime_dockerfile).to include("type=cache,id=mobilis-native-wasm-build-v5-json-single-ext")
    expect(application_dockerfile).not_to include("rbwasm build")
    expect(application_dockerfile).to include("COPY --from=ruby_runtime /runtime/ruby+stdlib.wasm")
  end

  it "pins the native-extension dependency boundary" do
    versions = runtime_lock.specs.to_h { |specification| [specification.name, specification.version.to_s] }

    expect(versions).to include(
      "bigdecimal" => "4.1.3",
      "js" => "2.10.1",
      "nokogiri" => "1.19.7",
      "railties" => "8.1.4.1",
      "ruby_wasm" => "2.10.1"
    )
  end

  it "uses Debian Trixie throughout the playground container build" do
    expect(runtime_dockerfile).to include("FROM ruby:4.0.10-trixie AS build")
    expect(application_dockerfile).to include("FROM node:22.23.5-trixie AS node")
    expect(application_dockerfile).to include("FROM ruby:4.0.10-trixie AS build")
    expect(application_dockerfile).to include("FROM nginx:1.30.6-trixie")
    expect(runtime_dockerfile).not_to include("bookworm")
    expect(application_dockerfile).not_to include("bookworm")
  end

  it "excludes local compiler trees from Docker build contexts" do
    dockerignore = File.read(File.join(root, ".dockerignore"))

    expect(dockerignore).to include("playground/build")
    expect(dockerignore).to include("playground/rubies")
  end
end
