"""Isolated application tests; no DATABASE_URL, exporters or external services."""
import json

import pytest
from fastapi.testclient import TestClient
from flexmock import flexmock
from flexmock.exceptions import FlexmockError
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from service_legacy.app import create_app
from service_legacy import items as item_logic
from service_legacy.items import ItemStore, determine_effect, effect_attributes, get_item_store
from service_legacy.models import Base, Item

VALUE = {"id": 42, "name": "foo"}
EFFECT = {"operation": "insert", "table": "items", "values": VALUE}


def forbidden_session():
    pytest.fail("unit handler unexpectedly opened a database session")


@pytest.fixture
def store():
    # This is the actual production type, not flexmock() or an empty object.
    return ItemStore(sessions=forbidden_session)


@pytest.fixture
def client(store, monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    app = create_app(telemetry=False)
    app.dependency_overrides[get_item_store] = lambda: store
    with TestClient(app) as client:
        yield client


def assert_response(response, status, body):
    assert response.status_code == status
    assert response.json() == body
    assert response.headers["content-type"] == "application/json"
    assert response.headers["x-served-by"] == "legacy"


def test_health_needs_no_collaborator(client, store):
    flexmock(store).should_receive("list_items").never()
    flexmock(store).should_receive("commit").never()
    assert_response(client.get("/health"), 200, {"status": "ok"})


@pytest.mark.parametrize("items", [[], [{"id": 1, "name": "example"}, VALUE]])
def test_item_read_contract(client, store, items):
    flexmock(store).should_receive("list_items").with_args().and_return(items).once()
    flexmock(store).should_receive("commit").never()
    assert_response(client.get("/items"), 200, items)


def test_read_database_failure(client, store):
    flexmock(store).should_receive("list_items").with_args().and_raise(SQLAlchemyError("offline")).once()
    flexmock(store).should_receive("commit").never()
    assert_response(client.get("/items"), 503, {"error": "database unavailable"})


INVALID = [b"", b"{", b"null", b"[]", b"{}",
    b'{"id":true,"name":"foo"}', b'{"id":1.0,"name":"foo"}',
    b'{"id":"42","name":"foo"}', b'{"id":null,"name":"foo"}',
    b'{"id":0,"name":"foo"}', b'{"id":-1,"name":"foo"}',
    b'{"id":2147483648,"name":"foo"}', b'{"id":42}', b'{"name":"foo"}',
    b'{"id":42,"name":null}', b'{"id":42,"name":12}', b'{"id":42,"name":""}',
    b'{"id":42,"name":"bad name"}', b'{"id":42,"name":"foo","extra":1}',
    b'{"id":42,"name":"foo"} {}', b'\xef\xbb\xbf{"id":42,"name":"foo"}',
    '{"id":42,"name":"foo"}'.encode("utf-16"),
    json.dumps({"id": 42, "name": "x" * 81}).encode(),
    json.dumps({"id": 42, "name": "é"}).encode()]


@pytest.mark.parametrize("raw", INVALID)
def test_invalid_write_never_commits(client, store, raw):
    flexmock(store).should_receive("commit").never()
    flexmock(store).should_receive("list_items").never()
    assert_response(client.post("/items", content=raw), 400, {"error": "invalid item"})


@pytest.mark.parametrize("value", [VALUE, {"id": 1, "name": "A_-0"},
    {"id": 2147483647, "name": "x" * 80}])
def test_authoritative_write_commits_exactly_one_computed_effect(client, store, value):
    expected = {"operation": "insert", "table": "items", "values": value}
    flexmock(store).should_receive("commit").with_args(expected).and_return(None).once().ordered()
    flexmock(item_logic).should_call("effect_attributes").with_args(expected, shadow=False, committed=True).once().ordered()
    flexmock(store).should_receive("list_items").never()
    assert_response(client.post("/items", json=value), 201, value)


@pytest.mark.parametrize("error,status,body", [
    (IntegrityError(None, None, Exception("duplicate")), 409, {"error": "item exists"}),
    (SQLAlchemyError("commit failed"), 503, {"error": "database unavailable"})])
def test_write_dependency_failures(client, store, error, status, body):
    flexmock(store).should_receive("commit").with_args(EFFECT).and_raise(error).once()
    flexmock(item_logic).should_receive("effect_attributes").never()
    assert_response(client.post("/items", json=VALUE), status, body)


def test_legacy_does_not_offer_a_request_dry_run(client, store):
    flexmock(store).should_receive("commit").with_args(EFFECT).and_return(None).once()
    assert_response(client.post("/items", json=VALUE, headers={"X-Mobilis-Shadow": "true"}), 201, VALUE)


def test_exact_effect_and_deterministic_evidence():
    value = dict(VALUE)
    effect = determine_effect(value)
    assert effect == EFFECT
    value["name"] = "changed"
    assert effect == EFFECT
    attrs = effect_attributes(effect, shadow=False, committed=True)
    assert attrs == {"demo.request.shadow": False, "demo.write.committed": True,
        "demo.write.mode": "actual", "db.operation.name": "INSERT", "db.collection.name": "items",
        "demo.write.effect": '{"operation": "insert", "table": "items", "values": {"id": 42, "name": "foo"}}'}
    assert effect_attributes(effect, shadow=False, committed=True) == attrs


def test_real_store_orders_items_using_real_sqlalchemy():
    # Read adapter semantics are exercised with SQLite, not ORM method mocks.
    engine = create_engine("sqlite://")
    try:
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            session.add_all([Item(id=42, name="foo"), Item(id=1, name="example")])
            session.commit()
        store = ItemStore(sessions=lambda: Session(engine))
        assert store.list_items() == [{"id": 1, "name": "example"}, VALUE]
    finally:
        engine.dispose()


def test_flexmock_rejects_a_method_absent_from_the_production_collaborator(store):
    with pytest.raises(FlexmockError):
        flexmock(store).should_receive("invented_database_method")
