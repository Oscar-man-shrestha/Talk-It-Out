"""HTTP client for the internal pipeline API.

Exact endpoints and schemas from backend/docs/groups-pipeline-contract.md
(contract_version 1) and its implementation backend/src/internal/pipeline.ts:

- POST /internal/pipeline/claim   {"max_jobs": N} -> {"jobs": [...]}
- POST /internal/pipeline/result  ok/error payload -> {"applied": bool, "reason"?: str}
- POST /internal/pipeline/fail    {"job_id", "error_code"} -> same shape

Auth: X-Pipeline-Key header on every call. Errors use the backend
envelope {"error": {"code", "message"}}. No request or response body is
ever logged — job ids and reason strings only.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass

from .errors import BackendFatal, BackendRejected, BackendTransient

CONTRACT_VERSION = 1

# Injected in tests; default implementation speaks real HTTP.
Poster = callable  # (url, headers, payload, timeout) -> (status, body_text)


@dataclass(frozen=True)
class Job:
    job_id: str
    raw_message_id: str
    text: str
    group_agenda: str
    contract_version: int


def default_poster(url: str, headers: dict[str, str], payload: dict, timeout: float):
    """POST JSON and return (status, body_text). Network errors propagate."""
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={**headers, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:  # non-2xx is still a usable response
        return exc.code, exc.read().decode("utf-8", "replace")


class BackendClient:
    def __init__(self, *, base_url: str, api_key: str, timeout: float = 15.0,
                 poster: Poster | None = None) -> None:
        self._base_url = base_url.rstrip("/")
        self._headers = {"X-Pipeline-Key": api_key}
        self._timeout = timeout
        self._poster = poster or default_poster

    # -- response plumbing -------------------------------------------------

    def _post(self, path: str, payload: dict) -> dict:
        url = f"{self._base_url}{path}"
        try:
            status, body_text = self._poster(url, self._headers, payload, self._timeout)
        except (TimeoutError, OSError) as exc:
            raise BackendTransient(f"network error calling {path}: {type(exc).__name__}") from exc
        try:
            body = json.loads(body_text) if body_text else {}
        except ValueError:
            body = None
        if not isinstance(body, dict):
            # A malformed body from a 2xx is just as unusable as a 5xx.
            if 200 <= status < 300:
                raise BackendTransient(f"malformed JSON response from {path}")
            raise BackendTransient(f"HTTP {status} with malformed body from {path}")
        if status == 401:
            raise BackendFatal(_code_of(body, "invalid_pipeline_key"))
        if status == 503:
            raise BackendFatal(_code_of(body, "internal_api_disabled"))
        if status == 422:
            # Our payload was invalid; the backend already recorded the
            # failed attempt. Never repost the same payload.
            raise BackendRejected(f"{path} rejected payload: {_code_of(body, 'validation')}")
        if status == 429:
            raise BackendTransient(f"rate limited by {path}")
        if status >= 500:
            raise BackendTransient(f"HTTP {status} from {path}")
        if not (200 <= status < 300):
            raise BackendTransient(f"unexpected HTTP {status} from {path}")
        return body

    # -- contract endpoints --------------------------------------------------

    def claim(self, max_jobs: int = 1) -> list[Job]:
        body = self._post("/internal/pipeline/claim", {"max_jobs": max_jobs})
        jobs_raw = body.get("jobs")
        if not isinstance(jobs_raw, list):
            raise BackendTransient("claim response has no jobs list")
        jobs: list[Job] = []
        for item in jobs_raw:
            try:
                job = Job(
                    job_id=item["job_id"],
                    raw_message_id=item["raw_message_id"],
                    text=item["text"],
                    group_agenda=item["group_agenda"],
                    contract_version=item["contract_version"],
                )
            except (KeyError, TypeError):
                raise BackendTransient("claim response job is missing required keys") from None
            if not isinstance(job.contract_version, int) or not isinstance(job.job_id, str):
                raise BackendTransient("claim response job has wrong types")
            if job.contract_version != CONTRACT_VERSION:
                # Breaking-change signal: stop rather than mis-process jobs.
                raise BackendFatal(
                    f"contract_version mismatch: backend sent {job.contract_version}, "
                    f"worker implements {CONTRACT_VERSION}"
                )
            jobs.append(job)
        return jobs

    def report_result(
        self,
        *,
        job_id: str,
        raw_message_id: str,
        rewritten_text: str,
        intent_preservation_score: float,
        relevance_score: float,
        relevance_label: str,
        pipeline_version: str,
    ) -> dict:
        return self._post(
            "/internal/pipeline/result",
            {
                "job_id": job_id,
                "raw_message_id": raw_message_id,
                "outcome": "ok",
                "rewritten_text": rewritten_text,
                "intent_preservation_score": intent_preservation_score,
                "relevance_score": relevance_score,
                "relevance_label": relevance_label,
                "pipeline_version": pipeline_version,
            },
        )

    def report_error(
        self, *, job_id: str, raw_message_id: str, error_code: str
    ) -> dict:
        return self._post(
            "/internal/pipeline/result",
            {
                "job_id": job_id,
                "raw_message_id": raw_message_id,
                "outcome": "error",
                "error_code": error_code[:100],
            },
        )

    def report_failure(self, *, job_id: str, error_code: str) -> dict:
        return self._post(
            "/internal/pipeline/fail",
            {"job_id": job_id, "error_code": error_code[:100]},
        )


def _code_of(body: dict, fallback: str) -> str:
    error = body.get("error")
    if isinstance(error, dict) and isinstance(error.get("code"), str):
        return error["code"]
    return fallback
