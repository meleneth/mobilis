# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class S3Storage < Mobilis::Base::ServiceWriter
      def write
        write_executable("entrypoint.sh", entrypoint)
      end

      def entrypoint
        bucket_commands = realized_node.buckets.map do |bucket|
          "printf '%s\\n' #{shell_quote("s3.bucket.create -name #{bucket}")} | weed shell -master=localhost:9333 -filer=localhost:8888 || true"
        end
        metrics_flag = realized_node.observability_enabled? ? " \\\n  -metricsPort=#{Mobilis::Realized::S3Storage::METRICS_PORT}" : ""

        <<~SH
          #!/usr/bin/env sh
          set -eu

          mkdir -p /data

          weed server \\
            -dir=/data \\
            -s3 \\
            -s3.port=#{Mobilis::Realized::S3Storage::S3_PORT} \\
            -filer \\
            -filer.port=#{Mobilis::Realized::S3Storage::FILER_PORT} \\
            -master.port=#{Mobilis::Realized::S3Storage::MASTER_PORT} \\
            -volume.port=#{Mobilis::Realized::S3Storage::VOLUME_PORT}#{metrics_flag} &

          seaweed_pid="$!"

          trap 'kill "$seaweed_pid"; wait "$seaweed_pid"' INT TERM

          until wget -qO- http://127.0.0.1:#{Mobilis::Realized::S3Storage::MASTER_PORT}/cluster/status >/dev/null 2>&1; do
            sleep 1
          done

          until printf '%s\\n' 's3.bucket.list' | weed shell -master=localhost:9333 -filer=localhost:8888 >/dev/null 2>&1; do
            sleep 1
          done

          #{bucket_commands.join("\n")}

          wait "$seaweed_pid"
        SH
      end

      private

      def write_executable(path, content)
        File.binwrite(path, content.gsub("\r\n", "\n"))
        FileUtils.chmod("+x", path)
      end

      def shell_quote(value)
        "'#{value.gsub("'", "'\"'\"'")}'"
      end
    end
  end
end
