"""Application identity and intake belong to PostgreSQL."""
import json
from uuid import uuid4

import strawberry
from sqlalchemy import select
from starlette.concurrency import run_in_threadpool

from .models import ApplicationRecord
from .pubsub_client import publish


@strawberry.federation.type(keys=["id"])
class Application:
    id: strawberry.ID
    activity: str
    justification: str
    correlation_id: str


def as_graphql(record):
    return Application(id=record.id, activity=record.activity,
                       justification=record.justification, correlation_id=record.correlation_id)


def get_application(session, identity):
    return session.scalar(select(ApplicationRecord).where(ApplicationRecord.id == identity))


@strawberry.type
class Query:
    @strawberry.field
    async def application(self, id: strawberry.ID, info: strawberry.Info) -> Application | None:
        record = await run_in_threadpool(get_application, info.context["session"], str(id))
        return as_graphql(record) if record else None


@strawberry.type
class Mutation:
    @strawberry.mutation
    async def request_approval(self, activity: str, justification: str,
                               info: strawberry.Info) -> Application:
        if activity not in {"DEPLOY_RUBBER_DUCK", "SECOND_COFFEE", "RENAME_PRODUCTION_SERVER", "FRIDAY_DEPENDENCY"}:
            raise ValueError("Unknown activity in the Department catalogue")
        if not justification or len(justification) > 400:
            raise ValueError("Justification must contain 1 to 400 characters")
        session = info.context["session"]
        record = ApplicationRecord(id=str(uuid4()), correlation_id=str(uuid4()),
                                   activity=activity, justification=justification)

        def persist():
            try:
                session.add(record)
                session.commit()
            except Exception:
                session.rollback()
                raise

        await run_in_threadpool(persist)
        event = {"version": 1, "application_id": record.id,
                 "correlation_id": record.correlation_id, "activity": activity,
                 "justification": justification}
        # A publish failure is surfaced to the caller. PostgreSQL has already committed;
        # this simple demo deliberately does not claim an atomic dual write.
        await run_in_threadpool(publish, "applications", json.dumps(event).encode(),
                                {"correlation_id": record.correlation_id})
        return as_graphql(record)


schema = strawberry.federation.Schema(query=Query, mutation=Mutation, federation_version="2.5")
