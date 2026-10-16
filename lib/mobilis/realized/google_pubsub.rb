# frozen_string_literal: true

module Mobilis
  module Realized
    class GooglePubSub < Mobilis::Base::ImageForm
      PORT = 8085

      def initialize(env, node)
        super(env, node, "#{env.meta_project_name}/#{node.name}")
        @has_service_dir = true
        @has_dockerfile = true
        set_compose_build_context
        add_compose_raw_var("PUBSUB_PROJECT_ID", node.project_id)
        add_compose_raw_var("PUBSUB_EMULATOR_HOST", "127.0.0.1:#{PORT}")
        if node.publish_port
          register_external_port(PORT, "#{name}_PUBSUB_PORT", "#{name} Pub/Sub emulator host port")
          host_port = envfile_vars.data.last.value
          add_env_only_var("#{name}_pubsub_host_endpoint", "localhost:#{host_port}")
        end
        set_healthcheck_command('test -f /tmp/mobilis-pubsub-ready && python /opt/mobilis/health.py',
                                interval: "5s", timeout: "5s", retries: 20, start_period: "20s")
      end

      def service_writer
        Mobilis::ServiceWriter::GooglePubSub
      end

      def dependant_services_require_restart?
        true
      end
    end
  end
end
