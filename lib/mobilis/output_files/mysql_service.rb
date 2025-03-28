module Mobilis
  module OutputFiles
    class MySQLService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "mysql:debian",
          "restart" => "always",
          "environment" => project.env_vars,
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "${#{project.env_name}_MYSQL_DATA}:/var/lib/mysql"
          ]
        }
      end
    end
  end
end
