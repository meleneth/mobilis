import json
from unittest.mock import Mock

import pytest

from service_applications import graphql_schema as schema


def test_event_payload_has_stable_identity(monkeypatch):
    published = []
    monkeypatch.setattr(schema, "publish", lambda topic, data, attrs: published.append((topic, json.loads(data), attrs)))
    session = Mock()
    info = Mock(context={"session": session})
    import asyncio
    result = asyncio.run(schema.Mutation().request_approval("DEPLOY_RUBBER_DUCK", "Morale", info))
    assert result.id == published[0][1]["application_id"]
    assert result.correlation_id == published[0][1]["correlation_id"]
    assert published[0][2]["correlation_id"] == result.correlation_id
    session.commit.assert_called_once()


def test_publish_failure_surfaces_after_database_commit(monkeypatch):
    monkeypatch.setattr(schema, "publish", Mock(side_effect=OSError("broker unavailable")))
    session = Mock()
    info = Mock(context={"session": session})
    import asyncio
    with pytest.raises(OSError, match="broker unavailable"):
        asyncio.run(schema.Mutation().request_approval("SECOND_COFFEE", "Administrative fatigue", info))
    session.commit.assert_called_once()


def test_database_failure_does_not_publish(monkeypatch):
    publisher = Mock()
    monkeypatch.setattr(schema, "publish", publisher)
    session = Mock()
    session.commit.side_effect = OSError("database unavailable")
    info = Mock(context={"session": session})
    import asyncio
    with pytest.raises(OSError, match="database unavailable"):
        asyncio.run(schema.Mutation().request_approval("SECOND_COFFEE", "Administrative fatigue", info))
    session.rollback.assert_called_once()
    publisher.assert_not_called()
