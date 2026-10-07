"""Regression coverage for logical span counting, independent of trace ingestion."""
import copy
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


if __name__ == "__main__":
    unittest.main()
