# frozen_string_literal: true

module Mobilis
  # Keep Ruby Data's immutable value semantics. Defining the singleton factory
  # methods outside the Data.define block also avoids a Steep 1.10.0 crash
  # (Unexpected self_type: untyped while synthesizing the Data class block).
  GeneratorCapabilities = Data.define(:browser_generation, :local_generation, :reason)

  class << GeneratorCapabilities
    def browser
      new(browser_generation: true, local_generation: true, reason: nil)
    end

    def local_only(reason)
      new(browser_generation: false, local_generation: true, reason:)
    end
  end
end
