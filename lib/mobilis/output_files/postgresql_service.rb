module Mobilis
  module OutputFiles
    class PostgreSQLService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "postgres:16.2-bookworm",
          "user" => "${RUNASUSER}",
          "restart" => "always",
          "environment" => service.env_vars,
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "${#{service.env_name}_POSTGRES_DATA}:/var/lib/postgresql/data"
          ]
        }
      end
    end
  end
end
