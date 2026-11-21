# frozen_string_literal: true

module Diesl
  # Structured edit history, separate from native text editor keystroke history.
  class History
    Entry = Struct.new(:before, :after, :label, keyword_init: true)

    attr_reader :undo_entries, :redo_entries

    def initialize
      @undo_entries = []
      @redo_entries = []
    end

    def record(before, after, label:)
      return false if before == after

      undo_entries << Entry.new(before:, after:, label:)
      redo_entries.clear
      true
    end

    def undo(current)
      entry = undo_entries.last
      raise Conflict, "No structured edit to undo" unless entry
      raise Conflict, "Source changed after #{entry.label}" unless current == entry.after

      undo_entries.pop
      redo_entries << entry
      entry.before
    end

    def redo(current)
      entry = redo_entries.last
      raise Conflict, "No structured edit to redo" unless entry
      raise Conflict, "Source changed after undo" unless current == entry.before

      redo_entries.pop
      undo_entries << entry
      entry.after
    end

    def reset
      undo_entries.clear
      redo_entries.clear
    end
  end
end
