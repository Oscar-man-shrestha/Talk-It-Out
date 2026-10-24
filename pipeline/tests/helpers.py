"""Shared test helpers: a valid Config and a recording fake backend."""

from __future__ import annotations

from talkitout_pipeline.config import Config


def make_config(**overrides) -> Config:
    base = dict(
        backend_base_url="http://localhost:3000",
        pipeline_api_key="test-pipeline-key",
        max_input_chars=5000,
        max_output_chars=8000,
        lease_seconds=300,
        max_attempts=3,
        poll_interval_seconds=0.0,
        model_endpoint="http://localhost:8080/v1/chat/completions",
        model_id="test-model",
        model_api_key="",
        model_temperature=0.2,
        model_max_tokens=1024,
        model_request_timeout_seconds=120.0,
        model_extra_body={},
        pipeline_version="test-worker 1.0.0",
        log_level="INFO",
    )
    base.update(overrides)
    return Config(**base)


class FakeBackend:
    """Records every call and replays scripted responses."""

    def __init__(self) -> None:
        self.claim_responses: list = []
        self.claim_calls = 0
        self.results: list[dict] = []
        self.errors: list[dict] = []
        self.failures: list[dict] = []
        self.result_response: dict = {"applied": True}
        self.error_response: dict = {"applied": False, "reason": "error_recorded"}

    def claim(self, max_jobs: int = 1):
        self.claim_calls += 1
        assert max_jobs == 1, "worker must process one job at a time"
        if self.claim_responses:
            item = self.claim_responses.pop(0)
            if isinstance(item, Exception):
                raise item
            return item
        return []

    def report_result(self, **payload):
        self.results.append(payload)
        return self.result_response

    def report_error(self, *, job_id, raw_message_id, error_code):
        self.errors.append(
            {"job_id": job_id, "raw_message_id": raw_message_id, "error_code": error_code}
        )
        return self.error_response

    def report_failure(self, *, job_id, error_code):
        self.failures.append({"job_id": job_id, "error_code": error_code})
        return {"applied": False, "reason": "error_recorded"}


def make_job(job_id="job-1", raw_id="raw-1", text="fix it now!!!", agenda="Making NLP notes"):
    from talkitout_pipeline.http_client import Job

    return Job(
        job_id=job_id,
        raw_message_id=raw_id,
        text=text,
        group_agenda=agenda,
        contract_version=1,
    )
