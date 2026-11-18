#!/usr/bin/env python3
"""Verify cross-service ancestry and SQL spans in a collector-connected run."""
import json
import time
from urllib.request import urlopen


def coherent_trace(trace):
    processes = trace["processes"]
    spans = trace["spans"]
    services = {processes[span["processID"]]["serviceName"] for span in spans}
    if not {"gateway", "sites", "deployments"}.issubset(services):
        return False
    gateway_ids = {span["spanID"] for span in spans
                   if processes[span["processID"]]["serviceName"] == "gateway"}
    for service in ("sites", "deployments"):
        http_spans = [span for span in spans
                      if processes[span["processID"]]["serviceName"] == service
                      and span["operationName"] == "POST /graphql"]
        if not any(any(ref["spanID"] in gateway_ids for ref in span["references"])
                   for span in http_spans):
            return False
        if not any(span["operationName"].startswith("SELECT ")
                   and processes[span["processID"]]["serviceName"] == service
                   for span in spans):
            return False
    return True


for _ in range(30):
    with urlopen("http://trace-viewer:16686/api/traces?service=gateway&limit=20", timeout=5) as response:
        traces = json.load(response)["data"]
    if any(coherent_trace(trace) for trace in traces):
        print("Gateway, subgraph HTTP ancestry, and both SQL spans verified in one trace")
        break
    time.sleep(1)
else:
    raise AssertionError("No coherent gateway -> Sites/Deployments -> SQL trace reached Jaeger")
