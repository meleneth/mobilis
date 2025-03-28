# frozen_string_literal: true

module Mobilis
  module OutputFiles
    class ComposeBase < Mobilis::OutputFile
      attr_reader :environment, :metaproject

      def initialize(environment, metaproject)
        super("compose-#{environment}.yml")
        @environment = environment
        @metaproject = metaproject
      end

      def render
        includes = [] # : Array[Hash[String, String]]
        metaproject.each_project_for_environment(@environment) do |project|
          next unless project.is_service_project?

          includes << {
            "path" => "./compose/#{project.name}.yml",
            "project_directory" => "./",
            "env_file" => "./compose/#{environment}.env"
          }
        end

        info = {
          "include" => includes,
          "name" => "#{metaproject.name}-#{environment}"
        }
        YAML.dump(info)
      end
    end
  end
end
