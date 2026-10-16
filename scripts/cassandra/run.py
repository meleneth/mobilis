#!/usr/bin/env python3
"""Run inside the generated records container with: ./dc_dev run --rm records python demo/run.py"""
from uuid import uuid4
from service_records.cassandra_client import execute


identity = uuid4()
note = "Mobilis Cassandra round trip"
execute("insert", "INSERT INTO records (id, note) VALUES (%s, %s)", (identity, note))
row = execute("select", "SELECT note FROM records WHERE id = %s", (identity,)).one()
if row is None or row.note != note:
    raise SystemExit("Cassandra round trip failed")
print(f"Wrote and read {identity}: {row.note}")
