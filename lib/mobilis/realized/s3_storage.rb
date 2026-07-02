# frozen_string_literal: true

module Mobilis
  module Realized
    class S3Storage < Mobilis::Base::ImageForm
      S3_PORT = 8333
      FILER_PORT = 8888
      MASTER_PORT = 9333
      METRICS_PORT = 9327
      VOLUME_PORT = 8080
      REGION = "us-east-1"

      attr_reader :endpoint_url_env_var, :access_key_env_var, :secret_key_env_var,
                  :region_env_var, :bucket_env_var

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::SEAWEEDFS)

        @has_data_volume = true
        @has_service_dir = true
        @has_dockerfile = false

        @endpoint_url_env_var = add_env_only_var("#{name}_s3_endpoint_url", endpoint_url)
        @access_key_env_var = add_env_only_var("#{name}_s3_access_key_id", access_key_id)
        @secret_key_env_var = add_env_only_var("#{name}_s3_secret_access_key", secret_access_key)
        @region_env_var = add_env_only_var("#{name}_s3_region", REGION)
        @bucket_env_var = add_env_only_var("#{name}_s3_bucket", default_bucket) if default_bucket

        register_external_port(S3_PORT, "#{name}_S3_PORT", "#{name} S3 API port")
        add_volume(data_volume_env_var.env_var_ref, "/data")
        add_volume("./#{name}/entrypoint.sh", "/usr/local/bin/mobilis-seaweedfs-entrypoint.sh")
        compose[:entrypoint] << "/bin/sh"
        compose[:entrypoint] << "/usr/local/bin/mobilis-seaweedfs-entrypoint.sh"
        set_healthcheck_command("wget -qO- http://127.0.0.1:#{MASTER_PORT}/cluster/status >/dev/null")
      end

      def exposed_port_no
        S3_PORT
      end

      def endpoint_url
        "http://#{name}:#{S3_PORT}"
      end

      def buckets
        config_node.buckets
      end

      def default_bucket
        config_node.default_bucket
      end

      def access_key_id
        "#{name}-#{environment}-access-key"
      end

      def observability_enabled?
        config_node.extra_depends_on.any? do |dependency|
          [
            Mobilis::Node::Alloy,
            Mobilis::Node::Prometheus
          ].any? { |klass| dependency[:target].is_a?(klass) }
        end
      end

      def secret_access_key
        "#{name}-#{environment}-secret-key"
      end

      def data_volume_env_var
        @data_volume_env_var ||= add_env_only_var("#{name}_seaweedfs_data", "./data/#{environment}/#{config_node.name}")
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::S3Storage
      end
    end
  end
end
