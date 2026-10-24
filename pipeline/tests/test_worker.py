import logging
import unittest

from talkitout_pipeline.errors import (
    BackendFatal,
    BackendRejected,
    BackendTransient,
    ModelError,
    OutputValidationError,
    UnsupportedLanguage,
)
from talkitout_pipeline.rewrite import RewriteOutcome
from talkitout_pipeline.worker import Worker

from .helpers import FakeBackend, make_config, make_job


class StubService:
    def __init__(self, outcomes):
        self.outcomes = list(outcomes)

    def rewrite(self, text, agenda):
        item = self.outcomes.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


def make_worker(service, backend, jobs=None, claim_script=None, sleeps=None):
    sleeps = sleeps if sleeps is not None else []
    if claim_script is not None:
        backend.claim_responses = claim_script
    else:
        backend.claim_responses = [jobs if jobs is not None else [make_job()]]
    worker = Worker(
        client=backend,
        service=service,
        config=make_config(poll_interval_seconds=2.0),
        sleep=sleeps.append,
    )
    return worker


OK_OUTCOME = RewriteOutcome(
    rewritten_text="a professional version",
    intent_preservation_score=0.95,
    relevance_score=0.42,
    relevance_label="borderline",
)


class ProcessJobTests(unittest.TestCase):
    def test_success_posts_result_with_contract_fields(self):
        backend, service = FakeBackend(), StubService([OK_OUTCOME])
        worker = make_worker(service, backend)
        self.assertEqual(worker.run_once(), "processed")
        self.assertEqual(len(backend.results), 1)
        result = backend.results[0]
        self.assertEqual(sorted(result.keys()), sorted([
            "job_id", "raw_message_id", "rewritten_text",
            "intent_preservation_score", "relevance_score",
            "relevance_label", "pipeline_version",
        ]))
        self.assertEqual(result["pipeline_version"], "test-worker 1.0.0")
        self.assertEqual(backend.errors, [])
        self.assertEqual(backend.failures, [])

    def test_model_error_posts_error_outcome(self):
        backend = FakeBackend()
        service = StubService([ModelError("down", code="model_unavailable")])
        make_worker(service, backend).run_once()
        self.assertEqual(backend.errors[0]["error_code"], "model_unavailable")
        self.assertEqual(backend.results, [])

    def test_unsupported_language_posts_error_outcome(self):
        backend = FakeBackend()
        service = StubService([UnsupportedLanguage("non-english")])
        make_worker(service, backend).run_once()
        self.assertEqual(backend.errors[0]["error_code"], "unsupported_language")

    def test_validation_failure_posts_error_outcome(self):
        backend = FakeBackend()
        service = StubService([OutputValidationError("blank", code="blank_output")])
        make_worker(service, backend).run_once()
        self.assertEqual(backend.errors[0]["error_code"], "blank_output")

    def test_unexpected_crash_posts_worker_crash_failure(self):
        backend = FakeBackend()
        service = StubService([ValueError("boom with secret text")])
        make_worker(service, backend).run_once()
        self.assertEqual(backend.failures[0]["error_code"], "worker_crash")
        # The exception text (potentially containing content) is never sent.
        self.assertNotIn("secret text", str(backend.failures))

    def test_duplicate_result_response_is_not_an_error(self):
        backend = FakeBackend()
        backend.result_response = {"applied": False, "reason": "already_done"}
        make_worker(StubService([OK_OUTCOME]), backend).run_once()
        self.assertEqual(len(backend.results), 1)

    def test_decided_message_response_is_not_an_error(self):
        backend = FakeBackend()
        backend.result_response = {"applied": False, "reason": "message_decided"}
        make_worker(StubService([OK_OUTCOME]), backend).run_once()
        self.assertEqual(len(backend.results), 1)


class LoopTests(unittest.TestCase):
    def test_empty_claim_sleeps_poll_interval(self):
        backend = FakeBackend()
        sleeps: list[float] = []
        worker = Worker(
            client=backend,
            service=StubService([]),
            config=make_config(poll_interval_seconds=2.0),
            sleep=sleeps.append,
        )
        self.assertEqual(worker.run_once(), "empty")
        self.assertEqual(sleeps, [2.0])
        self.assertEqual(backend.results, [])

    def test_transient_claim_error_is_skipped_without_failure(self):
        backend = FakeBackend()
        make_worker(
            StubService([]),
            backend,
            claim_script=[BackendTransient("network down")],
        ).run_once()
        self.assertEqual(backend.failures, [])
        self.assertEqual(backend.errors, [])

    def test_fatal_claim_error_stops_loop(self):
        backend = FakeBackend()
        worker = make_worker(
            StubService([]),
            backend,
            claim_script=[BackendFatal("invalid_pipeline_key")],
        )
        with self.assertRaises(BackendFatal):
            worker.run()

    def test_rejected_result_is_not_double_reported(self):
        backend = FakeBackend()
        backend.result_response = {"applied": True}
        backend.claim_responses = [[make_job()]]
        # report_result raises BackendRejected (422) — attempt already
        # counted server-side; the worker must move on without /fail.
        def raise_rejected(**payload):
            raise BackendRejected("validation")

        backend.report_result = raise_rejected
        worker = make_worker(StubService([OK_OUTCOME]), backend)
        self.assertEqual(worker.run_once(), "processed")
        self.assertEqual(backend.failures, [])

    def test_stop_event_exits_cleanly(self):
        backend = FakeBackend()
        worker = make_worker(StubService([]), backend)
        worker.request_stop()
        self.assertEqual(worker.run_once(), "stopped")
        worker.run()  # returns without raising

    def test_processes_one_job_per_cycle(self):
        backend = FakeBackend()
        service = StubService([OK_OUTCOME, OK_OUTCOME])
        worker = make_worker(
            service,
            backend,
            claim_script=[[make_job("j1")], [make_job("j2")], []],
        )
        self.assertEqual(worker.run_once(), "processed")
        self.assertEqual(worker.run_once(), "processed")
        self.assertEqual(worker.run_once(), "empty")
        self.assertEqual(len(backend.results), 2)


class PrivacyLoggingTests(unittest.TestCase):
    def test_no_message_text_or_identity_in_logs(self):
        sentinel_text = "SENTINEL-TEXT-do-not-log-9812"
        sentinel_sender = "SENTINEL-SENDER-priya"
        backend = FakeBackend()
        job = make_job(job_id="job-abc", text=sentinel_text, agenda="agenda secret")
        service = StubService([OK_OUTCOME])
        worker = make_worker(service, backend, jobs=[job])

        with self.assertLogs(level=logging.DEBUG) as captured:
            worker.run_once()
        printed = "\n".join(captured.output)
        self.assertIn("job-abc", printed)  # job ids are allowed
        self.assertNotIn(sentinel_text, printed)
        self.assertNotIn(sentinel_sender, printed)
        self.assertNotIn("a professional version", printed)  # rewrite text too

    def test_crash_logs_do_not_leak_exception_text(self):
        sentinel = "SENTINEL-CRASH-SECRET"
        backend = FakeBackend()
        service = StubService([ValueError(f"boom {sentinel}")])
        worker = make_worker(service, backend, jobs=[make_job(job_id="job-xyz")])
        with self.assertLogs(level=logging.DEBUG) as captured:
            worker.run_once()
        printed = "\n".join(captured.output)
        self.assertNotIn(sentinel, printed)
        self.assertIn("worker_crash", printed)

    def test_unchanged_flag_is_logged_without_text(self):
        # Observability for the echo failure mode: the worker logs that
        # the output was unchanged (job id + flag only, never text).
        backend = FakeBackend()
        outcome = RewriteOutcome(
            rewritten_text="sentinel-free-text",
            intent_preservation_score=1.0,
            relevance_score=0.5,
            relevance_label="borderline",
            unchanged=True,
        )
        worker = make_worker(StubService([outcome]), backend)
        with self.assertLogs(level=logging.INFO) as captured:
            worker.run_once()
        printed = "\n".join(captured.output)
        self.assertIn("unchanged=True", printed)
        self.assertNotIn("sentinel-free-text", printed)


if __name__ == "__main__":
    unittest.main()
