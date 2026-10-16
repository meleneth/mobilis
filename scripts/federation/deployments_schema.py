"""Deployments contributes Site.deployments through a Federation entity key."""
import strawberry
from sqlalchemy import func, select
from starlette.concurrency import run_in_threadpool

from .graphql_support import grouped_loader
from .models import DeploymentRecord


@strawberry.type
class Deployment:
    id: strawberry.ID
    status: str


@strawberry.federation.type(keys=["id"])
class Site:
    id: strawberry.ID

    @classmethod
    def resolve_reference(cls, id: strawberry.ID) -> "Site":
        # A malformed cross-subgraph key fails rather than returning a fake entity.
        parsed = int(str(id))
        if parsed < 1:
            raise ValueError("Site federation key must be positive")
        return cls(id=str(parsed))

    @strawberry.field
    async def deployments(self, info: strawberry.Info) -> list[Deployment]:
        loaders = info.context["loaders"]
        loader = loaders.setdefault(
            "site_deployments",
            grouped_loader(info.context["session"], DeploymentRecord, "site_id", max_keys=20, max_rows=100),
        )
        records = await loader.load(int(self.id))
        return [Deployment(id=str(record.id), status=record.status) for record in records]


@strawberry.type
class Query:
    @strawberry.field
    async def deployment_count(self, info: strawberry.Info) -> int:
        session = info.context["session"]
        return await run_in_threadpool(
            lambda: session.scalar(select(func.count()).select_from(DeploymentRecord))
        )


schema = strawberry.federation.Schema(query=Query, types=[Site, Deployment], federation_version="2.5")
