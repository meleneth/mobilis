"""The demo's database collaborator and semantic effect representation."""
import json
from sqlalchemy import select, text
from .database import get_session
from .models import Item


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
