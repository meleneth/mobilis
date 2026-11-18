"""Small diagnostic endpoint for the standalone verifier, using keyed CQL reads."""
from fastapi import HTTPException
from cassandra import OperationTimedOut, ReadTimeout, Unavailable, WriteTimeout
from cassandra.cluster import NoHostAvailable
from .cassandra_client import execute


def register(app):
    @app.get("/records/{application_id}")
    def record(application_id: str):
        try:
            row = execute("select", "SELECT application_id, correlation_id, activity, outcome, reason, message_id "
                          "FROM decisions WHERE application_id = %s", (application_id,)).one()
        except (NoHostAvailable, OperationTimedOut, ReadTimeout, Unavailable, WriteTimeout) as error:
            raise HTTPException(status_code=503, detail="Cassandra lookup unavailable") from error
        if row is None:
            raise HTTPException(status_code=404, detail="Decision not recorded")
        return dict(row._asdict())
