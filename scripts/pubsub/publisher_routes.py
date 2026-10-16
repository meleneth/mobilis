from fastapi import HTTPException
from pydantic import BaseModel
from .pubsub_client import publish


class Event(BaseModel):
    value: str


def register(app):
    @app.post("/publish")
    def send(event: Event):
        try:
            identity = publish("requests", event.value.encode("utf-8"))
        except Exception as error:
            raise HTTPException(status_code=503, detail="Pub/Sub publisher unavailable") from error
        return {"message_id": identity}
