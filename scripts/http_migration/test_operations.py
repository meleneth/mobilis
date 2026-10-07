"""Regression coverage for SQL meaning, bindings, effects and trace evidence."""
import copy
import json
import unittest
from operations import check_trace, unique_spans
from sql_meaning import sql_meaning


class SpanEvidenceTest(unittest.TestCase):
    def trace(self):
        return {"processes": {"p1": {"serviceName": "legacy"}}, "spans": [{
            "traceID": "abc", "spanID": "123", "processID": "p1",
            "operationName": "POST /items", "references": [], "startTime": 1,
            "duration": 10, "logs": [], "tags": [
                {"key": "span.kind", "value": "server"},
                {"key": "demo.write.effect", "value": '{"values":{"id":2}}'}]}]}

    def test_identical_delivery_copies_count_as_one_span(self):
        trace = self.trace()
        duplicate = copy.deepcopy(trace["spans"][0])
        duplicate["warnings"] = ["duplicate span IDs"]
        duplicate["tags"].append({"key": "@jaeger@warnings", "value": "diagnostic"})
        trace["spans"].append(duplicate)
        self.assertEqual(len(unique_spans(trace)), 1)

    def test_conflicting_copies_cannot_hide_an_effect_mismatch(self):
        trace = self.trace()
        duplicate = copy.deepcopy(trace["spans"][0])
        duplicate["tags"][1]["value"] = '{"values":{"id":3}}'
        trace["spans"].append(duplicate)
        with self.assertRaisesRegex(AssertionError, "conflicting duplicate"):
            unique_spans(trace)

    def test_distinct_http_spans_still_violate_exactly_one_invariant(self):
        trace = self.trace()
        duplicate = copy.deepcopy(trace["spans"][0])
        duplicate["spanID"] = "456"
        trace["spans"].append(duplicate)
        self.assertEqual(len(unique_spans(trace)), 2)
        with self.assertRaisesRegex(AssertionError, "expected one HTTP server"):
            check_trace(trace, {"legacy"}, write=False)


    def write_trace(self, authority="legacy"):
        effect = {"operation": "insert", "table": "items", "values": {"id": 42, "name": "foo"}}
        trace = {"processes": {name: {"serviceName": name} for name in ("gateway", "legacy", "candidate")}, "spans": []}

        def span(identity, name, parent, attributes):
            trace["spans"].append({"traceID": "abc", "spanID": identity, "processID": name,
                "operationName": identity, "references": [{"refType": "CHILD_OF", "spanID": parent}] if parent else [],
                "tags": [{"key": key, "value": value} for key, value in attributes.items()]})

        span("gateway", "gateway", None, {"span.kind": "server"})
        for name in ({"legacy", "candidate"} if authority == "legacy" else {"candidate"}):
            shadow = name != authority
            span(name, name, "gateway", {"span.kind": "server", "demo.request.shadow": shadow})
            span(name + "-effect", name, name, {"demo.request.shadow": shadow,
                "demo.write.committed": not shadow, "demo.write.mode": "shadow" if shadow else "actual",
                "db.operation.name": "INSERT", "db.collection.name": "items",
                "demo.write.effect": json.dumps(effect, sort_keys=True)})
            if not shadow:
                statement = "INSERT INTO items (id, name) VALUES (%(id)s::INTEGER, %(name)s::VARCHAR)" if name == "legacy" else "INSERT INTO items (id, name) VALUES ($1, $2)"
                span(name + "-db", name, name + "-effect", {"db.statement": statement})
            else:
                statement = "INSERT INTO items (id, name) VALUES ($1, $2)"
            span(name + "-sql", name, name + "-effect", {"demo.sql.text": statement,
                "demo.sql.parameters": json.dumps(effect["values"] if name == "legacy" else [42, "foo"]),
                "demo.sql.executed": not shadow, "demo.sql.executemany": False})
        return trace, effect["values"]

    def read_trace(self):
        trace, _ = self.write_trace()
        for span in trace["spans"]:
            identity = span["spanID"]
            if identity.endswith("-db"):
                span["tags"] = [{"key": "db.statement", "value": "SELECT items.id, items.name FROM items ORDER BY items.id"}]
            if identity.endswith("-sql"):
                span["tags"] = [{"key": key, "value": value} for key, value in {
                    "demo.sql.text": "SELECT items.id, items.name FROM items ORDER BY items.id" if identity.startswith("legacy") else "SELECT id, name FROM items ORDER BY id",
                    "demo.sql.parameters": "[]", "demo.sql.executed": True,
                    "demo.sql.executemany": False}.items()]
        trace["spans"].append({"traceID": "abc", "spanID": "candidate-db", "processID": "candidate",
            "operationName": "query", "references": [{"refType": "CHILD_OF", "spanID": "candidate"}],
            "tags": [{"key": "db.statement", "value": "SELECT id, name FROM items ORDER BY id"}]})
        return trace

    def test_equivalent_read_sql_is_compared(self):
        check_trace(self.read_trace(), {"legacy", "candidate"}, False, authority="legacy")

    def test_read_sql_drift_fails_even_with_matching_responses_and_span_counts(self):
        for statement in ["SELECT name, id FROM items ORDER BY id", "SELECT id, name FROM items WHERE id > 1 ORDER BY id",
                          "SELECT id, name FROM items ORDER BY id DESC", "SELECT id, name FROM items LIMIT 1",
                          "SELECT DISTINCT id, name FROM items ORDER BY id"]:
            with self.subTest(statement=statement):
                trace = self.read_trace()
                evidence = next(span for span in trace["spans"] if span["spanID"] == "candidate-sql")
                evidence["tags"][0]["value"] = statement
                with self.assertRaisesRegex(AssertionError, "SQL meaning drift"):
                    check_trace(trace, {"legacy", "candidate"}, False, authority="legacy")

    def test_real_query_drift_cannot_hide_behind_unchanged_sql_evidence(self):
        trace = self.read_trace()
        next(span for span in trace["spans"] if span["spanID"] == "candidate-db")["tags"][0]["value"] = "SELECT id, name FROM items ORDER BY name"
        with self.assertRaisesRegex(AssertionError, "instrumented SQL meaning drift"):
            check_trace(trace, {"legacy", "candidate"}, False, authority="legacy")

    def test_shadow_insert_binding_drift_is_rejected_with_unchanged_effect(self):
        trace, value = self.write_trace()
        evidence = next(span for span in trace["spans"] if span["spanID"] == "candidate-sql")
        evidence["tags"][1]["value"] = '[43, "foo"]'
        with self.assertRaisesRegex(AssertionError, "SQL meaning drift"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_sql_evidence_is_required(self):
        trace, value = self.write_trace()
        trace["spans"] = [span for span in trace["spans"] if span["spanID"] != "candidate-sql"]
        with self.assertRaisesRegex(AssertionError, "missing/duplicate SQL meaning evidence"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_sql_evidence_must_belong_to_the_request(self):
        trace, value = self.write_trace()
        evidence = next(span for span in trace["spans"] if span["spanID"] == "candidate-sql")
        evidence["references"] = []
        with self.assertRaisesRegex(AssertionError, "disconnected evidence"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_semantic_effect_comparison_accepts_independent_json_order(self):
        trace, value = self.write_trace()
        check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")
        trace, value = self.write_trace("candidate")
        check_trace(trace, {"candidate"}, True, value, "candidate")

    def test_shadow_commit_evidence_is_rejected(self):
        trace, value = self.write_trace()
        shadow = next(span for span in trace["spans"] if span["spanID"] == "candidate-effect")
        next(tag for tag in shadow["tags"] if tag["key"] == "demo.write.committed")["value"] = True
        with self.assertRaisesRegex(AssertionError, "shadow/commit evidence mismatch"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_authoritative_request_cannot_be_a_shadow(self):
        trace, value = self.write_trace("candidate")
        server = next(span for span in trace["spans"] if span["spanID"] == "candidate")
        next(tag for tag in server["tags"] if tag["key"] == "demo.request.shadow")["value"] = True
        with self.assertRaisesRegex(AssertionError, "request shadow context mismatch"):
            check_trace(trace, {"candidate"}, True, value, "candidate")

    def test_independently_computed_effect_mismatch_is_rejected(self):
        trace, value = self.write_trace()
        shadow = next(span for span in trace["spans"] if span["spanID"] == "candidate-effect")
        next(tag for tag in shadow["tags"] if tag["key"] == "demo.write.effect")["value"] = json.dumps(
            {"operation": "insert", "table": "items", "values": {"id": 43, "name": "foo"}})
        with self.assertRaisesRegex(AssertionError, "semantic effect mismatch"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_shadow_database_query_is_rejected(self):
        trace, value = self.write_trace()
        trace["spans"].append({"traceID": "abc", "spanID": "unexpected-db", "processID": "candidate",
            "operationName": "INSERT", "references": [{"refType": "CHILD_OF", "spanID": "candidate"}],
            "tags": [{"key": "db.statement", "value": "INSERT INTO items"}]})
        with self.assertRaisesRegex(AssertionError, "unexpected application DB spans"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_successful_effects_cannot_hide_a_failed_sql_span(self):
        trace, value = self.write_trace()
        query = next(span for span in trace["spans"] if span["spanID"] == "legacy-db")
        query["tags"].append({"key": "error", "value": True})
        with self.assertRaisesRegex(AssertionError, "unexpected error span"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_additional_query_to_another_table_is_not_ignored(self):
        trace = self.read_trace()
        extra = copy.deepcopy(next(span for span in trace["spans"] if span["spanID"] == "candidate-db"))
        extra["spanID"] = "extra-query"
        extra["tags"][0]["value"] = "SELECT id FROM another_table"
        trace["spans"].append(extra)
        with self.assertRaisesRegex(AssertionError, "unexpected application DB spans"):
            check_trace(trace, {"legacy", "candidate"}, False, authority="legacy")

    def test_discarded_shadow_http_failure_is_rejected(self):
        trace, value = self.write_trace()
        server = next(span for span in trace["spans"] if span["spanID"] == "candidate")
        server["tags"].append({"key": "http.response.status_code", "value": 400})
        with self.assertRaisesRegex(AssertionError, "unexpected HTTP span status"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")

    def test_mirror_unavailability_is_allowed_only_during_explicit_outage(self):
        trace, value = self.write_trace()
        trace["spans"] = [span for span in trace["spans"] if span["processID"] != "candidate"]
        mirror = {"traceID": "abc", "spanID": "mirror", "processID": "gateway",
                  "operationName": "mirror", "references": [{"refType": "CHILD_OF", "spanID": "gateway"}],
                  "tags": [{"key": "error", "value": True}, {"key": "http.status_code", "value": "503"}]}
        trace["spans"].append(mirror)
        with self.assertRaisesRegex(AssertionError, "unexpected error span"):
            check_trace(trace, {"legacy"}, True, value, "legacy")
        check_trace(trace, {"legacy"}, True, value, "legacy", failure=True)
        mirror["tags"][1]["value"] = "400"
        with self.assertRaisesRegex(AssertionError, "unexpected error span"):
            check_trace(trace, {"legacy"}, True, value, "legacy", failure=True)


class SqlMeaningTest(unittest.TestCase):
    def test_read_driver_spelling_and_aliases_are_equivalent(self):
        expected = sql_meaning("SELECT items.id, items.name FROM items ORDER BY items.id", {})
        for statement in ['select id, name from items order by id asc;',
                          'SELECT i.id, i.name FROM items AS i ORDER BY i.id',
                          'SELECT "items"."id", "items"."name" FROM "items" ORDER BY "items"."id"']:
            self.assertEqual(sql_meaning(statement, []), expected)

    def test_insert_column_order_and_placeholder_names_preserve_bindings(self):
        expected = sql_meaning("INSERT INTO items (id, name) VALUES (%(id)s::INTEGER, %(name)s::VARCHAR)", {"id": 42, "name": "foo"})
        self.assertEqual(sql_meaning("INSERT INTO items (name, id) VALUES ($2, $1)", [42, "foo"]), expected)
        self.assertNotEqual(sql_meaning("INSERT INTO items (id, name) VALUES ($1, $2)", [43, "foo"]), expected)

    def test_unsupported_or_missing_evidence_fails_closed(self):
        for statement, parameters in [
            ("INSERT INTO items (id, name) VALUES ($1, $2)", [42]),
            ("INSERT INTO items (id, name) VALUES ($1, $2) ON CONFLICT DO NOTHING", [42, "foo"]),
            ("INSERT INTO ONLY items (id, name) VALUES ($1, $2)", [42, "foo"]),
            ("INSERT INTO items (id, name) VALUES ($1, $2::VARCHAR(1))", [42, "foo"]),
            ("SELECT id, name FROM items; DELETE FROM items", []),
            ("SELECT id, name FROM another_table", []),
            ("SELECT id, name FROM items", [42]),
            ("not SQL", []),
        ]:
            with self.subTest(statement=statement), self.assertRaises(AssertionError):
                sql_meaning(statement, parameters)


if __name__ == "__main__":
    unittest.main()
