# frozen_string_literal: true

module Mobilis
  module Primitives
    # EmitVar defines a variable used in Docker Compose and the .env file.
    #
    # - container_name: used inside the container, e.g., POSTGRES_URL
    # - envfile_name: key in the .env file, e.g., USER_POSTGRES_URL
    # - value: actual value to inject
    #
    # Compose emits:   container_name=${envfile_name}
    # .env file emits: envfile_name=value
    class EmitVar
      attr_reader :container_name, :envfile_name, :value, :do_not_resolve

      def self.for(service, type, value, do_not_resolve: false)
        container_name = type
        envfile_name = "#{service}_#{type}"
        new(container_name, envfile_name, value, do_not_resolve: do_not_resolve)
      end

      def initialize(container_name, envfile_name = nil, value = nil, do_not_resolve: false)
        @container_name = normalize_name(container_name)
        @envfile_name = envfile_name ? normalize_name(envfile_name) : nil
        @value = value
        @do_not_resolve = do_not_resolve
      end

      def has_envfile_name?
        !envfile_name.nil?
      end

      def compose_repr
        return "#{container_name}=#{value}" unless has_envfile_name?

        "#{container_name}=#{env_var_ref}"
      end

      def container_var_ref
        "${#{@container_name}}"
      end

      def env_var_ref
        "${#{@envfile_name}}"
      end

      def env_repr
        return nil unless has_envfile_name?

        "#{envfile_name}=#{value}"
      end

      def as(new_container_name)
        self.class.new(new_container_name, envfile_name, value)
      end

      def key
        return container_name if container_name

        envfile_name
      end

      private

      def normalize_name(name)
        name.to_s.upcase.tr("-", "_")
      end
    end
  end
end
