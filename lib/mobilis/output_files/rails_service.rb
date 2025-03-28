module Mobilis
  module OutputFiles
    class RailsService < Mobilis::SingleServiceOutputFile
      def service_data
        vars = [] # : Array[String]
        vars << "RAILS_ENV=production"
        vars << "RAILS_MASTER_KEY=#{project.rails_master_key}"
        vars << "RAILS_MIN_THREADS=5"
        vars << "RAILS_MAX_THREADS=5"

        database = project.database
        vars << "DATABASE_URL=${#{project.env_name}_DATABASE_URL}" if database

        {
          "image" => project.docker_image_name,
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "environment" => vars,
          "build" => {
            "context" => "./#{project.name}"
          }
        }
      end
    end
  end
end
