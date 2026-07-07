# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class Rack < Mobilis::Base::ServiceWriter
      def write
        write_project_localgems_dir
        write_local_gems
        write_model_files
        write_otel_config if realized_node.otel_enabled?
        write_default_config_ru unless File.exist?("config.ru")
        write_gemfile
        write_dockerfile
      end

      private

      def write_project_localgems_dir
        FileUtils.mkdir_p("../localgems")
      end

      def write_local_gems
        Dir.chdir("..") do
          local_gems.each(&:write_files)
        end
      end

      def write_model_files
        realized_node.each_model_of_type(Mobilis::Model::File) do |model|
          model.write_file
        end
      end

      def write_otel_config
        FileUtils.mkdir_p("config")
        File.write("config/otel.rb", <<~RUBY)
          # frozen_string_literal: true

          require "opentelemetry/sdk"
          require "opentelemetry/exporter/otlp"
          require "opentelemetry/instrumentation/all"

          OpenTelemetry::SDK.configure do |config|
            otel_endpoint = "\#{ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")}/v1/traces"
            config.service_name = ENV.fetch("OTEL_SERVICE_NAME", "#{realized_node.name}")
            config.use_all
            config.add_span_processor(
              OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
                OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: otel_endpoint)
              )
            )
          end
        RUBY
      end

      def write_default_config_ru
        File.write("config.ru", <<~RUBY)
          # frozen_string_literal: true

          app = proc do
            [
              200,
              { "content-type" => "text/plain" },
              ["#{realized_node.name}\\n"]
            ]
          end

          run app
        RUBY
      end

      def write_gemfile
        lines = [
          "# frozen_string_literal: true",
          "",
          "source \"https://rubygems.org\"",
          "",
          %(ruby "#{ruby_version}"),
          "",
          %(gem "rack", "~> 3.1"),
          %(gem "rackup", "~> 2.2"),
          %(gem "puma", "~> 7.1")
        ]
        gem_models.each { |gem| lines << gem.gemfile_line }
        local_gems.each { |gem| lines << gem.gem_dependency.gemfile_line }
        if realized_node.otel_enabled?
          lines.concat([
                         %(gem "opentelemetry-sdk"),
                         %(gem "opentelemetry-exporter-otlp"),
                         %(gem "opentelemetry-instrumentation-all")
                       ])
        end
        File.write("Gemfile", "#{lines.uniq.join("\n")}\n")
      end

      def write_dockerfile
        File.write("Dockerfile", <<~DOCKERFILE)
          FROM #{Mobilis::ContainerVersions::RUBY}

          WORKDIR /app
          COPY localgems /localgems
          COPY #{realized_node.name}/Gemfile /app/Gemfile
          RUN bundle install
          COPY #{realized_node.name}/ /app

          EXPOSE #{Mobilis::Realized::Rack::INTERNAL_PORT}
          CMD ["bundle", "exec", "ruby", "-r./config/otel", "-S", "rackup", "-o", "0.0.0.0", "-p", "#{Mobilis::Realized::Rack::INTERNAL_PORT}"]
        DOCKERFILE
        return if realized_node.otel_enabled?

        Mobilis::FileLines.edit("Dockerfile") do
          replace_line(/^CMD /) do
            %(CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "#{Mobilis::Realized::Rack::INTERNAL_PORT}"])
          end
        end
      end

      def gem_models
        realized_node.config_node.models.filter_map do |model|
          model if model.is_a?(Mobilis::Model::RubyGem)
        end
      end

      def local_gems
        realized_node.config_node.models.filter_map do |model|
          model if model.is_a?(Mobilis::Model::LocalGem)
        end
      end

      def ruby_image
        Mobilis::ContainerVersions::RUBY
      end

      def ruby_version
        ruby_image.split(":", 2).fetch(1).split("-", 2).first
      end
    end
  end
end
