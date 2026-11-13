import json
import unittest

from talkitout_pipeline.errors import (
    BackendFatal,
    BackendRejected,
    BackendTransient,
)
from talkitout_pipeline.http_client import BackendClient


def envelope(code, message="boom"):
    return {"error": {"code": code, "message": message}}


def make_client(responses):
    """responses: list of (status, body_dict_or_str) or Exception, in order."""
    queue = list(responses)

    def poster(url, headers, payload, timeout):
        item = queue.pop(0)
        if isinstance(item, Exception):
            raise item
        status, body = item
        return status, body if isinstance(body, str) else json.dumps(body)

    return BackendClient(
        base_url="http://backend:3000",
        api_key="secret-key",
        poster=poster,
    )


class AuthAndHeaderTests(unittest.TestCase):
    def test_sends_pipeline_key_header(self):
        seen = {}

        def poster(url, headers, payload, timeout):
            seen["headers"] = headers
            seen["url"] = url
            seen["payload"] = payload
            return 200, json.dumps({"jobs": []})

        client = BackendClient(base_url="http://b", api_key="abc", poster=poster)
        client.claim()
        self.assertEqual(seen["headers"]["X-Pipeline-Key"], "abc")
        self.assertEqual(seen["url"], "http://b/internal/pipeline/claim")
        self.assertEqual(seen["payload"], {"max_jobs": 1})


class ClaimTests(unittest.TestCase):
    def test_parses_jobs(self):
        client = make_client(
            [
                (
                    200,
                    {
                        "jobs": [
                            {
                                "job_id": "j1",
                                "raw_message_id": "r1",
                                "text": "hello",
                                "group_agenda": "agenda",
                                "contract_version": 1,
                            }
                        ]
                    },
                )
            ]
        )
        jobs = client.claim()
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0].job_id, "j1")
        self.assertEqual(jobs[0].text, "hello")
        self.assertIsNone(jobs[0].tone)

    def test_reads_optional_tone(self):
        job = {"job_id": "j1", "raw_message_id": "r1", "text": "t",
               "group_agenda": "a", "contract_version": 1, "tone": "direct"}
        client = make_client([(200, {"jobs": [job]})])
        self.assertEqual(client.claim()[0].tone, "direct")

    def test_contract_version_mismatch_is_fatal(self):
        client = make_client(
            [
                (
                    200,
                    {
                        "jobs": [
                            {
                                "job_id": "j1",
                                "raw_message_id": "r1",
                                "text": "t",
                                "group_agenda": "a",
                                "contract_version": 2,
                            }
                        ]
                    },
                )
            ]
        )
        with self.assertRaises(BackendFatal):
            client.claim()

    def test_missing_keys_is_transient(self):
        client = make_client([(200, {"jobs": [{"job_id": "j1"}]})])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_no_jobs_list_is_transient(self):
        client = make_client([(200, {"unexpected": True})])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_empty_claim(self):
        client = make_client([(200, {"jobs": []})])
        self.assertEqual(client.claim(), [])


RESULT = dict(
    job_id="j1",
    raw_message_id="r1",
    rewritten_text="a calmer version",
    intent_preservation_score=0.9,
    relevance_score=0.5,
    relevance_label="borderline",
    pipeline_version="test-worker 1.0.0",
)


class ResultAndFailureTests(unittest.TestCase):
    def test_result_payload_has_exact_contract_keys(self):
        seen = {}

        def poster(url, headers, payload, timeout):
            seen["url"] = url
            seen["payload"] = payload
            return 200, json.dumps({"applied": True})

        client = BackendClient(base_url="http://b", api_key="k", poster=poster)
        body = client.report_result(**RESULT)
        self.assertEqual(body, {"applied": True})
        self.assertEqual(
            sorted(seen["payload"].keys()),
            sorted(
                [
                    "job_id",
                    "raw_message_id",
                    "outcome",
                    "rewritten_text",
                    "intent_preservation_score",
                    "relevance_score",
                    "relevance_label",
                    "pipeline_version",
                ]
            ),
        )
        self.assertEqual(seen["payload"]["outcome"], "ok")
        self.assertEqual(seen["url"], "http://b/internal/pipeline/result")

    def test_error_payload_shape(self):
        seen = {}

        def poster(url, headers, payload, timeout):
            seen["payload"] = payload
            return 200, json.dumps({"applied": False, "reason": "error_recorded"})

        client = BackendClient(base_url="http://b", api_key="k", poster=poster)
        client.report_error(job_id="j1", raw_message_id="r1", error_code="model_timeout")
        self.assertEqual(
            seen["payload"],
            {
                "job_id": "j1",
                "raw_message_id": "r1",
                "outcome": "error",
                "error_code": "model_timeout",
            },
        )

    def test_fail_payload_shape(self):
        seen = {}

        def poster(url, headers, payload, timeout):
            seen["url"] = url
            seen["payload"] = payload
            return 200, json.dumps({"applied": False, "reason": "error_recorded"})

        client = BackendClient(base_url="http://b", api_key="k", poster=poster)
        client.report_failure(job_id="j1", error_code="worker_crash")
        self.assertEqual(seen["payload"], {"job_id": "j1", "error_code": "worker_crash"})
        self.assertEqual(seen["url"], "http://b/internal/pipeline/fail")


class ErrorMappingTests(unittest.TestCase):
    def test_401_is_fatal(self):
        client = make_client([(401, envelope("invalid_pipeline_key"))])
        with self.assertRaises(BackendFatal):
            client.claim()

    def test_503_is_fatal(self):
        client = make_client([(503, envelope("internal_api_disabled"))])
        with self.assertRaises(BackendFatal):
            client.claim()

    def test_422_is_rejected_not_transient(self):
        client = make_client(
            [(422, envelope("validation", "rewritten_text is required"))]
        )
        with self.assertRaises(BackendRejected):
            client.report_result(**RESULT)

    def test_429_is_transient(self):
        client = make_client([(429, envelope("rate_limited"))])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_500_is_transient(self):
        client = make_client([(500, envelope("internal_error"))])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_malformed_json_2xx_is_transient(self):
        client = make_client([(200, "{not json")])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_malformed_json_500_is_transient(self):
        client = make_client([(500, "oops")])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_network_error_is_transient(self):
        client = make_client([OSError("connection refused")])
        with self.assertRaises(BackendTransient):
            client.claim()

    def test_timeout_error_is_transient(self):
        client = make_client([TimeoutError("timed out")])
        with self.assertRaises(BackendTransient):
            client.claim()


if __name__ == "__main__":
    unittest.main()
