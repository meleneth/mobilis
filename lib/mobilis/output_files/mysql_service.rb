module Mobilis
  module OutputFiles
    class MySQLService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "mysql:debian",
          "restart" => "always",
          "environment" => service.env_vars,
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "${#{service.env_name}_MYSQL_DATA}:/var/lib/mysql"
          ]
        }
      end
    end
  end
end
