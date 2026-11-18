# frozen_string_literal: true

module Mobilis
  module Browser
    class SourceHistory
      Entry = Data.define(:before, :after, :label)

      attr_reader :undo_entries, :redo_entries

      def initialize
        @undo_entries = []
        @redo_entries = []
      end

      def record(before, after, label:)
        return if before == after

        undo_entries << Entry.new(before:, after:, label:)
        redo_entries.clear
      end

      def reset
        undo_entries.clear
        redo_entries.clear
      end

      def undo(current)
        entry = undo_entries.last
        raise ArgumentError, "There is no structured edit to undo" unless entry
        raise ArgumentError, "Ruby source changed after #{entry.label}; refusing to overwrite it" unless current == entry.after

        undo_entries.pop
        redo_entries << entry
        entry.before
      end

      def redo(current)
        entry = redo_entries.last
        raise ArgumentError, "There is no structured edit to redo" unless entry
        raise ArgumentError, "Ruby source changed after undo; refusing to overwrite it" unless current == entry.before

        redo_entries.pop
        undo_entries << entry
        entry.after
      end

      def undo? = !undo_entries.empty?
      def redo? = !redo_entries.empty?
      def undo_label = undo_entries.last&.label
      def redo_label = redo_entries.last&.label
    end
  end
end
