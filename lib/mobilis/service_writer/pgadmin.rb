# frozen_string_literal: true

require "json"

module Mobilis
  module ServiceWriter
    class Pgadmin < Mobilis::Base::ServiceWriter
      def write
        File.write("servers.json", "#{JSON.pretty_generate(servers_json)}\n")
      end

      private

      def servers_json
        {
          "Servers" => realized_node.databases.each_with_index.to_h do |database, index|
            [
              (index + 1).to_s,
              server_definition(database)
            ]
          end
        }
      end

      def server_definition(database)
        {
          "Name" => database.name,
          "Group" => realized_env.to_s,
          "Host" => database.name,
          "Port" => database.internal_port_no,
          "MaintenanceDB" => database.db_name,
          "Username" => database.user,
          "SSLMode" => "prefer",
          "PasswordExecCommand" => "printf '%s' '#{database.password}'"
        }
      end
    end
  end
end
