from fastapi import HTTPException
from pydantic import BaseModel
from uuid import uuid4
from .cassandra_client import execute


class Record(BaseModel):
    note: str


def register(app):
    @app.post("/records")
    def create(record: Record):
        identity = uuid4()
        try:
            execute("insert", "INSERT INTO records (id, note) VALUES (%s, %s)", (identity, record.note))
        except Exception as error:
            raise HTTPException(status_code=503, detail="Cassandra write unavailable") from error
        return {"id": str(identity), "note": record.note}

    @app.get("/records/{identity}")
    def read(identity: str):
        from uuid import UUID
        try:
            row = execute("select", "SELECT note FROM records WHERE id = %s", (UUID(identity),)).one()
        except ValueError as error:
            raise HTTPException(status_code=400, detail="Invalid record ID") from error
        except Exception as error:
            raise HTTPException(status_code=503, detail="Cassandra read unavailable") from error
        if row is None:
            raise HTTPException(status_code=404, detail="Record not found")
        return {"id": identity, "note": row.note}
