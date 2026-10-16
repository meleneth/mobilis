import asyncio

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from service_deployments.graphql_support import grouped_loader
from service_deployments.graphql_schema import Site, schema
from service_deployments.models import Base, DeploymentRecord


def test_reference_rejects_an_invalid_key():
    assert Site.resolve_reference("7").id == "7"
    try:
        Site.resolve_reference("invalid")
    except ValueError:
        pass
    else:
        raise AssertionError("broken federation key was accepted")
    assert "deployments" in schema.as_str()


def test_bounded_relationship_loader_batches_keys_into_one_select():
    engine = create_engine("sqlite+pysqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    statements = []
    event.listen(engine, "before_cursor_execute", lambda *args: statements.append(args[2]))
    with Session(engine) as session:
        session.add_all([
            DeploymentRecord(id=1, site_id=1, status="active"),
            DeploymentRecord(id=2, site_id=2, status="pending"),
        ])
        session.commit()
        statements.clear()

        async def fetch():
            loader = grouped_loader(session, DeploymentRecord, "site_id", max_keys=2)
            return await asyncio.gather(loader.load(1), loader.load(2))

        result = asyncio.run(fetch())
        assert [[row.id for row in rows] for rows in result] == [[1], [2]]
        assert len([sql for sql in statements if sql.lstrip().upper().startswith("SELECT")]) == 1

        async def exceed_limit():
            loader = grouped_loader(session, DeploymentRecord, "site_id", max_keys=1)
            await asyncio.gather(loader.load(1), loader.load(2))

        try:
            asyncio.run(exceed_limit())
        except ValueError as error:
            assert "exceeds 1 keys" in str(error)
        else:
            raise AssertionError("unbounded relationship load was accepted")
