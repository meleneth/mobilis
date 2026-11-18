from datetime import datetime

from airflow.sdk import dag, task
from mobilis_domain import summarize
from mobilis_pipeline import ensure_schema, load_sales, persist_aggregates


@dag(dag_id="demo_aggregate", start_date=datetime(2025, 1, 1), schedule=None,
     catchup=False, tags=["mobilis", "pipeline"])
def aggregate():
    @task
    def read():
        ensure_schema()
        sales = load_sales()
        if len(sales) != 4:
            raise ValueError("Run demo_ingest successfully before demo_aggregate")
        return True

    @task
    def compute(_ready):
        return {region: (count, str(total)) for region, (count, total) in summarize(load_sales()).items()}

    @task
    def store(values):
        persist_aggregates(values)
        return values

    store(compute(read()))


aggregate()
