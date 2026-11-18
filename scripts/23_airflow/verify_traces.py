#!/usr/bin/env python3
"""Verify exported Airflow, package, and SQL spans in Jaeger after demo runs."""
import json
import sys
import time
from urllib.parse import urlencode
from urllib.request import urlopen


def fetch(root):
    query = urlencode({"service": "orchestrator-worker", "limit": 100})
    with urlopen(f"{root.rstrip('/')}/api/traces?{query}", timeout=5) as response:
        return json.load(response)["data"]


def attribute(span, name):
    return next((tag["value"] for tag in span.get("tags", []) if tag["key"] == name), None)


def parent_is(span, parent):
    return any(ref["refType"] == "CHILD_OF" and ref["spanID"] == parent["spanID"]
               for ref in span.get("references", []))


def verify(traces):
    ancestry = False
    retry = False
    failed = False
    for trace in traces:
        spans = trace["spans"]
        processes = trace["processes"]
        scheduler = [span for span in spans
                     if processes[span["processID"]]["serviceName"] == "orchestrator-scheduler"]
        worker = [span for span in spans
                  if processes[span["processID"]]["serviceName"] == "orchestrator-worker"]
        loads = [span for span in scheduler if span["operationName"] == "load"]
        persistence = [span for span in worker if span["operationName"] == "pipeline.persist_sales"]
        inserts = [span for span in worker if span["operationName"] == "postgresql.insert"]
        ancestry |= any(parent_is(package, task)
                        and any(parent_is(sql, package) and attribute(sql, "db.operation") == "INSERT"
                                and "ON CONFLICT" in attribute(sql, "db.statement") for sql in inserts)
                        and attribute(package, "airflow.dag_id") == "demo_ingest"
                        and attribute(package, "airflow.task_id") == "load"
                        for task in loads for package in persistence)
        retry |= any(attribute(package, "airflow.task_attempt") == 2 for package in persistence)
        failed |= any(span["operationName"] == "pipeline.persist_report"
                      and attribute(span, "otel.status_code") == "ERROR"
                      and any(field["key"] == "exception.type" and field["value"] == "RuntimeError"
                              for event in span.get("logs", []) for field in event["fields"])
                      and any(parent_is(span, task) for task in scheduler if task["operationName"] == "publish")
                      for span in worker)
    return ancestry, retry, failed


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:11070"
    deadline = time.monotonic() + 30
    while True:
        result = verify(fetch(root))
        if all(result):
            print("Verified scheduler-to-worker ancestry, SQL child spans, retry attributes, and an exported exception")
            break
        if time.monotonic() >= deadline:
            raise AssertionError(f"Missing trace evidence: ancestry={result[0]}, retry={result[1]}, failure={result[2]}")
        time.sleep(1)
