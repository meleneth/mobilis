"""One deterministic bilateral execution per accepted command.

All commands for a commodity use that commodity as Kafka key, so their order is
the order of their single assigned partition. There is no cross-market order.
"""

import json
import os
import signal
import threading

from prometheus_client import Counter, start_http_server

from .kafka_client import consume, publish
from .telemetry import configure


processed = Counter("exchange_commands_processed_total", "Commands processed by matching")
stop = threading.Event()


def match(command, message):
    if command["commodity"] != message.key.decode():
        raise ValueError("Commodity and partition key disagree")
    if int(command["quantity"]) <= 0 or int(command["price_cents"]) <= 0:
        raise ValueError("Invalid command in log")
    execution = {
        "execution_id": command["command_id"],
        "command_id": command["command_id"],
        "commodity": command["commodity"],
        "buyer": command["buyer"], "seller": command["seller"],
        "quantity": int(command["quantity"]), "price_cents": int(command["price_cents"]),
        "source_partition": message.partition, "source_offset": message.offset,
    }
    publish("exchange.executions", command["commodity"], execution,
            headers={"execution-id": execution["execution_id"]})
    processed.inc()
    print(json.dumps({"execution": execution}, sort_keys=True), flush=True)


def main():
    provider = configure()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    start_http_server(int(os.getenv("METRICS_PORT", "9000")))
    try:
        consume("exchange.commands", "matching-v1", match, stop)
    finally:
        provider.shutdown()


if __name__ == "__main__":
    main()
