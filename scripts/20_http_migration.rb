#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../examples/http_migration/system"

system = HTTPMigrationDemo.system(
  mirror_percent: Integer(ENV.fetch("MIRROR_PERCENT", "100")),
  candidate_percent: Integer(ENV.fetch("CANDIDATE_PERCENT", "0"))
)

if ARGV.first == "--render"
  # Safe artifact-only demo: uses normal writers/Compose emitters; no materialize,
  # deletion, git initialization, image build or running containers.
  require "fileutils"
  root = File.expand_path(ARGV.fetch(1))
  FileUtils.mkdir_p(root)
  manifest = Mobilis::Manifest.new(system)
  env = manifest.realized_env(:test)
  Dir.chdir(root) do
    env.each_node do |node|
      if node.has_service_dir
        FileUtils.mkdir_p(node.name)
        Dir.chdir(node.name) { node.service_writer.new(manifest, env, node).write }
      end
    end
    manifest.realized_envs.each do |realized_env|
      services = realized_env.realized_nodes.each_with_object({}) do |node, result|
        result.merge!(node.service_wrapped_compose[:services])
      end
      Mobilis::YAMLWriter.write_yaml("#{realized_env}-compose.yml", {name: "mobilis-http-migration-#{realized_env}", services: services})
      vars = realized_env.all_envfile_vars.to_h { |var| [var.envfile_name, var.value] }
      File.write("#{realized_env}.env", vars.sort.map { |key, value| "#{key}=#{value}" }.join("\n") + "\n")
    end
    File.write("mobilis-system.json", system.to_json)
  end
  puts root
else
  Mobilis::Manifest.new(system).materialize
end
