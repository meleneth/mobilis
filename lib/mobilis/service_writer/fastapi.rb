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
          FROM #{realized_node.cassandra ? "python:3.12-bookworm" : Mobilis::ContainerVersions::PYTHON}
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
        write_cassandra if realized_node.cassandra
        write_pubsub if realized_node.pubsub
        write_models if realized_node.database
        write_graphql_support if realized_node.config_node.graphql_subgraph_name
        write_telemetry if realized_node.otel_enabled?
        # Existing file models can supply ordinary application handlers.
        realized_node.each_model_of_type(Mobilis::Model::File, &:write_file)
      end

      private

      def dependencies
        deps = ["fastapi>=0.115,<1", "uvicorn>=0.30,<1", "httpx>=0.27,<1", "requests>=2.32,<3"]
        deps.concat(["SQLAlchemy>=2.0,<2.1", "psycopg[binary]>=3.2,<4"]) if realized_node.database
        deps << "cassandra-driver>=3.29,<4" if realized_node.cassandra
        deps << "google-cloud-pubsub>=2.30,<3" if realized_node.pubsub
        deps << "strawberry-graphql[fastapi]>=0.280,<1" if realized_node.config_node.graphql_subgraph_name
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
        imports << "from .cassandra_client import close_cassandra" if realized_node.cassandra
        imports << "from .pubsub_client import close_pubsub" if realized_node.pubsub
        imports << "from .telemetry import configure, instrument_app" if realized_node.otel_enabled?
        if realized_node.config_node.graphql_subgraph_name
          imports << "from strawberry.fastapi import GraphQLRouter"
          imports << "from .graphql_schema import schema"
          imports << "from .graphql_support import get_graphql_context"
        end
        # @type var cleanup: Array[String]
        cleanup = []
        cleanup.concat(["if get_engine.cache_info().currsize:", "    get_engine().dispose()"]) if realized_node.database
        cleanup << "close_cassandra()" if realized_node.cassandra
        cleanup << "close_pubsub()" if realized_node.pubsub
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
              #{'app.include_router(GraphQLRouter(schema, context_getter=get_graphql_context), prefix="/graphql")' if realized_node.config_node.graphql_subgraph_name}
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

      def write_graphql_support
        if realized_node.database
          File.write("#{@package_dir}/graphql_support.py", <<~PYTHON)
            from starlette.concurrency import run_in_threadpool
            from sqlalchemy import select
            from strawberry.dataloader import DataLoader
            from .database import get_session


            def get_graphql_context():
                # FastAPI closes this session when the GraphQL request finishes.
                with get_session() as session:
                    yield {"session": session, "loaders": {}}


            async def load_by_ids(session, model, ids, *, limit=100):
                unique_ids = list(dict.fromkeys(ids))
                if len(unique_ids) > limit:
                    raise ValueError(f"GraphQL relationship load exceeds {limit} keys")
                if not unique_ids:
                    return {}

                def query():
                    key = model.__mapper__.primary_key[0]
                    records = session.scalars(select(model).where(key.in_(unique_ids))).all()
                    return {getattr(record, key.key): record for record in records}

                return await run_in_threadpool(query)


            def grouped_loader(session, model, foreign_key, *, max_keys=100, max_rows=500):
                column = getattr(model, foreign_key)

                async def load(keys):
                    unique_keys = list(dict.fromkeys(keys))
                    if len(unique_keys) > max_keys:
                        raise ValueError(f"GraphQL relationship load exceeds {max_keys} keys")

                    def query():
                        return session.scalars(select(model).where(column.in_(unique_keys)).limit(max_rows + 1)).all()

                    records = await run_in_threadpool(query)
                    if len(records) > max_rows:
                        raise ValueError(f"GraphQL relationship load exceeds {max_rows} rows")
                    grouped = {key: [] for key in keys}
                    for record in records:
                        grouped[getattr(record, foreign_key)].append(record)
                    return [grouped[key] for key in keys]

                return DataLoader(load_fn=load)
          PYTHON
        else
          File.write("#{@package_dir}/graphql_support.py", <<~PYTHON)
            async def get_graphql_context():
                return {}
          PYTHON
        end
      end

      def write_cassandra
        execution = if realized_node.otel_enabled?
                      <<~PYTHON.rstrip
                        with trace.get_tracer(__name__).start_as_current_span(
                                "cassandra." + operation,
                                attributes={"db.system": "cassandra", "db.operation": operation,
                                            "db.namespace": os.environ["CASSANDRA_KEYSPACE"],
                                            "server.address": os.environ["CASSANDRA_CONTACT_POINTS"]},
                                record_exception=False, set_status_on_exception=False) as span:
                            try:
                                return get_session().execute(statement, parameters)
                            except Exception as error:
                                span.set_attribute("error.type", type(error).__name__)
                                span.set_status(Status(StatusCode.ERROR))
                                raise
                      PYTHON
                    else
                      "return get_session().execute(statement, parameters)"
                    end
        File.write("#{@package_dir}/cassandra_client.py", <<~PYTHON)
          import os
          from cassandra.auth import PlainTextAuthProvider
          from cassandra.cluster import Cluster, ExecutionProfile, EXEC_PROFILE_DEFAULT
          from cassandra.policies import DCAwareRoundRobinPolicy
          #{"from opentelemetry import trace\nfrom opentelemetry.trace import Status, StatusCode" if realized_node.otel_enabled?}

          _cluster = None
          _session = None


          def get_session():
              global _cluster, _session
              if _session is None:
                  points = [point.strip() for point in os.environ["CASSANDRA_CONTACT_POINTS"].split(",") if point.strip()]
                  auth = PlainTextAuthProvider(username=os.environ["CASSANDRA_USERNAME"], password=os.environ["CASSANDRA_PASSWORD"])
                  _cluster = Cluster(points, port=int(os.environ["CASSANDRA_PORT"]),
                                     auth_provider=auth, protocol_version=4,
                                     execution_profiles={EXEC_PROFILE_DEFAULT: ExecutionProfile(
                                         load_balancing_policy=DCAwareRoundRobinPolicy(
                                             local_dc=os.environ["CASSANDRA_DATACENTER"]))})
                  try:
                      _session = _cluster.connect(os.environ["CASSANDRA_KEYSPACE"])
                  except Exception:
                      _cluster.shutdown()
                      _cluster = None
                      raise
              return _session


          def execute(operation, statement, parameters=None):
              if not operation.isidentifier():
                  raise ValueError("operation must be a safe identifier")
              #{execution.lines.join("        ").rstrip}


          def close_cassandra():
              global _cluster, _session
              if _cluster is not None:
                  _cluster.shutdown()
              _cluster = None
              _session = None
        PYTHON
      end

      def write_pubsub
        traced = realized_node.otel_enabled?
        publish_body = if traced
                         <<~PYTHON.rstrip
                           with trace.get_tracer(__name__).start_as_current_span(
                                   "pubsub.publish", kind=SpanKind.PRODUCER,
                                   attributes={"messaging.system": "gcp_pubsub", "messaging.operation": "publish",
                                               "messaging.destination.name": topic},
                                   record_exception=False, set_status_on_exception=False) as span:
                               try:
                                   TraceContextTextMapPropagator().inject(attributes)
                                   message_id = _publisher_client().publish(path, data, **attributes).result(timeout=10)
                                   span.set_attribute("messaging.message.id", message_id)
                                   return message_id
                               except Exception as error:
                                   span.set_attribute("error.type", type(error).__name__)
                                   span.set_status(Status(StatusCode.ERROR))
                                   raise
                         PYTHON
                       else
                         "return _publisher_client().publish(path, data, **attributes).result(timeout=10)"
                       end
        process_body = if traced
                         <<~PYTHON.rstrip
                           extracted = TraceContextTextMapPropagator().extract(self.attributes)
                           remote = trace.get_current_span(extracted).get_span_context()
                           links = [Link(remote)] if remote.is_valid else []
                           with trace.get_tracer(__name__).start_as_current_span(
                                   "pubsub.process", kind=SpanKind.CONSUMER, links=links,
                                   attributes={"messaging.system": "gcp_pubsub", "messaging.operation": "process",
                                               "messaging.destination.name": self.subscription,
                                               "messaging.message.id": self.message_id,
                                               "messaging.message.delivery_attempt": self.delivery_attempt},
                                   record_exception=False, set_status_on_exception=False) as span:
                               try:
                                   return handler(self)
                               except Exception as error:
                                   span.set_attribute("error.type", type(error).__name__)
                                   span.set_status(Status(StatusCode.ERROR))
                                   raise
                         PYTHON
                       else
                         "return handler(self)"
                       end
        File.write("#{@package_dir}/pubsub_client.py", <<~PYTHON)
          import os
          from google.cloud import pubsub_v1
          from google.api_core.exceptions import DeadlineExceeded
          #{"from opentelemetry import trace\nfrom opentelemetry.trace import Link, SpanKind, Status, StatusCode\nfrom opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator" if traced}

          _publisher = None
          _subscriber = None


          def _allowed(variable):
              return set(filter(None, os.environ.get(variable, "").split(",")))


          def _publisher_client():
              global _publisher
              if _publisher is None:
                  _publisher = pubsub_v1.PublisherClient()
              return _publisher


          def _subscriber_client():
              global _subscriber
              if _subscriber is None:
                  _subscriber = pubsub_v1.SubscriberClient()
              return _subscriber


          def publish(topic, data, attributes=None):
              if topic not in _allowed("MOBILIS_PUBSUB_PUBLISH_TOPICS"):
                  raise ValueError("Pub/Sub topic is not declared for this service: " + topic)
              if not isinstance(data, bytes):
                  raise TypeError("Pub/Sub payload must be bytes")
              attributes = dict(attributes or {})
              path = _publisher_client().topic_path(os.environ["PUBSUB_PROJECT_ID"], topic)
              #{publish_body.lines.join("    ").rstrip}


          class Delivery:
              def __init__(self, subscription, received):
                  self.subscription = subscription
                  self.ack_id = received.ack_id
                  self.data = received.message.data
                  self.attributes = dict(received.message.attributes)
                  self.message_id = received.message.message_id
                  self.delivery_attempt = received.delivery_attempt or 0

              def process(self, handler):
                  #{process_body.lines.join("        ").rstrip}

              def ack(self):
                  path = _subscriber_client().subscription_path(os.environ["PUBSUB_PROJECT_ID"], self.subscription)
                  _subscriber_client().acknowledge(request={"subscription": path, "ack_ids": [self.ack_id]}, timeout=5)

              def nack(self):
                  path = _subscriber_client().subscription_path(os.environ["PUBSUB_PROJECT_ID"], self.subscription)
                  _subscriber_client().modify_ack_deadline(request={"subscription": path, "ack_ids": [self.ack_id],
                                                            "ack_deadline_seconds": 0}, timeout=5)


          def pull(subscription, max_messages=1, timeout=5):
              if subscription not in _allowed("MOBILIS_PUBSUB_SUBSCRIPTIONS"):
                  raise ValueError("Pub/Sub subscription is not declared for this service: " + subscription)
              path = _subscriber_client().subscription_path(os.environ["PUBSUB_PROJECT_ID"], subscription)
              try:
                  response = _subscriber_client().pull(request={"subscription": path, "max_messages": max_messages},
                                                       timeout=timeout)
              except DeadlineExceeded:
                  return []
              return [Delivery(subscription, item) for item in response.received_messages]


          def close_pubsub():
              global _publisher, _subscriber
              if _publisher is not None:
                  _publisher.transport.close()
              if _subscriber is not None:
                  _subscriber.transport.close()
              _publisher = None
              _subscriber = None
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
