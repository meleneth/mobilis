"""Regression coverage for logical span counting, independent of trace ingestion."""
import copy
import json
import unittest
from operations import check_trace, unique_spans


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
                span(name + "-db", name, name + "-effect", {"db.statement": "INSERT INTO items"})
        return trace, effect["values"]

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
        with self.assertRaisesRegex(AssertionError, "unexpected item DB spans"):
            check_trace(trace, {"legacy", "candidate"}, True, value, "legacy")


if __name__ == "__main__":
    unittest.main()
