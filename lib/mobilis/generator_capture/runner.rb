# frozen_string_literal: true

require "fileutils"
require "find"
require "json"
require "open3"
require "tmpdir"

module Mobilis
  module GeneratorCapture
    class Runner
      def run(definition)
        definition.validate!
        previous_umask = File.umask(0o022)
        begin
          Dir.mktmpdir("mobilis-generator-capture") do |temporary_root|
            workspace = File.join(temporary_root, "workspace")
            fixture_path = definition.fixture_path or raise ArgumentError, "Generator capture fixture path is missing"
            copy_fixture(fixture_path, workspace)
            before = Snapshot.capture(workspace)
            command = definition.command_parts.map { |part| expand(part, definition, workspace) }
            environment = definition.environment_variables.transform_values do |value|
              expand(value, definition, workspace)
            end
            stdout, stderr, status = Open3.capture3(
              environment,
              *command,
              *definition.argument_list,
              chdir: workspace
            )
            after = Snapshot.capture(workspace)

            build_record(definition, before, after, status, stdout, stderr, workspace)
          end
        ensure
          File.umask(previous_umask)
        end
      end

      def write(record, path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#{JSON.pretty_generate(record)}\n")
      end

      private

      def copy_fixture(source, destination)
        FileUtils.mkdir_p(destination)
        FileUtils.cp_r(Dir.children(source).map { |entry| File.join(source, entry) }, destination)
        Find.find(destination) do |path|
          next if File.symlink?(path)

          mode = File.directory?(path) || File.executable?(path) ? 0o755 : 0o644
          File.chmod(mode, path)
        end
      end

      def normalize_output(output, workspace)
        output.gsub(workspace, Definition::WORKSPACE_TOKEN)
          .gsub(%r{#{Regexp.escape(Dir.tmpdir)}/[^/\s]+}, "{temporary}")
          .gsub("\r\n", "\n")
      end

      def expand(value, definition, workspace)
        value.gsub(Definition::WORKSPACE_TOKEN, workspace)
          .gsub(Definition::REPOSITORY_TOKEN, definition.repository_path.to_s)
      end

      def build_record(definition, before, after, status, stdout, stderr, workspace)
        {
          "format_version" => 1,
          "capture" => definition.name,
          "generator" => {
            "identity" => definition.generator_name,
            "version" => definition.generator_version
          },
          "runtime" => definition.runtime_metadata,
          "invocation" => {
            "command" => definition.command_parts + definition.argument_list,
            "arguments" => definition.argument_list,
            "environment" => definition.environment_variables
          },
          "fixture" => {
            "identity" => definition.fixture_name,
            "sha256" => before.fingerprint,
            "files" => before.entries
          },
          "result" => {
            "success" => status.success?,
            "exit_status" => status.exitstatus,
            "stdout" => normalize_output(stdout, workspace),
            "stderr" => normalize_output(stderr, workspace),
            "delta" => before.delta_to(after)
          }
        }
      end
    end
  end
end
