module Mobilis
  module OutputFiles
    class RailsService < Mobilis::SingleServiceOutputFile
      def service_data
        vars = [] # : Array[String]
        vars << "RAILS_ENV=production"
        vars << "RAILS_MASTER_KEY=#{service.rails_master_key}"
        vars << "RAILS_MIN_THREADS=5"
        vars << "RAILS_MAX_THREADS=5"

        database = service.database
        vars << "DATABASE_URL=${#{service.env_name}_DATABASE_URL}" if database

        # vars << "NEW_RELIC_APP_NAME=#{ service.name }"
        # vars << "NEW_RELIC_LICENSE_KEY=#{ attributes[:new_relic_license_key] }"
        # vars << "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true"
        {
          "image" => service.docker_image_name,
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "environment" => vars,
          "build" => {
            "context" => "./#{service.name}"
          }
        }
      end
    end
  end
end
