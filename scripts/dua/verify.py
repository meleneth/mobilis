#!/usr/bin/env python3
"""Execute and verify the real generated DUA system from the Applications container."""
import json
import os
import sys
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from sqlalchemy import select
from service_applications.database import get_session
from service_applications.models import ApplicationRecord
from service_applications.pubsub_client import publish

GATEWAY = "http://gateway:5000/graphql"
CASES = [
    ("DEPLOY_RUBBER_DUCK", "Morale improvement", None, "APPROVED", "Rubber duck deployment improves morale without a committee."),
    ("SECOND_COFFEE", "The first was too procedural", None, "DENIED", "Form C-2 for a second coffee was not attached."),
    ("RENAME_PRODUCTION_SERVER", "Consistent naming", "production-final-final", "DENIED", "Production server names containing final are prohibited by the Naming Office."),
    ("FRIDAY_DEPENDENCY", "Scheduling clarity", None, "APPROVED_WITH_WARNING", "Friday may be a dependency, but cannot be pinned in production."),
]


def read_json(url, payload=None):
    request = Request(url, data=json.dumps(payload).encode() if payload is not None else None,
                      headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=15) as response:
        return json.load(response)


def graphql(document, variables=None, url=GATEWAY):
    result = read_json(url, {"query": document, "variables": variables or {}})
    if result.get("errors"):
        raise AssertionError(f"GraphQL errors from {url}: {result['errors']}")
    return result["data"]


def processing():
    return read_json("http://bureaucrat:8080/processing")


def poll(predicate, description, seconds=90):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        try:
            last = predicate()
            if last:
                return last
        except (HTTPError, OSError, AssertionError) as error:
            last = str(error)
        time.sleep(0.5)
    raise AssertionError(f"Timed out waiting for {description}; last={last}; worker={processing()}")


def application_query(identity):
    return graphql("query($id: ID!) { application(id: $id) { id activity justification targetName correlationId status decision { outcome reason } } }",
                   {"id": identity})["application"]


def verify(records, minimum_counts=None):
    for record in records:
        identity = record["id"]
        with get_session() as session:
            persisted = session.scalar(select(ApplicationRecord).where(ApplicationRecord.id == identity))
            assert persisted is not None, f"PostgreSQL is missing {identity}"
            assert persisted.correlation_id == record["correlation_id"]
            assert persisted.target_name == record["target_name"]
        def complete():
            result = application_query(identity)
            return result if result and result["decision"] else None
        result = poll(complete, f"federated decision for {identity}")
        assert result["id"] == identity and result["activity"] == record["activity"], result
        assert result["justification"] == record["justification"], result
        assert result["targetName"] == record["target_name"], result
        assert result["correlationId"] == record["correlation_id"], result
        assert result["status"] == record["outcome"], result
        assert result["decision"] == {"outcome": record["outcome"], "reason": record["reason"]}, result
        # This _entities query proves Decisions resolves the Application federation key.
        entities = graphql(
            'query($id: ID!) { _entities(representations: [{__typename: "Application", id: $id}]) { ... on Application { id status decision { outcome reason } } } }',
            {"id": identity}, url="http://decisions:8000/graphql")
        assert entities["_entities"][0]["decision"] == result["decision"], entities
        # Native Cassandra client in Decisions reads the authoritative keyed row.
        row = read_json(f"http://decisions:8000/records/{identity}")
        assert row["application_id"] == identity and row["correlation_id"] == record["correlation_id"], row
        assert row["outcome"] == record["outcome"] and row["reason"] == record["reason"], row
        assert row["message_id"], row
    if minimum_counts:
        counts = poll(lambda: processing() if all(processing()[key] >= value for key, value in minimum_counts.items()) else None,
                      f"worker acknowledgment counters {minimum_counts}")
        assert counts["acknowledged"] >= counts["inserted"] + counts["duplicates"], counts
    print(f"Verified {len(records)} PostgreSQL applications, federated decisions, keyed Cassandra rows and worker acknowledgments", file=sys.stderr)


def exercise():
    before = processing()
    records = []
    for activity, justification, target_name, outcome, reason in CASES:
        result = graphql(
            "mutation($activity: String!, $justification: String!, $targetName: String) { requestApproval(activity: $activity, justification: $justification, targetName: $targetName) { id activity justification targetName correlationId status } }",
            {"activity": activity, "justification": justification, "targetName": target_name})["requestApproval"]
        assert result["id"] and result["correlationId"], result
        assert result["status"] in ("PENDING", outcome), result
        records.append({"id": result["id"], "correlation_id": result["correlationId"],
                        "activity": activity, "justification": justification, "target_name": target_name,
                        "outcome": outcome, "reason": reason})
    verify(records, {"inserted": before["inserted"] + len(records)})
    duplicate = records[0]
    original_message_id = read_json(f"http://decisions:8000/records/{duplicate['id']}")["message_id"]
    event = {"version": 1, "application_id": duplicate["id"], "correlation_id": duplicate["correlation_id"],
             "activity": duplicate["activity"], "justification": duplicate["justification"],
             "target_name": duplicate["target_name"]}
    publish("applications", json.dumps(event).encode(), {"correlation_id": duplicate["correlation_id"]})
    publish("applications", b'{"version": 99}', {})
    poll(lambda: processing() if processing()["duplicates"] >= before["duplicates"] + 1
         and processing()["malformed"] >= before["malformed"] + 1 else None,
         "duplicate suppression and terminal malformed acknowledgment")
    verify(records)
    assert read_json(f"http://decisions:8000/records/{duplicate['id']}")["message_id"] == original_message_id, \
        "Duplicate delivery replaced the authoritative Cassandra decision"
    assert processing()["acknowledged"] >= before["acknowledged"] + len(records) + 2
    print(json.dumps(records))


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["exercise"]:
            exercise()
        elif sys.argv[1:] == ["verify"]:
            verify(json.load(sys.stdin))
        else:
            raise SystemExit("usage: verify.py exercise|verify")
    except Exception as error:
        print(f"DUA verification failed: {error}", file=sys.stderr)
        raise
