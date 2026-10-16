#!/usr/bin/env python3
"""Run from generate/: ./dc_dev run --rm publisher python demo/verify.py"""
import json
import time
from urllib.request import Request, urlopen

from service_publisher.pubsub_client import publish


def post(service, route, payload):
    request = Request(f"http://{service}:8000{route}",
                      data=json.dumps(payload).encode("utf-8"),
                      headers={"Content-Type": "application/json"}, method="POST")
    with urlopen(request, timeout=15) as response:
        return json.load(response)


def receive(service, expected, fail=False):
    for _ in range(20):
        result = post(service, "/consume", {"fail": fail})["message"]
        if result is not None:
            assert result["message_id"] == expected, (service, result, expected)
            return result
        time.sleep(0.5)
    raise AssertionError(f"No delivery to {service} for {expected}")


first = post("publisher", "/publish", {"value": "first"})["message_id"]
assert receive("alpha-one", first)["outcome"] == "acked"
assert receive("beta-worker", first)["outcome"] == "acked"

second = post("publisher", "/publish", {"value": "second"})["message_id"]
assert receive("alpha-two", second)["outcome"] == "acked"
assert receive("beta-worker", second)["outcome"] == "acked"

third = post("publisher", "/publish", {"value": "retry-me"})["message_id"]
assert receive("alpha-one", third, fail=True)["outcome"] == "nacked"
assert receive("alpha-two", third)["outcome"] == "acked"
assert receive("beta-worker", third)["outcome"] == "acked"

try:
    publish("missing-topic", b"not-published")
except ValueError as error:
    assert "missing-topic" in str(error)
else:
    raise AssertionError("Publishing to an undeclared topic must fail")

print("Pub/Sub fan-out, competing alpha consumers, ack, nack, redelivery, and missing-topic rejection verified")
