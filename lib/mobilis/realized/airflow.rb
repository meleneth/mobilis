# frozen_string_literal: true

module Mobilis
  module Realized
    class Airflow < Mobilis::Base::BuildForm
      COMPONENTS = {"" => "api-server", "-scheduler" => "scheduler",
                    "-dag-processor" => "dag-processor", "-worker" => "celery worker",
                    "-triggerer" => "triggerer"}.freeze
      attr_reader :database, :broker, :collector

      def initialize(env, node)
        super
        @has_service_dir = true
        set_compose_build_context(".")
        compose[:build][:dockerfile] = "#{name}/Dockerfile"
        register_external_port(8080, "#{name}_WEB_PORT", "#{name} Airflow UI")
      end

      def service_writer
        Mobilis::ServiceWriter::Airflow
      end

      def after_all_nodes_realized
        databases = connected_nodes(Mobilis::Realized::PostgreSQL)
        brokers = connected_nodes(Mobilis::Realized::Redis)
        collectors = connected_nodes(Mobilis::Realized::OtelCollector)
        raise ArgumentError, "Airflow requires exactly one PostgreSQL and one Redis connection" unless databases.size == 1 && brokers.size == 1
        raise ArgumentError, "Airflow supports one collector" if collectors.size > 1

        @database, @broker, @collector = databases.first, brokers.first, collectors.first
        add_compose_aliased_var("AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", "#{name}_airflow_database_url",
                                database.url.sub("postgres://", "postgresql+psycopg2://"))
        add_compose_aliased_var("AIRFLOW__CELERY__RESULT_BACKEND", "#{name}_airflow_result_backend",
                                database.url.sub("postgres://", "db+postgresql://"))
        add_compose_aliased_var("MOBILIS_PIPELINE_DATABASE_URL", "#{name}_pipeline_database_url", database.url)
        add_compose_raw_var("AIRFLOW__CELERY__BROKER_URL", "#{broker.url}/0")
        add_compose_raw_var("AIRFLOW__CORE__EXECUTOR", "CeleryExecutor")
        add_compose_raw_var("AIRFLOW__CORE__AUTH_MANAGER", "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager")
        add_compose_raw_var("AIRFLOW__CORE__EXECUTION_API_SERVER_URL", "http://#{name}:8080/execution/")
        add_compose_raw_var("AIRFLOW__CORE__LOAD_EXAMPLES", "False")
        add_compose_raw_var("AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION", "False")
        add_compose_raw_var("AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK", "True")
        add_compose_aliased_var("AIRFLOW__API_AUTH__JWT_SECRET", "#{name}_jwt_secret", "#{meta_project_name}-#{environment}-airflow-jwt-secret")
        add_compose_aliased_var("AIRFLOW__CORE__FERNET_KEY", "#{name}_fernet_key", "")
        return unless collector

        add_compose_raw_var("AIRFLOW__TRACES__OTEL_ON", "True")
        add_compose_raw_var("AIRFLOW__TRACES__OTEL_HOST", collector.name)
        add_compose_raw_var("AIRFLOW__TRACES__OTEL_PORT", collector.exposed_port_no)
        add_compose_raw_var("AIRFLOW__TRACES__OTEL_SSL_ACTIVE", "False")
        add_compose_raw_var("AIRFLOW__TRACES__OTEL_TASK_LOG_EVENT", "True")
        add_compose_raw_var("AIRFLOW__METRICS__OTEL_ON", "True")
        add_compose_raw_var("AIRFLOW__METRICS__OTEL_HOST", collector.name)
        add_compose_raw_var("AIRFLOW__METRICS__OTEL_PORT", collector.exposed_port_no)
        add_compose_raw_var("OTEL_EXPORTER_OTLP_ENDPOINT", collector.internal_url)
        add_compose_raw_var("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf")
      end

      def service_wrapped_compose
        base = compose.clean_shrunk
        base.delete(:healthcheck)
        base.delete(:ports)
        base[:volumes] = ["./#{name}/dags:/opt/airflow/dags:ro", "#{name}-logs:/opt/airflow/logs"]
        base[:restart] = "unless-stopped"
        base[:labels] = {"app.kubernetes.io/managed-by" => "mobilis", "mobilis.io/project" => meta_project_name,
                         "mobilis.io/service" => name}
        base[:environment] ||= {}
        services = {}
        init_name = "#{name}-init"
        services[init_name] = base.merge(command: "version", restart: "no",
                                         environment: (base[:environment] || []) + ["_AIRFLOW_DB_MIGRATE=true", "_AIRFLOW_WWW_USER_CREATE=true",
                                           "_AIRFLOW_WWW_USER_USERNAME=admin", "_AIRFLOW_WWW_USER_PASSWORD=admin"])
        COMPONENTS.each do |suffix, command|
          service_name = "#{name}#{suffix}"
          deps = (base[:depends_on] || {}).merge(init_name => {condition: "service_completed_successfully"})
          deps["#{name}"] = {condition: "service_healthy"} if suffix == "-worker"
          health = case suffix
                   when "" then "curl --fail http://localhost:8080/api/v2/version"
                   when "-scheduler" then "curl --fail http://localhost:8974/health"
                   when "-worker" then 'celery --app airflow.providers.celery.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}"'
                   else "airflow jobs check --job-type #{suffix == '-triggerer' ? 'TriggererJob' : 'DagProcessorJob'} --hostname \"$${HOSTNAME}\""
                   end
          component = base.merge(command: command, depends_on: deps,
                                 healthcheck: {test: ["CMD-SHELL", health], interval: "30s", timeout: "10s", retries: 5, start_period: "30s"},
                                 environment: (base[:environment] || []) + ["OTEL_SERVICE_NAME=#{service_name}",
                                            "AIRFLOW__TRACES__OTEL_APPLICATION=#{service_name}",
                                            "AIRFLOW__TRACES__OTEL_SERVICE=#{service_name}",
                                            "AIRFLOW__METRICS__OTEL_SERVICE=#{service_name}"])
          component[:ports] = compose_ports.as_json if suffix.empty?
          component[:environment] << "DUMB_INIT_SETSID=0" if suffix == "-worker"
          services[service_name] = component
        end
        {services: services, volumes: {"#{name}-logs" => {}}}
      end
    end
  end
end
