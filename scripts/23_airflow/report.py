from datetime import datetime

from airflow.sdk import dag, task, get_current_context
from mobilis_pipeline import ensure_schema, load_aggregates, persist_report


@dag(dag_id="demo_report", start_date=datetime(2025, 1, 1), schedule=None,
     catchup=False, tags=["mobilis", "pipeline"])
def report():
    @task
    def read():
        ensure_schema()
        rows = load_aggregates()
        if not rows:
            raise ValueError("Run demo_aggregate successfully before demo_report")
        return rows

    @task
    def publish(rows):
        context = get_current_context()
        return persist_report("daily", rows, fail=(context["dag_run"].conf or {}).get("fail", False))

    publish(read())


report()
