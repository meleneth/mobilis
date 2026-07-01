# frozen_string_literal: true

require "tmpdir"

RSpec.describe Mobilis::ServiceWriter::Rails do
  it "normalizes generated Rails runtime files to the central Ruby image" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write(".ruby-version", "ruby-3.2.2\n")
        File.write("Gemfile", %(source "https://rubygems.org"\nruby "3.2.2"\n))
        FileUtils.mkdir_p("bin")
        File.write("bin/docker-entrypoint", "#!/bin/bash -e\n")
        File.write("Dockerfile", <<~DOCKERFILE)
          ARG RUBY_VERSION=3.2.2
          FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base
          ENV BUNDLE_PATH="/usr/local/bundle"
          COPY Gemfile Gemfile.lock ./
        DOCKERFILE

        described_class.allocate.normalize_rails_runtime

        expect(File.read(".ruby-version")).to eq("ruby-4.0.2\n")
        expect(File.read("Gemfile")).to include(%(ruby "4.0.2"))
        dockerfile = File.read("Dockerfile")
        expect(dockerfile).to include("FROM ruby:4.0.2-trixie as base")
        expect(dockerfile).to include('RUN mkdir -p "${BUNDLE_PATH}" && chmod -R 777 "${BUNDLE_PATH}"')
        expect(File.read("bin/docker-entrypoint")).to include("for attempt in 1 2 3 4 5")
      end
    end
  end
end
