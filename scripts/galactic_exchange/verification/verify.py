#!/usr/bin/env python3
"""Run against a freshly generated Galactic Exchange project and Docker daemon."""

import hashlib
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
import uuid


COMPOSE = ["docker", "compose", "--env-file", "development.env", "-f", "development-compose.yml",
           "-f", "development-overrides.yml", "-f", "galactic-exchange.compose.yml"]


def run(*args, input_text=None, check=True):
    result = subprocess.run([*COMPOSE, *args], input=input_text, text=True, capture_output=True, check=False)
    if check and result.returncode:
        raise RuntimeError(f"compose {' '.join(args)} failed: {result.stderr}\n{result.stdout}")
    return result.stdout


def env_value(key):
    for line in open("development.env", encoding="utf-8"):
        if line.startswith(key + "="):
            return line.partition("=")[2].strip().strip('"')
    raise KeyError(key)


def request(method, url, value=None):
    data = json.dumps(value).encode() if value is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as response:
        return response.status, json.load(response)


def wait_for(label, predicate, seconds=180):
    until = time.monotonic() + seconds
    last = None
    while time.monotonic() < until:
        try:
            value = predicate()
            if value:
                print(f"verified: {label}", flush=True)
                return value
        except (OSError, urllib.error.URLError, RuntimeError, ValueError) as error:
            last = error
        time.sleep(2)
    raise AssertionError(f"timed out waiting for {label}: {last}")


def positions(database="portfolio-db"):
    sql = "SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.account,p.commodity),'[]'::json) FROM (SELECT account,commodity,quantity FROM positions) p"
    out = run("exec", "-T", database, "sh", "-lc",
              f'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "{sql}"')
    return json.loads(out.strip())


def processed(database="portfolio-db"):
    out = run("exec", "-T", database, "sh", "-lc",
              'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c "SELECT count(*) FROM processed_executions"')
    return int(out.strip())


def executions(count):
    out = run("exec", "-T", "events", "/opt/kafka/bin/kafka-console-consumer.sh",
              "--bootstrap-server", "localhost:9092", "--topic", "exchange.executions",
              "--from-beginning", "--max-messages", str(count), "--timeout-ms", "30000")
    return [json.loads(line) for line in out.splitlines() if line.startswith("{")]


def lag(group):
    output = run("exec", "-T", "events", "/opt/kafka/bin/kafka-consumer-groups.sh",
                 "--bootstrap-server", "localhost:9092", "--describe", "--group", group)
    values = []
    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 6 and parts[0] == group and parts[5].isdigit():
            values.append(int(parts[5]))
    return sum(values)


def expected_state(commands):
    quantities = {}
    markets = {}
    for command in commands:
        commodity = command["commodity"]
        for account, sign in ((command["buyer"], 1), (command["seller"], -1)):
            key = (account, commodity)
            quantities[key] = quantities.get(key, 0) + sign * command["quantity"]
        market = markets.setdefault(commodity, {"commodity": commodity, "price_cents": 0,
                                                 "volume": 0, "trade_count": 0})
        market["price_cents"] = command["price_cents"]
        market["volume"] += command["quantity"]
        market["trade_count"] += 1
    return ([{"account": account, "commodity": commodity, "quantity": quantity}
             for (account, commodity), quantity in sorted(quantities.items())],
            [markets[key] for key in sorted(markets)])


def main():
    run("up", "-d", "--build")
    trading = "http://127.0.0.1:" + env_value("TRADING_API_WEB_PORT")
    market = "http://127.0.0.1:" + env_value("MARKET_WEB_PORT")
    portfolio = "http://127.0.0.1:" + env_value("PORTFOLIO_WEB_PORT")
    for name, url in (("trading API", trading), ("market API", market), ("portfolio API", portfolio)):
        wait_for(name, lambda url=url: request("GET", url + "/health")[0] == 200)

    commands = [
        {"idempotency_key": "water-0001", "commodity": "Martian Water", "buyer": "Aster", "seller": "Boreal", "quantity": 8, "price_cents": 1250},
        {"idempotency_key": "ice-000001", "commodity": "Europa Ice", "buyer": "Boreal", "seller": "Cygnus", "quantity": 3, "price_cents": 2100},
        {"idempotency_key": "water-0002", "commodity": "Martian Water", "buyer": "Cygnus", "seller": "Aster", "quantity": 2, "price_cents": 1300},
        {"idempotency_key": "methane01", "commodity": "Titan Methane", "buyer": "Aster", "seller": "Cygnus", "quantity": 5, "price_cents": 900},
        {"idempotency_key": "helium0001", "commodity": "Lunar Helium-3", "buyer": "Boreal", "seller": "Aster", "quantity": 1, "price_cents": 9000},
        {"idempotency_key": "sulfur0001", "commodity": "Venusian Sulfur", "buyer": "Cygnus", "seller": "Boreal", "quantity": 7, "price_cents": 450},
    ]
    accepted = []
    for command in commands[:3]:
        status, result = request("POST", trading + "/trades", command)
        assert status == 202 and result["status"] == "accepted"
        assert result["command_id"] == hashlib.sha256(command["idempotency_key"].encode()).hexdigest()
        accepted.append(result)
    assert request("POST", trading + "/trades", commands[0]) == (202, accepted[0])
    print("verified: command idempotency and broker acknowledgment", flush=True)
    first_positions, first_markets = expected_state(commands[:3])
    wait_for("first portfolio projection", lambda: positions() == first_positions)
    wait_for("first market projection", lambda: request("GET", market + "/markets")[1] == first_markets)

    run("stop", "portfolio-consumer")
    for command in commands[3:]:
        status, result = request("POST", trading + "/trades", command)
        assert status == 202 and result["status"] == "accepted"
    final_positions, final_markets = expected_state(commands)
    wait_for("market advances while portfolio is stopped", lambda: request("GET", market + "/markets")[1] == final_markets)
    assert positions() == first_positions
    # Kafka's group tool may omit partitions with no committed offset yet.
    wait_for("portfolio consumer lag", lambda: lag("portfolio-v1") > 0)
    run("start", "portfolio-consumer")
    wait_for("portfolio catches up", lambda: positions() == final_positions)
    wait_for("portfolio processed count", lambda: processed() == len(commands))
    wait_for("portfolio lag clears", lambda: lag("portfolio-v1") == 0)

    events = executions(len(commands))
    ids = [event["execution_id"] for event in events]
    expected_ids = [hashlib.sha256(command["idempotency_key"].encode()).hexdigest() for command in commands]
    assert sorted(ids) == sorted(expected_ids), (ids, expected_ids)
    for commodity in {command["commodity"] for command in commands}:
        market_events = [event for event in events if event["commodity"] == commodity]
        expected_sequence = [hashlib.sha256(command["idempotency_key"].encode()).hexdigest()
                             for command in commands if command["commodity"] == commodity]
        assert [event["command_id"] for event in market_events] == expected_sequence
        offsets = [event["source_offset"] for event in market_events]
        assert offsets == sorted(offsets), (commodity, offsets)
    print("verified: execution IDs and per-market command order", flush=True)

    # The replay database has no projection tables or state before this new group starts.
    run("exec", "-T", "portfolio-replay-db", "sh", "-lc",
        'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "DROP TABLE IF EXISTS positions, processed_executions, schema_migrations, ar_internal_metadata CASCADE"')
    group = "portfolio-replay-" + uuid.uuid4().hex[:12]
    run("run", "-d", "--name", group, "-e", "PORTFOLIO_GROUP_ID=" + group,
        "-e", "MOBILIS_KAFKA_SUBSCRIPTIONS=exchange.executions:" + group,
        "portfolio-replay-consumer")
    try:
        wait_for("fresh replay matches original", lambda: positions("portfolio-replay-db") == final_positions)
        assert processed("portfolio-replay-db") == len(commands)
    finally:
        subprocess.run(["docker", "stop", group], check=False, capture_output=True)
        subprocess.run(["docker", "rm", group], check=False, capture_output=True)

    duplicate = events[0]
    run("exec", "-T", "events", "/opt/kafka/bin/kafka-console-producer.sh",
        "--bootstrap-server", "localhost:9092", "--topic", "exchange.executions",
        "--property", "parse.key=true", "--property", "key.separator=|",
        input_text=duplicate["commodity"] + "|" + json.dumps(duplicate, separators=(",", ":")) + "\n")
    wait_for("duplicate delivery consumed", lambda: lag("portfolio-v1") == 0 and lag("market-v1") == 0)
    assert positions() == final_positions
    assert processed() == len(commands)
    assert request("GET", market + "/markets")[1] == final_markets
    assert request("GET", market + "/leaderboard")[1] == [
        {"commodity": item["commodity"], "volume": item["volume"]}
        for item in sorted(final_markets, key=lambda item: (-item["volume"], item["commodity"]))]
    print("verified: duplicate delivery leaves both projections unchanged", flush=True)
    prometheus = "http://127.0.0.1:" + env_value("PROMETHEUS_WEB_PORT")
    jaeger = "http://127.0.0.1:" + env_value("JAEGER_WEB_PORT")
    wait_for("matching throughput metric", lambda: any(
        float(row["value"][1]) >= len(commands) for row in
        request("GET", prometheus + "/api/v1/query?query=exchange_commands_processed_total")[1]["data"]["result"]))
    wait_for("trace context linked across Kafka", lambda: any(
        reference["refType"] == "FOLLOWS_FROM"
        for item in request("GET", jaeger + "/api/traces?service=matching-worker&limit=20")[1]["data"]
        for span in item["spans"] if span["operationName"] == "kafka process"
        for reference in span["references"]))
    wait_for("HTTP ingress and producer trace", lambda: any(
        {"http", "kafka publish"}.issubset({span["operationName"] for span in item["spans"]})
        for item in request("GET", jaeger + "/api/traces?service=trading-api&limit=20")[1]["data"]))
    for service in ("portfolio", "market-worker"):
        wait_for(service + " consumer and database trace", lambda service=service: any(
            any(span["operationName"] == "kafka process" and any(
                ref["refType"] == "FOLLOWS_FROM" for ref in span["references"])
                for span in item["spans"])
            and any(any(tag["key"] == "db.system" and tag["value"] == "postgresql"
                        for tag in span["tags"]) for span in item["spans"])
            for item in request("GET", jaeger + "/api/traces?service=" + service
                                + "&operation=kafka%20process&limit=20")[1]["data"]))
    print("GALACTIC EXCHANGE VERIFIED", flush=True)


if __name__ == "__main__":
    main()
