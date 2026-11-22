# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mobilis generation execution parity" do
  # Drive the native execution adapter without Docker/Git side effects.
  # This exercises exactly the same ordered Manifest plan as production,
  # capturing each native commit boundary for comparison with browser deltas.
  class RecordingNative < Mobilis::Generation::Native
    attr_reader :commits

    def initialize(manifest)
      super
      @commits = []
    end

    def prepare_repository
      # Git object creation is separately covered by the native CLI and
      # browser Git integration tests; this test compares plan semantics.
    end

    def after_helpers
      manifest.run_plugin_hooks(:hook_after_dc_helpers)
    end

    def commit(message)
      root = manifest.directory_service.generate_root
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
        .reject { |path| path == "." || path == ".." || File.directory?(File.join(root, path)) }
        .sort.to_h { |path| [path, File.binread(File.join(root, path))] }
      @commits << {message: "[mobilis] #{message}", files:}
    end
  end

  def read_files(root)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
      .reject { |path| path == "." || path == ".." || File.directory?(File.join(root, path)) }
      .sort.to_h { |path| [path, File.binread(File.join(root, path))] }
  end

  it "produces identical content and commit boundaries for native and browser executors" do
    Dir.mktmpdir do |directory|
      build_system = lambda do
        Mobilis::DSL.build("parity-stack", starting_port: 11_000) do
          postgres("database")
          redis("cache")
          connect(from: "cache", to: "database")
        end
      end

      browser = Mobilis::Browser::Generator.new(workspace: File.join(directory, "browser")).call(build_system.call)
      native_dir = File.join(directory, "native")
      FileUtils.mkdir_p(native_dir)
      # Manifest plugin expansion can mutate realized state. Use independent
      # declarations for both executions, like real separate CLI/browser runs.
      manifest = Mobilis::Manifest.new(build_system.call, directory_service: Mobilis::Services::Directory.new(native_dir))
      execution = RecordingNative.new(manifest)
      caller_directory = Dir.pwd
      begin
        root = manifest.run_generation(execution)
      ensure
        Dir.chdir(caller_directory)
      end

      expect(read_files(root)).to eq(browser.files)
      # Browser emits only nonempty commits. Each native phase with changed
      # files must be represented at the same point with the same full tree.
      last_files = {}
      native_phases = execution.commits.filter_map do |checkpoint|
        files = checkpoint.fetch(:files)
        next if files == last_files

        last_files = files
        checkpoint
      end
      browser_files = {}
      browser_phases = browser.steps.map do |checkpoint|
        checkpoint.fetch(:deletes).each { |name| browser_files.delete(name) }
        browser_files.merge!(checkpoint.fetch(:writes))
        {message: checkpoint.fetch(:message), files: browser_files.dup}
      end
      expect(browser_phases).to eq(native_phases)
      expect(browser_phases.first.fetch(:message)).to eq("[mobilis] Basic project files")
      expect(browser_phases.map { |phase| phase.fetch(:message) })
        .to include("[mobilis] compose wrappers", "[mobilis] Compose overrides", "[mobilis] Mobilis system config")
    end
  end
end
