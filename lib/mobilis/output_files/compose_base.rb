# frozen_string_literal: true

module Mobilis
  module OutputFiles
    class ComposeBase < Mobilis::OutputFile
      attr_reader :environment, :project_config

      def initialize(environment, project_config)
        super("compose-#{environment}.yml")
        @environment = environment
        @project_config = project_config
      end

      def render
        includes = []
        project_config.projects.each do |project|
          next unless project.is_service_project

          includes << {
            "path" => "./compose/#{project.name}.yml",
            "project_directory" => "./",
            "env_file" => "./compose/#{environment}.env"
          }
        end
        info = {
          "include" => includes,
          "name" => "#{project_config.name}-#{environment}"
        }
        YAML.dump(info)
      end
    end
  end
end
