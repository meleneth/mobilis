# frozen_string_literal: true

module Mobilis
  GeneratorCapabilities = Data.define(:browser_generation, :local_generation, :reason) do
    def self.browser
      new(browser_generation: true, local_generation: true, reason: nil)
    end

    def self.local_only(reason)
      new(browser_generation: false, local_generation: true, reason:)
    end
  end
end
