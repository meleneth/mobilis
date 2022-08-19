require "optimist"

module Mobilis
  class CommandLine
    def self.parse_args(args)
      options = {}
      Optimist.options(args) do
        banner "checklist code janitor"
        stop_on ["new", "check", "add"]
      end
      if args.length == 0
        options[:subcommand] = :help
        return options
      end
      options[:subcommand] = args.shift.to_sym
      case options[:subcommand]
      when :new
        Optimist.options(args) do
          stop_on ["gem", "railsapp", "railsapi"]
        end
        options[:new_type] = args.shift.to_sym
        options[:name] = case options[:new_type]
        when :gem
          args.shift
        when :railsapp
          args.shift
        when :railsapi
          args.shift
        end
      when :add
        Optimist.options(args) do
          stop_on ["gem", "docker"]
        end
        options[:add_type] = args.shift.to_sym
        case options[:add_type]
        when :gem
          options[:name] = args.shift
        end
      end
      options
    end
  end
end
