module Mobilis
  module NewRelic
    def new_relic(&block)
      block.call(self)
    end

    def set_license_key(license_key)
      @new_relic_license_key = license_key
    end

    def enable_distributed_tracing
      @new_relic_destributed_tracing = true
    end
  end
end
