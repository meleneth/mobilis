# frozen_string_literal: true

module Mobilis
  module Realized
    class SQLDatabase < Mobilis::Base::ImageForm
      attr_reader :db_port_map

      def initialize(realized_env, config_node, image)
        super(realized_env, config_node, image)

        @has_data_volume = true
        @has_service_dir = false
      end

      def user
        "#{name}-#{environment}-user"
      end

      def password
        "#{name}-#{environment}-password"
      end

      def db_name
        "#{name}_#{environment}"
      end

      def url
        "#{scheme}://#{user}:#{password}@#{name}:#{internal_port_no}/#{db_name}"
      end

      def dependant_services_require_restart?
        true
      end

      # Subclasses must define this to provide the URL scheme (e.g., "postgres", "mysql2")
      def scheme
        raise NotImplementedError, "#{self.class} must implement #scheme"
      end
    end
  end
end
