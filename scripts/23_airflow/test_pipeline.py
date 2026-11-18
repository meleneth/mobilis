from mobilis_pipeline import persist_report
import pytest


def test_report_is_deterministic(monkeypatch):
    calls = []
    class Cursor:
        def execute(self, statement, arguments):
            calls.append((statement, arguments))
        def __enter__(self): return self
        def __exit__(self, *args): pass
    class DB:
        def cursor(self): return Cursor()
    from contextlib import contextmanager
    @contextmanager
    def fake_connection():
        yield DB()
    monkeypatch.setattr("mobilis_pipeline.connection", fake_connection)
    result = persist_report("daily", [{"region": "WEST", "count": 2, "total": "3.24"}])
    assert result["grand_total"] == "3.24"
    assert len(calls) == 1 and "ON CONFLICT" in calls[0][0]


def test_intentional_failure_does_not_write(monkeypatch):
    def unexpected_connection():
        raise AssertionError("failure should precede database connection")
    monkeypatch.setattr("mobilis_pipeline.connection", unexpected_connection)
    with pytest.raises(RuntimeError, match="Intentional failure"):
        persist_report("daily", [{"region": "WEST", "count": 2, "total": "3.24"}], fail=True)
