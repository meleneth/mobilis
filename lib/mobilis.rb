# frozen_string_literal: true

require "awesome_print"
require "forwardable"
require "table_print"
require "fileutils"
require "json"
require "yaml"

require "mel/scene-fsm"

module Mobilis
  module InteractiveDesigner
  end

  class Error < StandardError; end
end

require_relative "mobilis/version"
require_relative "mobilis/logger"

require_relative "mobilis/actions_projects_take"
require_relative "mobilis/new_relic"
require_relative "mobilis/scene_fsm"
require_relative "mobilis/rails_model_type"
require_relative "mobilis/file_lines"

require_relative "mobilis/services/directory"

require_relative "mobilis/port_assigner"

require_relative "mobilis/project"
require_relative "mobilis/project/generic_project"
require_relative "mobilis/project/localgem_project"
require_relative "mobilis/project/redis_instance"
require_relative "mobilis/project/kafka_instance"
require_relative "mobilis/project/mysql_instance"
require_relative "mobilis/project/postgresql_instance"
require_relative "mobilis/project/rack_project"
require_relative "mobilis/project/rails_model"
require_relative "mobilis/project/rails_project"
require_relative "mobilis/project/rails_field"

require_relative "mobilis/command_line"
require_relative "mobilis/os"

require_relative "mobilis/docker_compose_projector"
require_relative "mobilis/interactive_designer/add_project_menu"
require_relative "mobilis/interactive_designer/fsm_designer"
require_relative "mobilis/interactive_designer/link_editor"
require_relative "mobilis/interactive_designer/rack_app_designer"
require_relative "mobilis/interactive_designer/project_edit_menu"
require_relative "mobilis/interactive_designer/rails_project_edit"
require_relative "mobilis/interactive_designer/kafka_edit"
require_relative "mobilis/interactive_designer/rails_model_edit"

require_relative "mobilis/interactive_designer/main_menu"
