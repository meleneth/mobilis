"""Durable market projection. Redis is refreshed only from committed SQL state."""

import json
import os
import signal
import threading

import redis
from prometheus_client import Counter, Gauge, start_http_server
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from .kafka_client import consume
from .database import get_engine
from .telemetry import configure


processed = Counter("exchange_market_events_processed_total", "Market events processed")
replay_position = Gauge("exchange_market_last_offset", "Last processed offset", ["partition"])
stop = threading.Event()


def schema():
    with get_engine().begin() as connection:
        connection.execute(text("""CREATE TABLE IF NOT EXISTS processed_executions (
            execution_id text PRIMARY KEY)"""))
        connection.execute(text("""CREATE TABLE IF NOT EXISTS market_state (
            commodity text PRIMARY KEY, price_cents bigint NOT NULL,
            volume bigint NOT NULL, trade_count bigint NOT NULL)"""))


def apply(event, message):
    with get_engine().begin() as connection:
        inserted = connection.execute(
            text("INSERT INTO processed_executions(execution_id) VALUES (:id) ON CONFLICT DO NOTHING RETURNING execution_id"),
            {"id": event["execution_id"]}).first()
        if inserted is None:
            return
        connection.execute(text("""INSERT INTO market_state(commodity, price_cents, volume, trade_count)
            VALUES (:commodity, :price, :quantity, 1)
            ON CONFLICT (commodity) DO UPDATE SET
              price_cents=EXCLUDED.price_cents,
              volume=market_state.volume+EXCLUDED.volume,
              trade_count=market_state.trade_count+1"""),
            {"commodity": event["commodity"], "price": int(event["price_cents"]),
             "quantity": int(event["quantity"])})
    processed.inc()
    replay_position.labels(partition=str(message.partition)).set(message.offset)
    # A cache failure cannot roll back an already committed event. Reads rebuild it.
    try:
        cache = redis.from_url(os.environ["LEADERBOARD_URL"], socket_timeout=2)
        with get_engine().connect() as connection:
            rows = connection.execute(text("SELECT commodity, volume FROM market_state"))
            cache.zadd("exchange:volume", {name: volume for name, volume in rows})
    except (redis.RedisError, SQLAlchemyError, OSError) as error:
        print(json.dumps({"cache_refresh_error": str(error)}), flush=True)


def main():
    provider = configure(get_engine())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    schema()
    start_http_server(int(os.getenv("METRICS_PORT", "9000")))
    try:
        consume("exchange.executions", "market-v1", apply, stop)
    finally:
        provider.shutdown()


if __name__ == "__main__":
    main()
