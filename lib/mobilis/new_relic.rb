module Mobilis
  module NewRelic
    def new_relic &block
      instance_eval(&block)
    end

    def set_license_key license_key
      @new_relic_license_key = license_key
    end

    def enable_distributed_tracing
      @new_relic_destributed_tracing = true
    end
  end
end
