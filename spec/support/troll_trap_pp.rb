# frozen_string_literal: true

# Troll trap for pretty_print errors:
# Overrides PP.pp to fail loudly if your pretty_print method raises.
# Enable by running with TROLL_HUNT=1

if ENV["TROLL_HUNT"] == "1"
  warn "[TROLL_HUNT] patching PP.pp to raise on pretty_print errors"

  class << PP
    unless method_defined?(:orig_pp)
      alias_method :orig_pp, :pp

      def pp(obj, out = $stdout, width = 79)
        out = PP::SingleLine.new(out, width)
        begin
          obj.pretty_print(out)
          out.flush
        rescue => e
          raise "🔥 pretty_print failed in #{obj.class}: #{e.class} - #{e.message}\n\n#{e.backtrace.join("\n")}"
        end
        obj
      end
    end
  end
end
