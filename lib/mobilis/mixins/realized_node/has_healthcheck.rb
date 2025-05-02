# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      module HasHealthCheck
        def set_healthcheck_command(command, interval: "10s", timeout: "5s", retries: 5, start_period: "5s")
          compose_healthcheck[:test] = ["CMD-SHELL", command]
          compose_healthcheck[:interval] = interval
          compose_healthcheck[:timeout] = timeout
          compose_healthcheck[:retries] = retries
          compose_healthcheck[:start_period] = start_period
        end

        def compose_healthcheck
          return @compose_healthcheck if defined?(@compose_healthcheck)

          @compose_healthcheck = AutoVivify.new
        end

        def has_healthcheck?
          compose_healthcheck.materialized?(:test)
        end
      end
    end
  end
end
