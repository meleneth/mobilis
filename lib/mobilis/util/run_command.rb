# frozen_string_literal: true

require "open3"

module Mobilis
  module Util
    class CommandFailed < StandardError
      attr_reader :cmd, :status

      def initialize(cmd, status)
        @cmd = cmd
        @status = status
        super("Command failed (#{status.exitstatus}): #{cmd.join(" ")}")
      end
    end

    def self.run_command(cmd, chdir: nil, env: {}, allow_failure: false, capture: false)
      cmd = normalize_command(cmd)
      full_env = ENV.to_h.merge(env)

      result = ""
      status = nil
      Dir.chdir(chdir || Dir.pwd) do
        if capture
          result, status = Open3.capture2e(full_env, *cmd)
        else
          puts " 𝕸 > Running Command: #{cmd.join(" ")}"
          system(full_env, *cmd)
          status = $?
        end
      end

      process_status = ensure_status(status, cmd)
      raise CommandFailed.new(cmd, process_status) unless allow_failure || process_status.success?

      capture ? result : true
    end

    def self.normalize_command(cmd)
      return cmd unless windows?
      return cmd unless cmd.first&.start_with?("./dc_")

      ["bash", *cmd]
    end

    def self.windows?
      Gem.win_platform?
    end

    def self.ensure_status(status, cmd)
      status or raise "No process status returned for #{cmd.join(" ")}"
    end
  end
end
