# frozen_string_literal: true

require "awesome_print"
require "forwardable"
require "table_print"
require "fileutils"

require "mel/scene-fsm"

module Mobilis
  module InteractiveDesigner
  end
  class Error < StandardError; end
end

require_relative "mobilis/version"
require_relative "mobilis/logger"

require_relative "mobilis/project"
require_relative "mobilis/project/generic_project"
require_relative "mobilis/project/localgem_project"
require_relative "mobilis/project/redis_instance"
require_relative "mobilis/project/mysql_instance"
require_relative "mobilis/project/postgresql_instance"
require_relative "mobilis/project/rack_project"

require_relative "mobilis/actions_projects_take"
require_relative "mobilis/command_line"
require_relative "mobilis/os"
require_relative "mobilis/new_relic"

require_relative "mobilis/docker_compose_projector"
require_relative "mobilis/interactive_designer/add_project_menu"
require_relative "mobilis/interactive_designer/fsm_designer"
require_relative "mobilis/interactive_designer/link_editor"
require_relative "mobilis/interactive_designer/main_menu"
require_relative "mobilis/interactive_designer/rack_app_designer"
require_relative "mobilis/interactive_designer/rails_app_edit"
require_relative "mobilis/interactive_designer/rails_model_edit"
