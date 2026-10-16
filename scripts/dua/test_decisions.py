import asyncio
from unittest.mock import Mock

from service_decisions import decisions_schema as schema


def test_pending_and_completed_decision(monkeypatch):
    application = schema.Application(id="request-1")
    monkeypatch.setattr(schema, "lookup", lambda identity: None)
    assert asyncio.run(application.status()) == "PENDING"
    assert asyncio.run(application.decision()) is None
    monkeypatch.setattr(schema, "lookup", lambda identity: Mock(outcome="DENIED", reason="Form C-2 absent"))
    decision = asyncio.run(application.decision())
    assert decision.outcome == "DENIED" and decision.reason == "Form C-2 absent"


def test_reference_resolution_requires_key():
    try:
        schema.Application.resolve_reference("")
    except ValueError:
        pass
    else:
        raise AssertionError("Missing key accepted")
