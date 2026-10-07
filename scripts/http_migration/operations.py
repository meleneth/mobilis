"""Generated-project operations. Runs in the application's ordinary Python image."""
import argparse
import json
from pathlib import Path
import random
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from sqlalchemy import text
from service_legacy.database import engine
from service_legacy.models import Base

GATEWAY = "http://gateway:8080"
ADMIN = "http://gateway:9901"
JAEGER = "http://trace-viewer:16686"


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def http(url, value=None, trace_id=None, raw=None):
    headers = {}
    if trace_id:
        headers["traceparent"] = f"00-{trace_id}-0123456789abcdef-01"
    data = raw if raw is not None else (json.dumps(value).encode() if value is not None else None)
    if data is not None:
        headers["Content-Type"] = "application/json"
    try:
        response = urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read()
        try:
            payload = json.loads(body) if body else None
        except ValueError:
            payload = body.decode("utf-8", errors="replace")
        return response.status, {key.lower(): value for key, value in response.headers.items()}, payload


def get(url):
    status, _, body = http(url)
    require(status == 200, (url, status, body))
    return body


def state():
    defaults = json.loads(Path(__file__).with_name("initial-state.json").read_text())
    entries = get(ADMIN + "/runtime")["entries"]
    def value(key, default):
        return int(entries.get(key, {}).get("final_value", default))
    mirror = value("migration.mirror", defaults["mirror"])
    candidate = value("migration.authority.candidate", defaults["candidate"])
    legacy = value("migration.authority.legacy", 100 - defaults["candidate"])
    require(legacy + candidate == 100, "Authoritative weights must total 100")
    return mirror, candidate


def ready(services):
    urls = {"legacy": "http://legacy:8000", "candidate": "http://candidate:8080",
            "candidate-shadow": "http://candidate-shadow:8080", "gateway": GATEWAY}
    for name in services:
        deadline = time.monotonic() + 30
        while True:
            try:
                if get(urls[name] + "/health") == {"status": "ok"}:
                    break
            except (urllib.error.URLError, AssertionError):
                pass
            require(time.monotonic() < deadline, f"{name} did not become ready")
            time.sleep(0.2)


def migration(mirror, candidate):
    require(0 <= mirror <= 100 and 0 <= candidate <= 100, "Percentages must be 0..100")
    services = (["legacy"] if candidate < 100 else []) + (["candidate"] if candidate > 0 else [])
    if mirror > 0:
        services.append("candidate-shadow")
    ready(services)
    form = urllib.parse.urlencode({"migration.mirror": mirror,
                                  "migration.authority.legacy": 100 - candidate,
                                  "migration.authority.candidate": candidate}).encode()
    request = urllib.request.Request(ADMIN + "/runtime_modify", data=form)
    with urllib.request.urlopen(request, timeout=10) as response:
        require(response.status == 200, "Envoy rejected runtime update")
    require(state() == (mirror, candidate), "Envoy runtime values did not change")
    print(f"Envoy adopted mirror={mirror}% candidate authority={candidate}%", flush=True)
    routing(mirror, candidate)


def shadow_count():
    stats = get(ADMIN + "/stats?format=json&filter=upstream_rq_total")["stats"]
    return sum(s["value"] for s in stats if s["name"] == "cluster.candidate-shadow.upstream_rq_total")


def routing(mirror, candidate):
    before = shadow_count()
    counts = {"legacy": 0, "candidate": 0}
    samples = 1000 if candidate in (1, 99) or mirror in (1, 99) else 120
    for _ in range(samples):
        status, headers, _ = http(GATEWAY + "/items")
        require(status == 200, ("routing probe failed", status))
        backend = headers.get("x-served-by")
        require(backend in counts, ("missing authority header", headers))
        counts[backend] += 1
    if candidate == 0:
        require(counts["candidate"] == 0, counts)
    elif candidate == 100:
        require(counts["legacy"] == 0, counts)
    else:
        require(all(counts.values()), ("split not observed", counts))
        # A broad statistical guard detects reversed/incorrect weights without claiming exact counts.
        observed = counts["candidate"] / samples
        require(abs(observed - candidate / 100) < 0.20, ("unexpected split", counts))
    deadline = time.monotonic() + 10
    while True:
        mirrored = shadow_count() - before
        if mirror != 100 or mirrored >= samples or time.monotonic() >= deadline:
            break
        time.sleep(0.2)
    if mirror == 0:
        require(mirrored == 0, ("unexpected mirroring", mirrored))
    elif mirror == 100:
        require(mirrored == samples, ("not every request mirrored", mirrored, samples))
    else:
        require(0 < mirrored < samples and abs(mirrored / samples - mirror / 100) < 0.20,
                ("unexpected mirror fraction", mirrored, samples, mirror))
    print(f"Observed routing: {counts}; shadow sends={mirrored}/{samples}", flush=True)


def seed():
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(text("""
            CREATE TABLE IF NOT EXISTS item_effects (
                sequence bigserial PRIMARY KEY, writer text NOT NULL, effect jsonb NOT NULL);
            CREATE OR REPLACE FUNCTION record_item_effect() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
                INSERT INTO item_effects(writer, effect) VALUES
                (current_setting('application_name'), jsonb_build_object(
                    'operation', 'insert', 'table', 'items',
                    'values', jsonb_build_object('id', NEW.id, 'name', NEW.name)));
                RETURN NEW;
            END $$;
            DROP TRIGGER IF EXISTS item_effect ON items;
            CREATE TRIGGER item_effect AFTER INSERT ON items FOR EACH ROW EXECUTE FUNCTION record_item_effect();
            TRUNCATE items, item_effects RESTART IDENTITY;
            INSERT INTO items(id, name) VALUES (1, 'example');
            TRUNCATE item_effects RESTART IDENTITY;
        """))
    print("Reset schema, items=[{id: 1, name: example}], and write audit", flush=True)


def snapshot():
    with engine.connect() as connection:
        items = [dict(row._mapping) for row in connection.execute(text("SELECT id, name FROM items ORDER BY id"))]
        effects = [dict(row._mapping) for row in connection.execute(text("SELECT sequence, writer, effect FROM item_effects ORDER BY sequence"))]
    return items, effects


def new_item():
    items, _ = snapshot()
    used = {item["id"] for item in items}
    while True:
        item_id = random.randint(2, 2147483647)
        if item_id not in used:
            return {"id": item_id, "name": "demo_" + uuid.uuid4().hex}


def exercise():
    require(get(GATEWAY + "/health") == {"status": "ok"}, "health contract")
    before = get(GATEWAY + "/items")
    value = new_item()
    status, headers, body = http(GATEWAY + "/items", value)
    require(status == 201 and body == value, (status, body))
    after = get(GATEWAY + "/items")
    require(after == sorted(before + [value], key=lambda item: item["id"]), "read-after-write mismatch")
    print(f"Health OK; read {len(before)}; created {value} via {headers['x-served-by']}; read {len(after)}", flush=True)


def tags(span):
    return {tag["key"]: tag["value"] for tag in span.get("tags", [])}


def service(trace, span):
    return trace["processes"][span["processID"]]["serviceName"]


def query_spans(spans):
    return [span for span in spans if not span["operationName"].startswith("prepare ") and any(
        key in {"db.statement", "db.query.text"} and "items" in str(value).lower()
        for key, value in tags(span).items())]


def unique_spans(trace):
    # Jaeger can return repeated delivery/query copies of the same logical span.
    # Ignore only Jaeger's diagnostic metadata; conflicting evidence is an error.
    result = {}
    signatures = {}
    for span in trace["spans"]:
        identity = span["spanID"]
        signature = {key: span.get(key) for key in
                     ("traceID", "operationName", "references", "startTime", "duration", "logs")}
        signature["service"] = service(trace, span)
        signature["tags"] = {key: value for key, value in tags(span).items()
                             if not key.startswith("@jaeger@")}
        if identity in signatures:
            require(signature == signatures[identity], ("conflicting duplicate span evidence", identity))
        else:
            signatures[identity] = signature
            result[identity] = span
    return list(result.values())


def check_trace(trace, expected, write, value=None, authority=None):
    spans = unique_spans(trace)
    by_id = {span["spanID"]: span for span in spans}
    for name in expected:
        local = [span for span in spans if service(trace, span) == name]
        servers = [span for span in local if tags(span).get("span.kind") == "server"]
        require(len(servers) == 1, (name, "expected one HTTP server", servers))
        parents = [ref["spanID"] for ref in servers[0]["references"] if ref["refType"] == "CHILD_OF"]
        require(any(parent in by_id and service(trace, by_id[parent]) == "gateway" for parent in parents), (name, "Envoy parent missing", parents))
        queries = query_spans(local)
        require(len(queries) == (0 if write and name == "candidate-shadow" else 1), (name, "unexpected item DB spans", queries))
        effects = []
        if write:
            effects = [span for span in local if "demo.write.effect" in tags(span)]
            require(len(effects) == 1, (name, "missing/duplicate effect", effects))
            effect_span = effects[0]
            attrs = tags(effect_span)
            mode = "shadow" if name == "candidate-shadow" else "actual"
            require(attrs.get("demo.write.mode") == mode, (name, "wrong write mode", attrs))
            require(attrs.get("db.operation.name") == "INSERT" and attrs.get("db.collection.name") == "items", attrs)
            require(json.loads(attrs["demo.write.effect"]) == {"operation": "insert", "table": "items", "values": value}, (name, "semantic effect mismatch", attrs))
        # SQL and effect evidence must descend from this service's request span.
        for span in queries + effects:
            current = span
            seen = set()
            while current["spanID"] != servers[0]["spanID"]:
                require(current["spanID"] not in seen, "cycle in span ancestry")
                seen.add(current["spanID"])
                parent = next((ref["spanID"] for ref in current["references"] if ref["refType"] == "CHILD_OF"), None)
                require(parent in by_id, (name, "disconnected evidence", span))
                current = by_id[parent]
    actual_backends = {service(trace, span) for span in spans if tags(span).get("span.kind") == "server"} - {"gateway", "candidate-shadow"}
    if authority:
        require(actual_backends == {authority}, ("unexpected authoritative backend", actual_backends))


def await_trace(trace_id, expected, write=False, value=None, authority=None):
    deadline = time.monotonic() + 60
    last = "trace missing"
    while time.monotonic() < deadline:
        try:
            data = get(JAEGER + "/api/traces/" + trace_id)["data"]
            if data:
                trace = data[0]
                check_trace(trace, expected, write, value, authority)
                print(f"Trace {trace_id}: {sorted(expected)}; propagation, parentage and {'effect' if write else 'query'} evidence passed", flush=True)
                return trace
        except (urllib.error.URLError, KeyError, AssertionError) as error:
            last = str(error)
        time.sleep(1)
    raise AssertionError(f"Trace {trace_id} did not satisfy verification: {last}")


def verify_write(mirror, candidate, failure=False):
    before, audit_before = snapshot()
    value = new_item()
    trace_id = uuid.uuid4().hex
    status, headers, body = http(GATEWAY + "/items", value, trace_id)
    require(status == 201 and body == value, ("write contract", status, body))
    authority = headers.get("x-served-by")
    require(authority in {"legacy", "candidate"}, headers)
    if candidate in (0, 100):
        require(authority == ("legacy" if candidate == 0 else "candidate"), "wrong authority")
    after, audit_after = snapshot()
    require(after == sorted(before + [value], key=lambda item: item["id"]), "database mutation mismatch")
    new_effects = audit_after[len(audit_before):]
    effect = {"operation": "insert", "table": "items", "values": value}
    require(len(new_effects) == 1 and new_effects[0]["writer"] == authority and new_effects[0]["effect"] == effect,
            ("exactly one authoritative insert required; shadow must not mutate", new_effects))
    expected = {authority}
    if mirror == 100 and not failure:
        expected.add("candidate-shadow")
    await_trace(trace_id, expected, write=True, value=new_effects[0]["effect"]["values"], authority=authority)
    print(f"Write verified: DB audit ({authority}) == committed effect" + (" == independent shadow intent; zero shadow DB calls" if "candidate-shadow" in expected else ""), flush=True)


def verify(failure=False):
    mirror, candidate = state()
    if failure:
        require((mirror, candidate) == (100, 0), "failure check requires 100/0")
    else:
        routing(mirror, candidate)
    before, _ = snapshot()
    trace_id = uuid.uuid4().hex
    status, headers, body = http(GATEWAY + "/items", trace_id=trace_id)
    require(status == 200 and body == before, ("read contract", status, body))
    authority = headers["x-served-by"]
    expected = {authority}
    if mirror == 100 and not failure:
        expected.add("candidate-shadow")
    await_trace(trace_id, expected, authority=authority)
    require(get(GATEWAY + "/health") == {"status": "ok"}, "health contract")
    verify_write(mirror, candidate, failure)
    # Invalid input must not mutate DB; test actual services independently as well as the gateway.
    targets = [GATEWAY]
    if not failure:
        targets.append("http://candidate:8080")
    if candidate != 100:
        targets.append("http://legacy:8000")
    original = snapshot()
    invalid = [b'{', b'null', b'[]', b'{}', b'{"id":true,"name":"ok"}',
               b'{"id":1.0,"name":"ok"}', b'{"id":2,"name":null}',
               b'{"id":2,"name":"bad name"}', b'{"id":2147483648,"name":"ok"}',
               b'{"id":2,"name":"ok","extra":1}', b'{"id":2,"name":"ok"} {}',
               '{"id":2,"name":"ok"}'.encode("utf-16"),
               b'\xef\xbb\xbf{"id":2,"name":"ok"}']
    for target in targets:
        for raw in invalid:
            status, _, body = http(target + "/items", raw=raw)
            require((status, body) == (400, {"error": "invalid item"}), (target, raw, status, body))
        status, _, body = http(target + "/items", original[0][0])
        require((status, body) == (409, {"error": "item exists"}), (target, status, body))
        conflict = new_item()
        conflict["name"] = original[0][0]["name"]
        status, _, body = http(target + "/items", conflict)
        require((status, body) == (409, {"error": "item exists"}), (target, "duplicate name", status, body))
    require(snapshot() == original, "invalid/conflicting requests mutated DB")
    print("PASS: running HTTP/read/write/effect contracts" + (" with both candidate instances stopped" if failure else ""), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["seed", "exercise", "verify", "failure", "migration", "state", "ready"])
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    if args.operation == "migration":
        require(len(args.arguments) == 2, "usage: ./migration MIRROR_PERCENT CANDIDATE_PERCENT")
        migration(*(int(value) for value in args.arguments))
    elif args.operation == "ready":
        ready(args.arguments)
    elif args.operation == "state":
        print("%s %s" % state())
    elif args.operation == "failure":
        verify(failure=True)
    else:
        globals()[args.operation]()


if __name__ == "__main__":
    main()
