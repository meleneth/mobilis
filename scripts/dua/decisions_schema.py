"""Cassandra lookups are keyed by application ID; no partition scans."""
import strawberry
from starlette.concurrency import run_in_threadpool

from .cassandra_client import execute


@strawberry.type
class Decision:
    outcome: str
    reason: str


def lookup(identity):
    return execute("select", "SELECT outcome, reason FROM decisions WHERE application_id = %s",
                   (identity,)).one()


@strawberry.federation.type(keys=["id"])
class Application:
    id: strawberry.ID

    @classmethod
    def resolve_reference(cls, id: strawberry.ID) -> "Application":
        if not str(id):
            raise ValueError("Application federation key is required")
        return cls(id=id)

    @strawberry.field
    async def decision(self) -> Decision | None:
        row = await run_in_threadpool(lookup, str(self.id))
        return Decision(outcome=row.outcome, reason=row.reason) if row else None

    @strawberry.field
    async def status(self) -> str:
        row = await run_in_threadpool(lookup, str(self.id))
        return row.outcome if row else "PENDING"


@strawberry.type
class Query:
    @strawberry.field
    def decision_service(self) -> str:
        return "Department of Unnecessary Approvals, Records Division"


schema = strawberry.federation.Schema(query=Query, types=[Application, Decision], federation_version="2.5")
