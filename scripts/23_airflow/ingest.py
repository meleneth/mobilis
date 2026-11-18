from datetime import datetime
import time

from airflow.sdk import dag, task, get_current_context
from mobilis_domain import normalize
from mobilis_pipeline import ensure_schema, persist_sales


@dag(dag_id="demo_ingest", start_date=datetime(2025, 1, 1), schedule=None,
     catchup=False, tags=["mobilis", "pipeline"])
def ingest():
    @task(retries=1)
    def prepare():
        ensure_schema()
        return True

    @task
    def extract_west(_ready):
        time.sleep(3)
        return [{"id": 1, "region": " west ", "amount": "10.25"},
                {"id": 2, "region": "west", "amount": "20.00"}]

    @task
    def extract_east(_ready):
        time.sleep(3)
        return [{"id": 3, "region": "east", "amount": "7.50"},
                {"id": 4, "region": " EAST ", "amount": "2.50"}]

    @task
    def normalize_batch(rows):
        return [{"id": sale.record_id, "region": sale.region, "amount": str(sale.amount)}
                for sale in map(normalize, rows)]

    @task(retries=1, retry_delay=__import__("datetime").timedelta(seconds=5))
    def load(west, east):
        context = get_current_context()
        if context["ti"].try_number == 1:
            raise RuntimeError("Demonstration transient failure; Airflow retry succeeds")
        persist_sales([normalize(row) for row in west + east])
        return 4

    ready = prepare()
    load(normalize_batch.override(task_id="normalize_west")(extract_west(ready)),
         normalize_batch.override(task_id="normalize_east")(extract_east(ready)))


ingest()
