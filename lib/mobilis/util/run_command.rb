# frozen_string_literal: true

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
      full_env = ENV.to_h.merge(env)

      result = nil
      status = false
      Dir.chdir(chdir || Dir.pwd) do
        if capture
          output = IO.popen(full_env, cmd, err: %i[child out]) do |io|
            result = io.read
          end
          status = $?
        else
          puts " >-> Running Command: #{cmd.join(" ")}"
          system(full_env, *cmd)
          status = $?
        end
      end

      raise CommandFailed.new(cmd, status) unless allow_failure || status.success?

      capture ? result : true
    end
  end
end
