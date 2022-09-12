# frozen_string_literal: true

require_relative "mobilis/version"
require_relative "mobilis/command_line"
require_relative "mobilis/project"
require_relative "mobilis/docker_compose_projector"

module Mobilis
  class Error < StandardError; end
end
