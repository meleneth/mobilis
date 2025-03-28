module Mobilis
  module OutputFiles
    class PostgreSQLService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "postgres:16.2-bookworm",
          "user" => "${RUNASUSER}",
          "restart" => "always",
          "environment" => project.env_vars,
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "${#{project.env_name}_POSTGRES_DATA}:/var/lib/postgresql/data"
          ]
        }
      end
    end
  end
end
