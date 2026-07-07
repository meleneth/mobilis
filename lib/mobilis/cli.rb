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
      filename = @argv.shift
      Optimist.die("You must provide a valid path to a system.json file") unless filename && File.exist?(filename)

      system = Mobilis::System.from_json(File.read(filename))
      puts "[mobilis] loaded system from #{filename} with #{system.node_count} nodes"
      Mobilis::Manifest.new(system).materialize
    end

    def usage
      <<~USAGE
        Usage:
          mobilis generate <system.json>
      USAGE
    end
  end
end
