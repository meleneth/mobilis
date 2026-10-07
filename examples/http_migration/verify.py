"""Read-only smoke check against a running, seeded demo on its Compose network."""
import argparse
import json
import time
import urllib.error
import urllib.request
import uuid


def get(url, headers=None):
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers or {}), timeout=5) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--authority", choices=["legacy", "candidate"], default="legacy")
    parser.add_argument("--mirror", action="store_true")
    args = parser.parse_args()
    trace_id = uuid.uuid4().hex
    payload = get("http://gateway:8080/items", {"traceparent": f"00-{trace_id}-0123456789abcdef-01"})
    assert payload == [{"id": 1, "name": "example"}], payload
    assert get("http://gateway:8080/health") == {"status": "ok"}
    print("HTTP contract and propagated client trace request passed", flush=True)

    expected = {"gateway", args.authority}
    if args.mirror:
        expected.add("candidate")
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        try:
            traces = get(f"http://trace-viewer:16686/api/traces/{trace_id}")["data"]
            if traces:
                trace = traces[0]
                services = {p["serviceName"] for p in trace["processes"].values()}
                if expected <= services:
                    break
        except (urllib.error.URLError, KeyError):
            pass
        time.sleep(1)
    else:
        raise AssertionError(f"Missing distributed trace {trace_id}: expected {expected}")

    spans = trace["spans"]
    by_id = {span["spanID"]: span for span in spans}
    for service in expected - {"gateway"}:
        service_spans = [s for s in spans if trace["processes"][s["processID"]]["serviceName"] == service]
        queries = [s for s in service_spans if not s["operationName"].startswith("prepare ") and any(
            tag["key"] in {"db.statement", "db.query.text"} and "items" in str(tag["value"])
            for tag in s["tags"])]
        assert len(queries) == 1, (service, "expected one database query span", service_spans)
        servers = [s for s in service_spans if any(tag["key"] == "span.kind" and tag["value"] == "server" for tag in s["tags"])]
        assert len(servers) == 1, (service, "expected one HTTP server span", service_spans)
        parents = [r["spanID"] for r in servers[0]["references"] if r["refType"] == "CHILD_OF"]
        assert any(parent in by_id and trace["processes"][by_id[parent]["processID"]]["serviceName"] == "gateway" for parent in parents), parents
    print(f"Trace {trace_id}: {sorted(services)}; one HTTP and SQL span per backend, with Envoy parent", flush=True)


if __name__ == "__main__":
    main()
