# frozen_string_literal: true

require "pastel"

module Mobilis
  module PrettyPrint
    module DSL
      def ppx(pp, &block)
        is_highlander = Thread.current[:ppx_highlander].nil?
        if is_highlander
          Thread.current[:ppx_highlander] = :there_can_be_only_one
          Thread.current[:ppx_depth] = 0
        end
        context = Context.new(pp, self)
        context.instance_eval(&block)
      rescue StandardError => e
        warn "[ppx] pretty_print failed for #{obj.class}: #{e.message}"
        warn e.backtrace.first(6).join("\n")
        raise
      ensure
        if is_highlander
          Thread.current[:ppx_depth] = nil
          Thread.current[:ppx_highlander] = nil
        end
      end

      class Context
        attr_reader :pp, :indent_level, :pastel, :target

        def initialize(pp, target)
          @pp = pp
          @indent_level = Thread.current[:ppx_depth]
          @target = target
          @pastel = ::Pastel.new(enabled: ENV["DISABLE_COLOR_OUTPUT"] != "1")
        end

        def object
          target
        end

        def heading(text)
          return emit_single_line_summary if distant_relative?

          pp.text(indent + pastel.bold.blue(text.to_s))
          pp.breakable
        end

        def line(label, value)
          return if distant_relative?

          pp.breakable
          pp.text(sub_indent + pastel.cyan("#{label}: ") + value.to_s)
        end

        def row(*columns, note: nil)
          return if distant_relative?

          columns = columns.map(&:to_s)
          width = columns.map(&:length).max
          padded = columns.map { |c| c.ljust(width) }.join(pastel.white(" | "))
          padded += "  #{pastel.dim("# #{note}")}" if note
          pp.breakable
          pp.text(sub_indent + padded)
        end

        def section(label, items)
          return if distant_relative?

          pp.text(indent + pastel.magenta("#{label}:"))
          items.each do |item|
            item.pretty_print(pp) # Each item will run its own DSL with shared pp
          end
        end

        private

        def indent
          " " * indent_level * 2
        end

        def sub_indent
          "  #{indent}"
        end

        def emit_single_line_summary
          puts "hi, it was #{indent_level}"
          pp.text(single_line_target_representation)
        end

        def top_level?
          indent_level.zero?
        end

        def direct_child?
          indent_level == 1
        end

        def distant_relative?
          !(top_level? || direct_child?)
        end

        def name_of_named_target
          return nil unless target.respond_to? :name

          target.name
        end

        def single_line_target_representation
          "<#{target.class} #{target_memory_address} #{name_of_named_target}>"
        end

        def target_memory_address
          "0x#{(target.object_id << 1).to_s(16)}"
        end
      end
    end
  end
end
