# frozen_string_literal: true

#
# Mobilis::PrettyPrint::DSL
# Depth-aware JobesWar DSL for structured object visualization
# Supports child-only rendering: top-level and direct children render fully,
# deeper levels emit object summaries.

module Mobilis
  module PrettyPrint
    class DSL
      def self.render(object, parent, &block)
        Thread.current[:ppx_depth] ||= 0
        new(object, parent).instance_eval(&block)
      ensure
        Thread.current[:ppx_depth] = nil if Thread.current[:ppx_depth] == 0
      end

      def initialize(object, parent)
        @object = object
        @parent = parent
      end

      def ruby_class(object = @object, styles: %i[blue bold], &block)
        label = @object.class.name
        box = JobesWar::Node::Box.new(label: label, styles: styles)
        @parent << box

        with_depth(box, object) do
          @object.ppx_fields(self) if @object.respond_to?(:ppx_fields)
          block&.call(self)
        end
      end

      def instance_value(label, value, styles: [:dim])
        return if value.nil?

        @parent << JobesWar::Node::Value.new("#{label}: #{value}", styles: styles)
      end

      def env_vars(vars)
        box = JobesWar::Node::Box.new
        table = JobesWar::Node::TicTac.new

        vars.each do |var|
          row = []
          row << JobesWar::Node::Value.new(var.compose_name, styles: [:green])
          row << JobesWar::Node::Value.new(var.envfile_name, styles: [:blue])
          row << JobesWar::Node::Value.new(truncate_with_ellipsis(var.value), styles: [:yellow])
          table << row
        end

        box << table
        @parent << box
      end

      def plugins(plugins)
        plugins.each do |plugin|
          child_object("plugin", plugin)
        end
      end

      def child_object(label, child)
        return if child.nil?

        if distant_relative?
          summary = child_summary(child)
          instance_value(label, summary)
        else
          sub_box = JobesWar::Node::Box.new(label: label, styles: [:magenta])
          @parent << sub_box
          with_depth(sub_box, child) { child.ppx_box(sub_box) }
        end
      end

      private

      def with_depth(parent_box, object, &block)
        Thread.current[:ppx_depth] += 1
        self.class.new(object, parent_box).instance_eval(&block)
      ensure
        Thread.current[:ppx_depth] -= 1
      end

      def depth
        Thread.current[:ppx_depth] ||= 0
      end

      def top_level?
        depth == 0
      end

      def direct_child?
        depth == 1
      end

      def distant_relative?
        depth >= 2
      end

      def child_summary(obj)
        name = obj.respond_to?(:name) ? obj.name.inspect : nil
        addr = "0x#{(obj.object_id << 1).to_s(16)}"
        "<#{obj.class} #{addr}#{name ? " #{name}" : ""}>"
      end

      def truncate_with_ellipsis(str)
        str = str.to_s
        str.length >= 40 ? str[0...37] + "..." : str
      end
    end
  end
end
