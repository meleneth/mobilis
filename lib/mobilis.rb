# frozen_string_literal: true

require "awesome_print"
require "forwardable"
require "table_print"

require "mel/scene-fsm"

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
require_relative "mobilis/interactive_designer/add_project_menu"
