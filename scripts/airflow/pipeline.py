"""Retry-safe PostgreSQL persistence for the Airflow demonstration."""
import json
import os
import atexit
from contextlib import contextmanager
from decimal import Decimal

import psycopg2
from opentelemetry import context as otel_context, trace
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator


def _configure_telemetry():
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not endpoint:
        return
    # Airflow's scheduler may already have installed its native provider.
    # Task execution can start in a separate process with only the API proxy.
    if type(trace.get_tracer_provider()).__name__ != "ProxyTracerProvider":
        return
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

    provider = TracerProvider(resource=Resource.create({"service.name": os.environ.get("OTEL_SERVICE_NAME", "airflow-worker")}))
    provider.add_span_processor(SimpleSpanProcessor(OTLPSpanExporter(endpoint=endpoint.rstrip("/") + "/v1/traces")))
    trace.set_tracer_provider(provider)
    atexit.register(provider.shutdown)


_configure_telemetry()


@contextmanager
def _operation(name):
    token = None
    try:
        from airflow.sdk import get_current_context
        carrier = get_current_context()["ti"].context_carrier
        if carrier and not trace.get_current_span().get_span_context().is_valid:
            parent = TraceContextTextMapPropagator().extract(carrier)
            if trace.get_current_span(parent).get_span_context().is_valid:
                token = otel_context.attach(parent)
    except (ImportError, RuntimeError, KeyError, AttributeError):
        pass
    try:
        with trace.get_tracer(__name__).start_as_current_span(name) as span:
            _annotate(span)
            yield span
    finally:
        if token is not None:
            otel_context.detach(token)


def _annotate(span):
    """Correlate application spans even if Airflow/Celery split traces."""
    try:
        from airflow.sdk import get_current_context
        context = get_current_context()
        ti = context["ti"]
        span.set_attribute("airflow.dag_id", ti.dag_id)
        span.set_attribute("airflow.task_id", ti.task_id)
        span.set_attribute("airflow.run_id", ti.run_id)
        span.set_attribute("airflow.task_attempt", ti.try_number)
        span.set_attribute("airflow.runtime", os.environ.get("OTEL_SERVICE_NAME", "airflow-worker"))
    except (ImportError, RuntimeError, KeyError, AttributeError):
        return


def sql_execute(cursor, statement, parameters=None):
    """Trace the exact PostgreSQL operation executed by this package."""
    operation = statement.split(None, 1)[0].upper()
    with _operation("postgresql." + operation.lower()) as span:
        span.set_attribute("db.system", "postgresql")
        span.set_attribute("db.operation", operation)
        span.set_attribute("db.statement", statement)
        cursor.execute(statement, parameters)


@contextmanager
def connection():
    db = psycopg2.connect(os.environ["MOBILIS_PIPELINE_DATABASE_URL"])
    try:
        with db:
            yield db
    finally:
        db.close()


def ensure_schema():
    with connection() as db, db.cursor() as cur:
        sql_execute(cur, "CREATE TABLE IF NOT EXISTS demo_sales (id integer PRIMARY KEY, region text NOT NULL, amount numeric(12,2) NOT NULL)")
        sql_execute(cur, "CREATE TABLE IF NOT EXISTS demo_aggregates (region text PRIMARY KEY, sale_count integer NOT NULL, total numeric(12,2) NOT NULL)")
        sql_execute(cur, "CREATE TABLE IF NOT EXISTS demo_reports (report_name text PRIMARY KEY, content jsonb NOT NULL)")


def persist_sales(sales):
    with _operation("pipeline.persist_sales") as span:
        span.set_attribute("demo.record_count", len(sales))
        with connection() as db, db.cursor() as cur:
            for sale in sales:
                sql_execute(cur, "INSERT INTO demo_sales(id,region,amount) VALUES (%s,%s,%s) ON CONFLICT(id) DO UPDATE SET region=EXCLUDED.region,amount=EXCLUDED.amount",
                            (sale.record_id, sale.region, sale.amount))


def load_sales():
    from mobilis_domain import Sale
    with _operation("pipeline.load_sales") as span:
        with connection() as db, db.cursor() as cur:
            sql_execute(cur, "SELECT id,region,amount FROM demo_sales ORDER BY id")
            return [Sale(*row) for row in cur.fetchall()]


def persist_aggregates(values):
    with _operation("pipeline.persist_aggregates") as span:
        with connection() as db, db.cursor() as cur:
            for region, (count, total) in values.items():
                sql_execute(cur, "INSERT INTO demo_aggregates(region,sale_count,total) VALUES (%s,%s,%s) ON CONFLICT(region) DO UPDATE SET sale_count=EXCLUDED.sale_count,total=EXCLUDED.total",
                            (region, count, total))


def load_aggregates():
    with connection() as db, db.cursor() as cur:
        sql_execute(cur, "SELECT region,sale_count,total FROM demo_aggregates ORDER BY region")
        return [{"region": region, "count": count, "total": str(total)} for region, count, total in cur.fetchall()]


def persist_report(name, rows, fail=False):
    content = {"regions": rows, "grand_total": str(sum((Decimal(row["total"]) for row in rows), Decimal("0.00")))}
    with _operation("pipeline.persist_report") as span:
        if fail:
            raise RuntimeError("Intentional failure requested by DAG run configuration")
        with connection() as db, db.cursor() as cur:
            sql_execute(cur, "INSERT INTO demo_reports(report_name,content) VALUES (%s,%s::jsonb) ON CONFLICT(report_name) DO UPDATE SET content=EXCLUDED.content",
                        (name, json.dumps(content, sort_keys=True)))
    return content
