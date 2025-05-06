# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      module HasEnvVars
        def add_env_only_var(envfile_name, value)
          myvar = Mobilis::Primitives::EmitVar.new(nil, envfile_name, value)
          envfile_vars.add(myvar)
          myvar
        end

        def add_compose_aliased_var(container_name, envfile_name, value, override: false)
          myvar = Mobilis::Primitives::EmitVar.new(container_name, envfile_name, value)
          envfile_vars.add(myvar)
          if override
            compose_environment_override.add(myvar, override: override)
          else
            compose_environment.add(myvar)
          end
          myvar
        end

        def add_compose_raw_var(container_name, value, override: false)
          myvar = Mobilis::Primitives::EmitVar.new(container_name, nil, value)
          if override
            compose_environment_override.add(myvar)
          else
            compose_environment.add(myvar)
          end
          myvar
        end

        def env_vars_for_env_file(&block)
          return enum_for(:env_vars_for_env_file) unless block_given?

          envfile_vars.each(&block)
        end

        def env_vars_for_compose_environment(&block)
          return enum_for(:env_vars_for_compose_environment) unless block_given?

          compose_vars.each(&block)
        end

        def all_emit_vars
          return enum_for(:all_emit_vars) unless block_given?

          seen = {}
          envfile_vars.each do |var|
            next if seen[var]

            seen[var] = true
            yield var
          end
          compose_vars.each do |var|
            next if seen[var]

            seen[var] = true
            yield var
          end
        end

        def compose_environment_override
          unless defined?(@compose_environment_override) && @compose_environment_override
            @compose_environment_override = Mobilis::Compose::Environment.new
          end
          @compose_environment_override
        end

        def compose_environment
          unless defined?(@compose_environment) && @compose_environment
            @compose_environment = Mobilis::Compose::Environment.new
          end
          @compose_environment
        end

        def envfile_vars
          unless defined?(@envfile_vars) && @envfile_vars
            @envfile_vars = Mobilis::Compose::Environment.new(envfile: true)
          end
          @envfile_vars
        end
      end
    end
  end
end
