module Mobilis
  module Mixins
    module RealizedNode
      module HasEnvVars
        def env_vars
          @env_vars = [] unless defined?(@env_vars) && @env_vars
          @env_vars
        end

        def per_env_vars
          @per_env_vars = [] unless defined?(@per_env_vars) && @per_env_vars
          @per_env_vars
        end

        def add_env_var(env_var)
          env_vars << env_var
        end

        def add_per_env_var(env_var)
          per_env_vars << env_var
        end

        def env_vars_to_resolve
          env_vars.reject { |e| e.do_not_resolve }
        end

        def env_var(resolved_name)
          env_vars.each do |env_var|
            return env_var if env_var.specific_name == resolved_name
          end
          raise "No such environment variable #{specific_name} for #{name}"
        end

        def env_var_resolved(resolved_name)
          env_vars.each do |env_var|
            return env_var if env_var.resolved_name == resolved_name
          end
          raise "No such environment variable #{specific_name} for #{name}"
        end

        # rubocop:disable all
        def compose_env_vars
          return enum_for :compose_env_vars unless block_given?
          env_vars.each do |env_var|
            yield env_var unless env_var.do_not_resolve
          end
        end

        def all_env_vars
          return enum_for :all_env_vars unless block_given?
          env_vars.each do |env_var|
            yield env_var unless env_var.do_not_resolve
          end
          per_env_vars.each do |env_var|
            yield env_var unless env_var.do_not_resolve
          end
        end

        # rubocop:enable all

        def each_docker_env_var
          enum_for :each_docker_env_var unless block_given?
          env_vars.each do |env_var|
            yield env_var if env_var.instance_of? Mobilis::DockerEnvVar
          end
        end

        def add_basic_env_var(name, value, do_not_resolve: false)
          add_env_var(Mobilis::BasicEnvVar.new(name, value, do_not_resolve: do_not_resolve))
        end

        def add_docker_env_var(resolved_name, specific_name, value, do_not_resolve: false)
          add_env_var(Mobilis::DockerEnvVar.new(resolved_name, specific_name, value, do_not_resolve: do_not_resolve))
        end

        def add_basic_per_env_var(name, value, do_not_resolve: false)
          add_per_env_var(Mobilis::BasicEnvVar.new(name, value, do_not_resolve: do_not_resolve))
        end

        def add_docker_per_env_var(resolved_name, specific_name, value, do_not_resolve: false)
          add_per_env_var(Mobilis::DockerEnvVar.new(resolved_name, specific_name, value,
                                                    do_not_resolve: do_not_resolve))
        end
      end
    end
  end
end
