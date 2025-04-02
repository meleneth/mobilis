# frozen_string_literal: true

require "optimist"
require "mobilis"

module Mobilis
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      cmd = @argv.shift
      case cmd
      when "generate"
        generate
      else
        abort usage
      end
    end

    def generate
      opts = Optimist.options(@argv) do
        banner "Usage: mobilis generate <system.json>\n\n"
        stop_on_unknown
      end

      filename = @argv.shift
      Optimist.die("You must provide a valid path to a system.json file") unless filename && File.exist?(filename)

      system = Mobilis::System.from_json(File.read(filename))
      # Replace with actual emit logic as it comes online
      puts "[mobilis] loaded system from #{filename} with #{system.node_count} nodes"
    end

    def usage
      <<~USAGE
        Usage:
          mobilis generate <system.json>
      USAGE
    end
  end
end
