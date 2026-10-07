"""The demo's database collaborator and semantic effect representation."""
import json
import re
from sqlalchemy import event, select, text
from sqlalchemy.engine import Engine
from opentelemetry import trace
from .database import get_session
from .models import Item


@event.listens_for(Engine, "after_cursor_execute")
def record_executed_sql(connection, cursor, statement, parameters, context, executemany):
    # Observe the driver's real SQL and bindings, rather than a business-logic
    # description that could remain unchanged when the ORM query drifts.
    if re.fullmatch(r"\s*(?:(?:BEGIN|COMMIT|ROLLBACK)|SET\s+LOCAL\s+application_name\s*=\s*'(?:legacy|candidate)')\s*;?\s*",
                    statement, flags=re.IGNORECASE):
        return
    with trace.get_tracer("items").start_as_current_span("items.sql") as span:
        span.set_attributes({"demo.sql.text": statement,
                             "demo.sql.parameters": json.dumps(parameters),
                             "demo.sql.executed": True,
                             "demo.sql.executemany": executemany})


def determine_effect(value):
    return {"operation": "insert", "table": "items", "values": dict(value)}


def effect_attributes(effect, *, shadow, committed):
    return {"demo.write.mode": "shadow" if shadow else "actual",
            "demo.request.shadow": shadow, "demo.write.committed": committed,
            "db.operation.name": "INSERT", "db.collection.name": "items",
            "demo.write.effect": json.dumps(effect, sort_keys=True)}


class ItemStore:
    def __init__(self, sessions=get_session):
        self.sessions = sessions

    def list_items(self):
        with self.sessions() as session:
            return [{"id": item.id, "name": item.name}
                    for item in session.scalars(select(Item).order_by(Item.id))]

    def commit(self, effect):
        with self.sessions() as session:
            try:
                session.execute(text("SET LOCAL application_name = 'legacy'"))
                session.add(Item(**effect["values"]))
                session.commit()
            except Exception:
                session.rollback()
                raise


def get_item_store():
    return ItemStore()
