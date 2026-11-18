# frozen_string_literal: true

module Mobilis
  module Browser
    class SemanticRuntime
      attr_reader :invocation_count, :total_duration_ms, :last_duration_ms, :last_label

      def initialize
        @invocation_count = 0
        @total_duration_ms = 0.0
        @last_duration_ms = 0.0
        @last_label = nil
      end

      def measure(label)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @invocation_count += 1
        @last_label = label
        yield
      ensure
        if started
          @last_duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
          @total_duration_ms += @last_duration_ms
        end
      end
    end
  end
end
