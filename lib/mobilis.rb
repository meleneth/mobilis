# frozen_string_literal: true

module Mobilis
  module InteractiveDesigner
  end
  class Error < StandardError; end
end

require_relative "mobilis/version"
require_relative "mobilis/command_line"
require_relative "mobilis/project"
require_relative "mobilis/docker_compose_projector"
require_relative "mobilis/interactive_designer/rails_app_edit"
require_relative "mobilis/interactive_designer/rails_model_edit"
require_relative "mobilis/interactive_designer/main_menu"
