"""Polling worker loop: one job at a time, clean shutdown, safe logging.

Logging rule (pipeline/AGENTS.md): log job ids, outcome reasons, and
fixed error codes only. Message text, rewritten text, and identity are
never passed to a logger — test_privacy enforces this with sentinels.

Failure mapping (contract §3–§7):
- model/validation/language errors  -> outcome:"error" with a fixed code
  (or /fail for unexpected crashes), so the backend's attempt counter
  and backoff decide retries (PIPELINE_MAX_ATTEMPTS, default 3).
- backend transient errors          -> skip silently-but-logged; the
  lease expires and the backend re-queues the job (attempts are counted
  per claim). Posting a failure here would double-count.
- backend fatal errors (401/503/contract drift) -> stop the worker.
"""

from __future__ import annotations

import logging
import threading
from typing import Callable

from .config import Config
from .errors import (
    BackendFatal,
    BackendRejected,
    BackendTransient,
    ModelError,
    OutputValidationError,
    UnsupportedLanguage,
)
from .http_client import BackendClient, Job
from .rewrite import RewriteService

logger = logging.getLogger("talkitout.worker")

Sleep = Callable[[float], None]


class Worker:
    def __init__(
        self,
        *,
        client: BackendClient,
        service: RewriteService,
        config: Config,
        sleep: Sleep,
        stop_event: threading.Event | None = None,
    ) -> None:
        self._client = client
        self._service = service
        self._config = config
        self._sleep = sleep
        self._stop_event = stop_event or threading.Event()

    @property
    def stop_event(self) -> threading.Event:
        return self._stop_event

    def request_stop(self) -> None:
        self._stop_event.set()

    def run(self) -> None:
        """Poll until stop is requested. Raises BackendFatal upward."""
        logger.info("worker loop started (poll=%ss, one job at a time)",
                    self._config.poll_interval_seconds)
        while not self._stop_event.is_set():
            try:
                self.run_once()
            except BackendFatal as exc:
                logger.error("stopping: backend rejected the worker (%s)", exc.code)
                raise

    def run_once(self) -> str:
        """One poll cycle. Returns 'stopped' | 'empty' | 'processed'."""
        if self._stop_event.is_set():
            return "stopped"
        try:
            jobs = self._client.claim(max_jobs=1)
        except (BackendTransient, BackendRejected) as exc:
            logger.warning("claim skipped (%s)", exc.code)
            self._sleep(self._config.poll_interval_seconds)
            return "empty"
        if not jobs:
            self._sleep(self._config.poll_interval_seconds)
            return "empty"
        self._process_job(jobs[0])
        return "processed"

    def _process_job(self, job: Job) -> None:
        # The claim already consumed one attempt; a crash that prevents
        # reporting is handled by the lease expiring (see module docstring).
        try:
            try:
                outcome = self._service.rewrite(job.text, job.group_agenda)
            except (UnsupportedLanguage, OutputValidationError, ModelError) as exc:
                body = self._client.report_error(
                    job_id=job.job_id,
                    raw_message_id=job.raw_message_id,
                    error_code=exc.code,
                )
                logger.info("job %s error recorded (%s)", job.job_id, exc.code)
                _log_applied(job.job_id, body)
                return
            except Exception as exc:  # unexpected bug: never send or log exception text
                # type name only: a traceback could carry message content.
                logger.error("job %s crashed (%s); reporting worker_crash",
                             job.job_id, type(exc).__name__)
                body = self._client.report_failure(
                    job_id=job.job_id, error_code="worker_crash"
                )
                _log_applied(job.job_id, body)
                return

            body = self._client.report_result(
                job_id=job.job_id,
                raw_message_id=job.raw_message_id,
                rewritten_text=outcome.rewritten_text,
                intent_preservation_score=outcome.intent_preservation_score,
                relevance_score=outcome.relevance_score,
                relevance_label=outcome.relevance_label,
                pipeline_version=self._config.pipeline_version,
            )
            logger.info("job %s result submitted (unchanged=%s)",
                        job.job_id, outcome.unchanged)
            _log_applied(job.job_id, body)
        except (BackendTransient, BackendRejected) as exc:
            # Could not deliver the outcome; the lease expiry handles it.
            logger.warning("job %s result not delivered (%s)", job.job_id, exc.code)
        except BackendFatal:
            raise


def _log_applied(job_id: str, body: dict) -> None:
    applied = body.get("applied")
    reason = body.get("reason")
    if reason is None:
        logger.info("job %s applied=%s", job_id, applied)
    else:
        logger.info("job %s applied=%s reason=%s", job_id, applied, reason)


def setup_logging(level: str = "INFO") -> None:
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
