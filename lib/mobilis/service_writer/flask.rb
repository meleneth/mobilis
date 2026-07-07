module Mobilis
  module ServiceWriter
    class Flask < Mobilis::Base::ServiceWriter
      def write
        write_Dockerfile
        write_requirements_txt
        write_app_py
        @manifest.commit_all("add flask project #{@realized_node.name}")
      end

      def write_Dockerfile
        File.write("Dockerfile", <<~HERE)
          # Use the official Python image as a base
          FROM #{Mobilis::ContainerVersions::PYTHON}

          # Set the working directory inside the container
          WORKDIR /app

          # Copy the requirements file and install dependencies
          COPY requirements.txt .
          RUN pip install --no-cache-dir -r requirements.txt

          # Copy the application code
          COPY . .

          # Expose port 5000 for the Flask app
          EXPOSE 5000

          # Set the command to run the application
          CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
        HERE
      end

      def write_requirements_txt
        File.write("requirements.txt", <<~HERE)
          flask
          redis
          opentelemetry-api
          opentelemetry-sdk
          opentelemetry-exporter-otlp
          opentelemetry-instrumentation-flask
          opentelemetry-instrumentation-logging
          opentelemetry-instrumentation-redis
          opentelemetry-instrumentation-requests
          requests
          prometheus_flask_exporter
          gunicorn
        HERE
      end

      def write_app_py
        File.write("app.py", <<~HERE)
          from flask import Flask, request, jsonify
          from prometheus_flask_exporter import PrometheusMetrics
          import redis
          from opentelemetry.sdk.resources import Resource
          from opentelemetry.instrumentation.flask import FlaskInstrumentor
          from opentelemetry.instrumentation.requests import RequestsInstrumentor
          from opentelemetry.sdk.trace import TracerProvider
          from opentelemetry.sdk.trace.export import BatchSpanProcessor
          from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
          from opentelemetry.trace import set_tracer_provider

          from opentelemetry.trace import get_tracer_provider, set_tracer_provider
          from opentelemetry.sdk.trace.export import BatchSpanProcessor
          from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

          # Set up the tracer provider
          resource = Resource.create({"service.name": "flask-api-otel-demo"})
          provider = TracerProvider(resource=resource)
          set_tracer_provider(provider)  # ✅ Correct way to set it
          tracer = get_tracer_provider().get_tracer(__name__)  # ✅ Correct way to get the tracer

          # Set up OTLP Exporter
          otlp_exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True)
          provider.add_span_processor(BatchSpanProcessor(otlp_exporter))

          app = Flask(__name__)


          FlaskInstrumentor().instrument_app(app)
          RequestsInstrumentor().instrument()
          # Attach Prometheus metrics to Flask
          metrics = PrometheusMetrics(app)

          # This exposes metrics at /metrics for Prometheus
          metrics.info("flask_app_info", "Flask App Info", version="1.0.0")

          ## Redis Connection
          #redis_client = redis.Redis(host="redis", port=6379, decode_responses=True)

          @app.route("/set", methods=["POST"])
          def set_value():
              key = request.json.get("key")
              value = request.json.get("value")
              with tracer.start_as_current_span("request_handling") as span:
                  worker_id = request.headers.get("X-Worker-ID")
                  if worker_id:
                      span.set_attribute("worker_id", worker_id)

              #with tracer.start_as_current_span("redis_set_value"):
              #    redis_client.set(key, value)

              with tracer.start_as_current_span("format_return"):
                  value = jsonify({"message": f"Set {key} = {value}"})
              return value, 200

          @app.route("/get", methods=["GET"])
          def get_value():
              key = request.args.get("key")
              with tracer.start_as_current_span("request_handling") as span:
                  worker_id = request.headers.get("X-Worker-ID")
                  if worker_id:
                      span.set_attribute("worker_id", worker_id)

              #with tracer.start_as_current_span("redis_get_value"):
              #    value = redis_client.get(key)
              value=42
              with tracer.start_as_current_span("format_return"):
                  value = jsonify({"message": f"Set {key} = {value}"})

              return value, 200

          @app.route("/health", methods=["GET"])
          def health():
              return "OK", 200

          if __name__ == "__main__":
              app.run(host="0.0.0.0", port=5000)


        HERE
      end

      def write_compose_file
        service_details = {} #: Hash[Symbol, untyped]
        service_details[:image] = "#{username}/#{@realized_node.name}"
        service_details[:build] = { context: "./#{realized_node.name}" }
        service_details[:environment] = @realized_node.env_vars_for_compose_environment.map(&:compose_repr)
        service = {} #: Hash[String, Hash[Symbol, untyped]]
        service[@realized_node.name] = service_details
        services = { services: service }

        directory_service.chdir_compose
        File.write("#{realized_node.name}.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(services)))
        commit_all("Compose for #{realized_node.name}")
      end
    end
  end
end
