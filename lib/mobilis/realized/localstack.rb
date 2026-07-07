# frozen_string_literal: true

module Mobilis
  module Realized
    class Localstack < Mobilis::Base::ImageForm
      include Mobilis::PrettyPrint::PrettyPrintable

      def initialize(env, config_node)
        super(env, config_node, Mobilis::ContainerVersions::LOCALSTACK)

        @has_service_dir = true
        register_external_port(exposed_port_no, "#{name}_WEB_PORT",
                               "#{name} web interface port")
      end

      def exposed_port_no
        4566
      end

      def service_writer
        Mobilis::ServiceWriter::Localstack
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "environment", environment
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.child_object "config_node", config_node
        extra_depends_on.each do |dependency|
          target = dependency[:target]
          next unless target.is_a?(Mobilis::Base::Node) || target.is_a?(Mobilis::Base::RealizedNode)

          dsl.child_object "Extra depends_on #{target.name}", target
        end
        dsl.env_vars all_emit_vars
      end
    end
  end
end
