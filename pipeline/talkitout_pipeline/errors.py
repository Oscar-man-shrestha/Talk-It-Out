"""Error types with fixed, text-free error codes.

Every code travels to the backend as error_code (or drives worker
behavior) and must never carry message content: the exception message
itself is for local diagnostics only and is never sent or logged with
job context.
"""


class PipelineError(Exception):
    """Base class; ``code`` is a short fixed string safe to report."""

    code = "worker_error"

    def __init__(self, message: str, *, code: str | None = None) -> None:
        super().__init__(message)
        if code is not None:
            self.code = code


class ConfigError(PipelineError):
    code = "config_error"


class UnsupportedLanguage(PipelineError):
    """The submission does not look like English (English-only policy)."""

    code = "unsupported_language"


class OutputValidationError(PipelineError):
    """The model output failed deterministic validation; never report it."""

    code = "output_validation_failed"


class ModelError(PipelineError):
    """The inference call failed; the reason is one of the fixed codes."""

    code = "model_unavailable"


class BackendFatal(PipelineError):
    """The backend rejected the worker itself (bad key, API disabled,
    contract-version drift). The loop must stop for a human to fix."""

    code = "backend_fatal"


class BackendTransient(PipelineError):
    """Network/5xx/429/malformed-response: skip the job without posting a
    failure — the lease expires and the backend re-queues it (attempts are
    counted per claim, per contract §6)."""

    code = "backend_transient"


class BackendRejected(PipelineError):
    """The backend 422'd our result payload: the failed attempt is already
    recorded server-side. Never repost the same payload."""

    code = "backend_rejected"
