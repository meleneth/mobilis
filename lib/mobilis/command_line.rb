require "optimist"

module Mobilis
  class CommandLine
    def self.parse_args(args)
      options = {}
      Optimist.options(args) do
        banner "multi-project codebase generation toolkit"
        stop_on ["load", "build", "help"]
      end
      if args == []
        options[:subcommand] = :interactive
        return options
      end
      options[:subcommand] = args.shift.to_sym
      case options[:subcommand]
      when :load
        options[:filename] = args.shift
      when :build
        options[:filename] = args.shift
      when :help
        puts "I think we'd all like a little help."
      else
        Optimist.die "unknown subcommand #{cmd.inspect}"
      end
      options
    end
  end
end
