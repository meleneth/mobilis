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
        expect(dockerfile).to include("FROM ruby:4.0.2-trixie AS base")
        expect(dockerfile).to include('RUN mkdir -p "${BUNDLE_PATH}" && chmod -R 777 "${BUNDLE_PATH}"')
        expect(File.read("bin/docker-entrypoint")).to include("for attempt in 1 2 3 4 5")
      end
    end
  end

  it "writes docker-entrypoint with LF line endings" do
    manifest = build(:manifest, system: build(:system, :with_rails_and_postgres), suppress_plugins: true)
    realized_env = manifest.realized_env(:test)
    realized_node = realized_env.find_realized_node_by_name("user")

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      Dir.chdir(dir) do
        File.write("Gemfile", %(ruby "0.0.0"\n))
        File.write("Dockerfile", <<~DOCKERFILE)
          ARG RUBY_VERSION=0.0.0
          FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base
          COPY Gemfile Gemfile.lock ./
        DOCKERFILE

        described_class.new(manifest, realized_env, realized_node).normalize_rails_runtime
        expect(File.binread("bin/docker-entrypoint")).not_to include("\r\n")
      end
    end
  end

  it "writes a shared local gem and adapts the Dockerfile for the project-root context" do
    first = build(:rails_node, name: "accounts")
    shared_gem = first.local_gem("shared-library", require_name: "shared/library") do |gem|
      gem.write_file("shared-library.gemspec", <<~RUBY)
        Gem::Specification.new do |spec|
          spec.name = "shared-library"
          spec.version = "0.1.0"
          spec.summary = "Shared application code"
          spec.authors = ["Mobilis"]
          spec.files = Dir["lib/**/*"]
          spec.require_paths = ["lib"]
        end
      RUBY
      gem.write_file("lib/shared/library.rb", "module Shared::Library; end\n")
    end
    second = build(:rails_node, name: "billing")
    second.use_local_gem(shared_gem)
    system = build(:system, nodes: [first, second])
    manifest = build(:manifest, system: system, suppress_plugins: true)
    realized_env = manifest.realized_env(:test)

    Dir.mktmpdir do |dir|
      %w[accounts billing].each do |service_name|
        FileUtils.mkdir_p(File.join(dir, service_name, "bin"))
        Dir.chdir(File.join(dir, service_name)) do
          File.write("Gemfile", %(source "https://rubygems.org"\nruby "3.2.2"\n))
          File.write("Gemfile.lock", "")
          File.write("Dockerfile", <<~DOCKERFILE)
            ARG RUBY_VERSION=3.2.2
            FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
            ENV BUNDLE_PATH="/usr/local/bundle"
            COPY vendor/* ./vendor/
            COPY Gemfile Gemfile.lock ./
            COPY . .
            FROM base
            COPY --chown=rails:rails --from=build /rails /rails
          DOCKERFILE

          realized_node = realized_env.find_realized_node_by_name(service_name)
          writer = described_class.new(manifest, realized_env, realized_node)
          writer.write_local_gems
          writer.normalize_rails_runtime
        end
      end

      expect(File.read(File.join(dir, "localgems/shared-library/lib/shared/library.rb"))).to eq(
        "module Shared::Library; end\n"
      )
      %w[accounts billing].each do |service_name|
        dockerfile = File.read(File.join(dir, service_name, "Dockerfile"))
        expect(dockerfile).to include("COPY localgems/shared-library /localgems/shared-library")
        expect(dockerfile).to include("COPY --from=build /localgems/shared-library /localgems/shared-library")
        expect(dockerfile).to include(
          "COPY #{service_name}/Gemfile #{service_name}/Gemfile.lock ./"
        )
        expect(dockerfile).to include("COPY #{service_name}/ .")
        expect(dockerfile).to include("COPY #{service_name}/vendor/* ./vendor/")
        expect(dockerfile).to include("FROM ruby:4.0.2-trixie AS base")
        expect(File.read(File.join(dir, service_name, "Dockerfile.dockerignore"))).to eq(<<~IGNORE)
          **
          !#{service_name}/
          !#{service_name}/**
          !localgems/
          !localgems/shared-library/
          !localgems/shared-library/**
        IGNORE
      end
    end
  end

  it "copies only consumed gems at their declared paths into both Docker stages" do
    node = build(:rails_node, name: "accounts")
    node.local_gem("authorization-context", path: "../gems/authorization-context")
    node.local_gem("shared", path: "../vendor/gems/shared")
    manifest = build(:manifest, system: build(:system, nodes: [node]), suppress_plugins: true)
    env = manifest.realized_env(:test)
    writer = described_class.new(manifest, env, env.find_realized_node_by_name("accounts"))

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/accounts/bin")
      Dir.chdir("#{dir}/accounts") do
        File.write("Gemfile", "")
        File.write("Dockerfile", <<~DOCKERFILE)
          FROM ruby AS base
          FROM base AS build
          COPY Gemfile Gemfile.lock ./
          RUN bundle install
          COPY . .
          FROM base
          COPY --from=build /rails /rails
        DOCKERFILE
        writer.write_local_gems
        writer.normalize_rails_runtime

        dockerfile = File.read("Dockerfile")
        ignore = File.read("Dockerfile.dockerignore")
        %w[gems/authorization-context vendor/gems/shared].each do |path|
          expect(File).to exist("../#{path}/Gemfile")
          expect(dockerfile).to include("COPY #{path} /#{path}")
          expect(dockerfile).to include("COPY --from=build /#{path} /#{path}")
          expect(dockerfile.index("COPY #{path}")).to be < dockerfile.index("RUN bundle install")
          expect(ignore).to include("!#{path}/\n!#{path}/**\n")
        end
        expect(ignore).to include("!vendor/\n!vendor/gems/\n")
        expect(ignore).not_to include("!gems/**", "!vendor/**")
        expect(dockerfile).not_to include("localgems")
      end
    end
  end
end
