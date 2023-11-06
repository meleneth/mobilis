# frozen_string_literal: true

require "logger"

module Mobilis
  class << self
    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = "mobilis"
      end
    end
  end
end
