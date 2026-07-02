# frozen_string_literal: true

require "fileutils"
require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Rack do
  let(:rack_node) do
    build(:rack_node, name: "gameservice").tap do |node|
      node.add_gem("redis")
      node.local_gem("mel-mnbme", require_name: "mel/mnbme") do |gem|
        gem.write_file("mel-mnbme.gemspec", "Gem::Specification.new { |s| s.name = 'mel-mnbme'; s.version = '0.1.0'; s.summary = 'demo'; s.authors = ['demo']; s.files = Dir['lib/**/*']; s.require_paths = ['lib'] }\n")
        gem.write_file("lib/mel/mnbme.rb", "# frozen_string_literal: true\n")
      end
      node.write_file("config.ru", "run proc { [200, {}, ['ok']] }\n")
    end
  end
  let(:system) { build(:system, nodes: [rack_node]) }
  let(:manifest) { build(:manifest, system: system, suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("gameservice") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "writes a Rack service with local gem files and a modern Ruby image" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/gameservice")
      Dir.chdir("#{dir}/gameservice") do
        writer.write
      end

      expect(File.read("#{dir}/gameservice/Dockerfile")).to include("FROM ruby:4.0.2-trixie")
      expect(File.read("#{dir}/gameservice/Gemfile")).to include('gem "mel-mnbme", path: "../localgems/mel-mnbme", require: "mel/mnbme"')
      expect(File.read("#{dir}/gameservice/Gemfile")).to include('gem "puma", "~> 7.1"')
      expect(File).to exist("#{dir}/localgems/mel-mnbme/lib/mel/mnbme.rb")
    end
  end

  it "writes OTEL startup wiring when connected to an otel collector" do
    collector = build(:otel_collector_node, name: "otel-collector")
    rack_node.has_extra_depends_on(collector)
    system << collector

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/gameservice")
      Dir.chdir("#{dir}/gameservice") do
        writer.write
      end

      expect(File.read("#{dir}/gameservice/Gemfile")).to include('gem "opentelemetry-exporter-otlp"')
      expect(File.read("#{dir}/gameservice/config/otel.rb")).to include("OpenTelemetry::Exporter::OTLP::Exporter")
      expect(File.read("#{dir}/gameservice/Dockerfile")).to include("-r./config/otel")
    end
  end
end
