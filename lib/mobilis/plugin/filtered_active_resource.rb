# frozen_string_literal: true

require "active_support/inflector"
require "fileutils"

module Mobilis
  module Plugin
    class FilteredActiveResource < Mobilis::Base::Plugin
      def hook_after_services_written
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |_realized_env, realized_node|
          write_provider_files(realized_node)
          write_consumer_files(realized_node)
        end
      end

      def hook_after_rails_models_created
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |_realized_env, realized_node|
          patch_provider_models(realized_node)
        end
      end

      private

      def write_provider_files(realized_node)
        # @type var provider_files_written: Hash[String, bool]
        provider_files_written = @provider_files_written || {}
        @provider_files_written = provider_files_written
        return if provider_files_written[realized_node.name]

        resources = api_resources(realized_node)
        return if resources.empty?

        directory_service.chdir_project(realized_node)
        write_filterable_concern
        resources.each do |resource|
          write_provider_controller(resource)
          add_provider_route(resource)
        end
        directory_service.chdir_generate
        commit_all("#{realized_node.name} filtered resource endpoints")
        provider_files_written[realized_node.name] = true
      end

      def write_consumer_files(realized_node)
        # @type var consumer_files_written: Hash[String, bool]
        consumer_files_written = @consumer_files_written || {}
        @consumer_files_written = consumer_files_written
        return if consumer_files_written[realized_node.name]

        providers = connected_rails_providers(realized_node)
        return if providers.empty?

        directory_service.chdir_project(realized_node)
        wrote = false
        providers.each do |provider|
          api_resources(provider).each do |resource|
            write_active_resource_client(provider, resource)
            wrote = true
          end
        end
        install_active_resource_gem if wrote
        directory_service.chdir_generate
        commit_all("#{realized_node.name} filtered ActiveResource clients") if wrote
        consumer_files_written[realized_node.name] = true if wrote
      end

      def install_active_resource_gem
        rails_builder = @manifest.plugin_for(Mobilis::Plugin::RailsBuilder)
        raise "RailsBuilder plugin is required to install ActiveResource" unless rails_builder.is_a?(Mobilis::Plugin::RailsBuilder)

        rails_builder.container_run("bundle add activeresource --require active_resource")
      end

      def patch_provider_models(realized_node)
        # @type var provider_models_patched: Hash[String, bool]
        provider_models_patched = @provider_models_patched || {}
        @provider_models_patched = provider_models_patched
        return if provider_models_patched[realized_node.name]

        resources = api_resources(realized_node)
        return if resources.empty?

        directory_service.chdir_project(realized_node)
        resources.each do |resource|
          patch_provider_model(resource)
        end
        directory_service.chdir_generate
        commit_all("#{realized_node.name} filtered resource model metadata")
        provider_models_patched[realized_node.name] = true
      end

      def api_resources(realized_node)
        realized_node.config_node.models.filter_map do |model|
          next unless model.is_a?(Mobilis::Model::Rails::Model)
          next unless model.api_exposed?

          model
        end
      end

      def connected_rails_providers(realized_node)
        realized_node.extra_depends_on.filter_map do |dep|
          dep[:target] if dep[:target].is_a?(Mobilis::Realized::Rails)
        end
      end

      def write_filterable_concern
        FileUtils.mkdir_p("app/models/concerns/mobilis")
        File.write("app/models/concerns/mobilis/filterable.rb", <<~RUBY)
          # frozen_string_literal: true

          module Mobilis
            module Filterable
              extend ActiveSupport::Concern

              class_methods do
                def filterable_fields(*fields)
                  @filterable_fields ||= []
                  @filterable_fields.concat(fields.map(&:to_s))
                end

                def allowed_filters
                  @filterable_fields || []
                end
              end
            end
          end
        RUBY
      end

      def write_provider_controller(resource)
        FileUtils.mkdir_p("app/controllers")
        File.write("app/controllers/#{resources_name(resource)}_controller.rb", <<~RUBY)
          # frozen_string_literal: true

          class #{controller_class_name(resource)} < ApplicationController
            before_action :set_#{singular_name(resource)}, only: %i[show]

            def index
              filters = params.slice(*#{model_class_name(resource)}.allowed_filters).permit!
              raise ActionController::BadRequest, "filters required" unless filters.present?

              render json: #{model_class_name(resource)}.where(filters.to_h)
            end

            def search
              filters = params.permit(#{permit_filter_args(resource)})
              raise ActionController::BadRequest, "filters required" unless filters.present?

              render json: #{model_class_name(resource)}.where(filters.to_h)
            end

            def show
              render json: @#{singular_name(resource)}
            end

            private

            def set_#{singular_name(resource)}
              @#{singular_name(resource)} = #{model_class_name(resource)}.find(params.expect(:id))
            end
          end
        RUBY
      end

      def add_provider_route(resource)
        path = "config/routes.rb"
        contents = File.read(path)
        route = <<~RUBY
            resources :#{resources_name(resource)}, only: %i[index show] do
              collection do
                post :search
              end
            end
        RUBY
        return if contents.include?("resources :#{resources_name(resource)}")

        File.write(path, contents.sub(/^end\s*\z/, "#{route}end\n"))
      end

      def patch_provider_model(resource)
        path = "app/models/#{singular_name(resource)}.rb"
        return unless File.exist?(path)

        contents = File.read(path)
        include_line = "  include Mobilis::Filterable\n"
        filter_line = "  filterable_fields #{resource.filterable_fields.map(&:inspect).join(', ')}\n"
        unless contents.include?("include Mobilis::Filterable")
          contents = contents.sub(/^class #{model_class_name(resource)} < ApplicationRecord\n/, "\\0#{include_line}")
        end
        unless contents.include?("filterable_fields ")
          contents = contents.sub(/^class #{model_class_name(resource)} < ApplicationRecord\n(?:  include Mobilis::Filterable\n)?/, "\\0#{filter_line}")
        end
        File.write(path, contents)
      end

      def write_active_resource_client(provider, resource)
        FileUtils.mkdir_p("app/models")
        File.write("app/models/#{singular_name(resource)}.rb", <<~RUBY)
          # frozen_string_literal: true

          require "active_resource"
          require "json"

          class #{model_class_name(resource)} < ActiveResource::Base
            self.site = ENV.fetch("#{dependency_url_container_name(provider)}", "#{provider.internal_url}")
            self.format = :json
            self.primary_key = "id"
            self.collection_name = "#{resources_name(resource)}"

            def self.with_headers(temp_headers)
              old_headers = headers.dup
              propagated_headers = temp_headers.dup
              OpenTelemetry.propagation.inject(propagated_headers) if defined?(OpenTelemetry)
              self.headers.merge!(propagated_headers)
              yield
            ensure
              self.headers.replace(old_headers)
            end

            def self.search(params)
              raw = connection.post(
                "/#{resources_name(resource)}/search",
                params.to_json,
                headers.merge("Accept" => "application/json", "Content-Type" => "application/json")
              )

              ActiveSupport::JSON.decode(raw.body).map { |attrs| new(attrs) }
            end
          end
        RUBY
      end

      def dependency_url_container_name(provider)
        "#{provider.name}_url".upcase.tr("-", "_")
      end

      def permit_filter_args(resource)
        resource.filterable_fields.map { |field| "#{field}: []" }.join(", ")
      end

      def singular_name(resource)
        resource.name.underscore
      end

      def resources_name(resource)
        resource.name.underscore.pluralize
      end

      def model_class_name(resource)
        singular_name(resource).camelize
      end

      def controller_class_name(resource)
        "#{resources_name(resource).camelize}Controller"
      end
    end
  end
end
