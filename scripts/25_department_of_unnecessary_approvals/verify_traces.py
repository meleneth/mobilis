#!/usr/bin/env python3
"""Correlate real gateway, database, publisher, and linked worker traces."""
import json
import sys
import time
from urllib.request import urlopen

ROOT = "http://trace-viewer:16686/api/traces"


def fetch(url):
    with urlopen(url, timeout=10) as response:
        return json.load(response)["data"]


def service(trace, span):
    return trace["processes"][span["processID"]]["serviceName"]


def tag(span, name):
    return next((item["value"] for item in span.get("tags", []) if item["key"] == name), None)


def verify(records):
    expected = {record["correlation_id"] for record in records}
    deadline = time.monotonic() + 45
    pending = set(expected)
    federated_read = False
    diagnostics = []
    while time.monotonic() < deadline:
        workers = fetch(ROOT + "?service=bureaucrat&limit=100")
        for trace in workers:
            inserts = [span for span in trace["spans"] if service(trace, span) == "bureaucrat"
                       and span["operationName"] == "cassandra.insert_decision"]
            for insert in inserts:
                correlation = tag(insert, "dua.correlation_id")
                if correlation not in pending or tag(insert, "dua.decision_inserted") is not True:
                    continue
                consumers = [span for span in trace["spans"] if span["operationName"] == "pubsub.process"
                             and service(trace, span) == "bureaucrat"]
                if not consumers:
                    continue
                consumer = consumers[0]
                links = [ref for ref in consumer.get("references", []) if ref["refType"] == "FOLLOWS_FROM"
                         and ref["traceID"] != trace["traceID"]]
                if not links:
                    diagnostics.append(f"{correlation}: worker span has no asynchronous link")
                    continue
                producer = fetch(ROOT + "/" + links[0]["traceID"])[0]
                spans = producer["spans"]
                message_id = tag(consumer, "messaging.message.id")
                if not any(span["operationName"] == "pubsub.publish" and service(producer, span) == "applications"
                           and tag(span, "messaging.message.id") == message_id for span in spans):
                    diagnostics.append(f"{correlation}: linked producer message ID differs")
                    continue
                if not any(service(producer, span) == "gateway" and span["operationName"] == "requestApproval"
                           for span in spans):
                    diagnostics.append(f"{correlation}: linked gateway mutation missing")
                    continue
                if not any(service(producer, span) == "applications" and span["operationName"] == "dua.request_approval"
                           for span in spans):
                    diagnostics.append(f"{correlation}: linked Applications resolver missing")
                    continue
                if not any(service(producer, span) == "applications" and span["operationName"].startswith("INSERT ")
                           and tag(span, "db.system") == "postgresql" for span in spans):
                    diagnostics.append(f"{correlation}: linked PostgreSQL INSERT missing")
                    continue
                pending.discard(correlation)

        gateway_traces = fetch(ROOT + "?service=gateway&limit=100")
        federated_read = any(
            any(service(trace, span) == "gateway" and span["operationName"] == "POST /graphql" for span in trace["spans"])
            and any(service(trace, span) == "applications" and span["operationName"] == "POST /graphql" for span in trace["spans"])
            and any(service(trace, span) == "decisions" and span["operationName"] == "POST /graphql" for span in trace["spans"])
            and any(service(trace, span) == "decisions" and span["operationName"] == "dua.decision_lookup" for span in trace["spans"])
            and any(service(trace, span) == "decisions" and span["operationName"] == "cassandra.select" for span in trace["spans"])
            for trace in gateway_traces)
        if not pending and federated_read:
            print(f"Verified {len(expected)} linked request-to-worker traces and a federated Cassandra lookup", file=sys.stderr)
            return
        time.sleep(1)
    raise AssertionError(f"Trace evidence incomplete: pending correlations={sorted(pending)}, "
                         f"federated_read={federated_read}, diagnostics={diagnostics[-8:]}")


if __name__ == "__main__":
    verify(json.load(sys.stdin))
