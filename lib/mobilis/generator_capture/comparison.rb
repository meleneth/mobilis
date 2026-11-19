# frozen_string_literal: true

module Mobilis
  module GeneratorCapture
    class Comparison
      def compare(baseline, variant)
        validate_pair!(baseline, variant)
        baseline_delta = index(baseline)
        variant_delta = index(variant)

        {
          "format_version" => 1,
          "generator" => baseline.dig("generator", "identity"),
          "version" => baseline.dig("generator", "version"),
          "baseline_capture" => baseline.fetch("capture"),
          "baseline_arguments" => baseline.dig("invocation", "arguments"),
          "variant_capture" => variant.fetch("capture"),
          "variant_arguments" => variant.dig("invocation", "arguments"),
          "fixture_sha256" => baseline.dig("fixture", "sha256"),
          "only_in_baseline" => difference(baseline_delta, variant_delta),
          "only_in_variant" => difference(variant_delta, baseline_delta),
          "changed_in_both" => changed_in_both(baseline_delta, variant_delta)
        }
      end

      private

      def validate_pair!(baseline, variant)
        %w[generator fixture].each do |key|
          next if baseline.fetch(key) == variant.fetch(key)

          raise ArgumentError, "Cannot compare captures with different #{key} metadata"
        end
        [baseline, variant].each do |record|
          raise ArgumentError, "Cannot compare failed capture #{record.fetch("capture")}" unless record.dig("result", "success")
        end
      end

      def index(record)
        record.dig("result", "delta").to_h { |entry| [entry.fetch("path"), entry] }
      end

      def difference(left, right)
        (left.keys - right.keys).sort.map { |path| summarize(left.fetch(path)) }
      end

      def changed_in_both(left, right)
        (left.keys & right.keys).sort.filter_map do |path|
          next if left.fetch(path) == right.fetch(path)

          {
            "path" => path,
            "baseline" => summarize(left.fetch(path)),
            "variant" => summarize(right.fetch(path))
          }
        end
      end

      def summarize(entry)
        state = entry["after"] || entry["before"]
        {
          "operation" => entry.fetch("operation"),
          "path" => entry.fetch("path"),
          "mode" => state.fetch("mode"),
          "sha256" => state["sha256"]
        }.compact
      end
    end
  end
end
