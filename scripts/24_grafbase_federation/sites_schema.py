"""Sites owns Site.id and Site.name. Resolvers use the request's SQLAlchemy session."""
import strawberry
from sqlalchemy import select
from starlette.concurrency import run_in_threadpool

from .models import SiteRecord


@strawberry.federation.type(keys=["id"])
class Site:
    id: strawberry.ID
    name: str


@strawberry.type
class Query:
    @strawberry.field
    async def sites(self, info: strawberry.Info) -> list[Site]:
        session = info.context["session"]
        records = await run_in_threadpool(
            lambda: session.scalars(select(SiteRecord).order_by(SiteRecord.id).limit(20)).all()
        )
        return [Site(id=str(record.id), name=record.name) for record in records]


@strawberry.type
class Mutation:
    @strawberry.mutation
    async def create_site(self, name: str, info: strawberry.Info) -> Site:
        session = info.context["session"]

        def insert():
            record = SiteRecord(name=name)
            session.add(record)
            session.commit()
            session.refresh(record)
            return Site(id=str(record.id), name=record.name)

        return await run_in_threadpool(insert)


schema = strawberry.federation.Schema(query=Query, mutation=Mutation, federation_version="2.5")
