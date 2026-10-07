# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class FastAPI < Mobilis::Base::ServiceWriter
      def write
        package = realized_node.config_node.package_name
        @package_dir = "src/#{package}"
        FileUtils.mkdir_p(@package_dir)
        FileUtils.mkdir_p("tests")
        File.write(".gitignore", ".venv/\n__pycache__/\n.pytest_cache/\n.coverage\nhtmlcov/\n*.egg-info/\n")
        File.write("tests/test_health.py", <<~PYTHON)
          from fastapi.testclient import TestClient
          from #{package}.app import create_app


          def test_health():
              with TestClient(create_app(telemetry=False)) as client:
                  response = client.get("/health")
              assert response.status_code == 200
              assert response.json() == {"status": "ok"}
              assert response.headers["content-type"] == "application/json"
        PYTHON
        File.write("#{@package_dir}/__init__.py", "")
        File.write("pyproject.toml", <<~TOML)
          [build-system]
          requires = ["setuptools>=75"]
          build-backend = "setuptools.build_meta"

          [project]
          name = "#{realized_node.name}"
          version = "0.1.0"
          requires-python = ">=3.11"
          dependencies = #{dependencies.to_json}

          [project.optional-dependencies]
          test = ["pytest>=8,<10", "pytest-cov>=6,<8", "flexmock>=0.12,<1"]

          [project.scripts]
          #{realized_node.name} = "#{package}.cli:main"

          [tool.setuptools.packages.find]
          where = ["src"]

          [tool.pytest.ini_options]
          testpaths = ["tests"]

          [tool.coverage.run]
          branch = true
          source = ["#{package}"]

          [tool.coverage.report]
          show_missing = true
        TOML
        File.write("Dockerfile", <<~DOCKER)
          FROM #{Mobilis::ContainerVersions::PYTHON}
          WORKDIR /app
          COPY . .
          RUN pip install --no-cache-dir .
          EXPOSE #{realized_node.exposed_port_no}
          CMD ["#{realized_node.name}"]
        DOCKER
        File.write("#{@package_dir}/cli.py", <<~PYTHON)
          import os
          import uvicorn
          from .app import create_app


          def main():
              uvicorn.run(create_app(), host="0.0.0.0", port=int(os.environ.get("PORT", "#{realized_node.exposed_port_no}")))
        PYTHON
        write_app
        File.write("#{@package_dir}/routes.py", "def register(app):\n    pass\n")
        write_database if realized_node.database
        write_models if realized_node.database
        write_telemetry if realized_node.otel_enabled?
        # Existing file models can supply ordinary application handlers.
        realized_node.each_model_of_type(Mobilis::Model::File, &:write_file)
      end

      private

      def dependencies
        deps = ["fastapi>=0.115,<1", "uvicorn>=0.30,<1", "httpx>=0.27,<1", "requests>=2.32,<3"]
        deps.concat(["SQLAlchemy>=2.0,<2.1", "psycopg[binary]>=3.2,<4"]) if realized_node.database
        if realized_node.otel_enabled?
          deps.concat(["opentelemetry-sdk>=1.30,<2", "opentelemetry-exporter-otlp-proto-http>=1.30,<2",
            "opentelemetry-instrumentation-fastapi", "opentelemetry-instrumentation-httpx",
            "opentelemetry-instrumentation-requests"])
          deps << "opentelemetry-instrumentation-sqlalchemy" if realized_node.database
        end
        deps
      end

      def write_app
        # @type var imports: Array[String]
        imports = []
        imports << "from .database import get_engine" if realized_node.database
        imports << "from .telemetry import configure, instrument_app" if realized_node.otel_enabled?
        # @type var cleanup: Array[String]
        cleanup = []
        cleanup.concat(["if get_engine.cache_info().currsize:", "    get_engine().dispose()"]) if realized_node.database
        cleanup.concat(["if provider is not None:", "    provider.shutdown()"]) if realized_node.otel_enabled?
        File.write("#{@package_dir}/app.py", <<~PYTHON)
          from contextlib import asynccontextmanager
          from fastapi import FastAPI
          from .routes import register
          #{imports.join("\n")}


          def create_app(*, telemetry=True):
              #{"provider = configure(#{"get_engine()" if realized_node.database}) if telemetry else None" if realized_node.otel_enabled?}
              @asynccontextmanager
              async def lifespan(app):
                  try:
                      yield
                  finally:
                      #{cleanup.empty? ? "pass" : cleanup.join("\n            ")}

              app = FastAPI(lifespan=lifespan)

              @app.get("/health")
              def health():
                  return {"status": "ok"}

              register(app)
              #{"if telemetry:\n        instrument_app(app)" if realized_node.otel_enabled?}
              return app
        PYTHON
      end

      def write_database
        File.write("#{@package_dir}/database.py", <<~PYTHON)
          import os
          from functools import lru_cache
          from sqlalchemy import create_engine
          from sqlalchemy.engine import make_url
          from sqlalchemy.orm import Session

          # Credentials, host and database come exclusively from the connection.
          @lru_cache(maxsize=1)
          def get_engine():
              url = make_url(os.environ["DATABASE_URL"]).set(drivername="postgresql+psycopg")
              return create_engine(url, pool_pre_ping=True)


          def get_session():
              return Session(get_engine())
        PYTHON
      end

      def write_models
        lines = ["from datetime import date, datetime", "from decimal import Decimal", "from uuid import UUID",
          "import sqlalchemy as sa", "from sqlalchemy import ForeignKey", "from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column",
          "", "", "class Base(DeclarativeBase):", "    pass"]
        realized_node.each_model_of_type(Mobilis::Model::SQLAlchemy::Model) do |model|
          raise ArgumentError, "SQLAlchemy model #{model.name} needs a primary key" unless model.columns.any? { |c| c[:primary_key] }

          lines.concat(["", "", "class #{model.name}(Base):", "    __tablename__ = #{model.table.to_json}"])
          model.columns.each do |column|
            args = ["sa.#{column[:sql_type]}"]
            args << "ForeignKey(#{column[:foreign_key].to_json})" if column[:foreign_key]
            %i[primary_key nullable unique].each { |key| args << "#{key}=#{column[key] ? "True" : "False"}" }
            default = column[:default]
            default = "True" if default == true
            default = "False" if default == false
            args << "default=#{default}" unless default.nil?
            type = column[:python_type]
            type = "#{type} | None" if column[:nullable]
            lines << "    #{column[:name]}: Mapped[#{type}] = mapped_column(#{args.join(", ")})"
          end
        end
        File.write("#{@package_dir}/models.py", "#{lines.join("\n")}\n")
      end

      def write_telemetry
        File.write("#{@package_dir}/telemetry.py", <<~PYTHON)
          from functools import lru_cache
          from opentelemetry import trace, propagate
          from opentelemetry.sdk.resources import Resource
          from opentelemetry.sdk.trace import TracerProvider
          from opentelemetry.sdk.trace.export import BatchSpanProcessor
          from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
          from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
          from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
          from opentelemetry.instrumentation.requests import RequestsInstrumentor
          from opentelemetry.propagators.composite import CompositePropagator
          from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
          from opentelemetry.baggage.propagation import W3CBaggagePropagator
          #{"from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor" if realized_node.database}


          @lru_cache(maxsize=1)
          def configure(#{"engine" if realized_node.database}):
              provider = TracerProvider(resource=Resource.create({}))
              provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
              trace.set_tracer_provider(provider)
              propagate.set_global_textmap(CompositePropagator([TraceContextTextMapPropagator(), W3CBaggagePropagator()]))
              HTTPXClientInstrumentor().instrument()
              RequestsInstrumentor().instrument()
              #{"SQLAlchemyInstrumentor().instrument(engine=engine)" if realized_node.database}
              return provider


          def instrument_app(app):
              # FastAPI instrumentation already wraps ASGI; no second Uvicorn wrapper.
              FastAPIInstrumentor.instrument_app(app, exclude_spans=["receive", "send"])
        PYTHON
      end
    end
  end
end
