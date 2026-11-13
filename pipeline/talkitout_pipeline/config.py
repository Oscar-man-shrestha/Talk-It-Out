"""Environment-based configuration and validation.

Every value comes from the environment (pipeline/.env is loaded first,
without overriding variables already set in the environment). No secrets
or endpoints are hardcoded; the defaults below mirror the backend's
PROVISIONAL limits (backend/.env.example: 5000 input / 8000 output
chars) and are pending confirmation — see README.md "Limits status".
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .errors import ConfigError

_DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


def load_env_file(path: Path = _DEFAULT_ENV_FILE) -> None:
    """Parse a .env file of KEY=VALUE lines into os.environ.

    Existing environment variables always win. Malformed lines are
    ignored (never logged with values, since a value could be a secret).
    """
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _required(env: dict[str, str], name: str) -> str:
    value = env.get(name, "").strip()
    if not value:
        raise ConfigError(f"{name} must be set (see pipeline/.env.example).")
    if value.startswith("<"):
        raise ConfigError(f"{name} still looks like a .env.example placeholder.")
    return value


def _positive_float(env: dict[str, str], name: str, default: float) -> float:
    raw = env.get(name, "").strip()
    if not raw:
        return default
    try:
        value = float(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be a number.") from exc
    if value <= 0:
        raise ConfigError(f"{name} must be positive.")
    return value


def _positive_int(env: dict[str, str], name: str, default: int) -> int:
    value = _positive_float(env, name, float(default))
    as_int = int(value)
    if as_int != value:
        raise ConfigError(f"{name} must be a whole number.")
    return as_int


@dataclass(frozen=True)
class Config:
    # Backend connection (HTTP contract only; never a DB connection).
    backend_base_url: str
    pipeline_api_key: str

    # Backend-side limits, mirrored for local guards. PROVISIONAL:
    # backend defaults are placeholders pending confirmation (README).
    max_input_chars: int
    max_output_chars: int
    lease_seconds: int
    max_attempts: int

    # Worker loop.
    poll_interval_seconds: float

    # Self-hosted, OpenAI-compatible inference endpoint. No third-party
    # provider; MODEL_API_KEY is only for a server that requires auth.
    model_endpoint: str
    model_id: str
    model_api_key: str
    model_temperature: float
    model_max_tokens: int
    model_request_timeout_seconds: float
    # Extra JSON object merged into every model request payload. This is
    # how server-specific request fields (e.g. vLLM's
    # chat_template_kwargs for Qwen3 thinking mode) are configured
    # without hard-coding one server in the adapter.
    model_extra_body: dict[str, Any]

    # Reported verbatim in every successful result (contract §3).
    pipeline_version: str
    log_level: str


def load_config(env: dict[str, str] | None = None) -> Config:
    env = dict(os.environ if env is None else env)

    base_url = _required(env, "PIPELINE_BACKEND_BASE_URL").rstrip("/")
    api_key = _required(env, "PIPELINE_API_KEY")
    model_endpoint = _required(env, "MODEL_ENDPOINT")
    if not (model_endpoint.startswith("http://") or model_endpoint.startswith("https://")):
        raise ConfigError("MODEL_ENDPOINT must be an http(s) URL.")
    model_id = _required(env, "MODEL_ID")

    max_input = _positive_int(env, "PIPELINE_MAX_INPUT_CHARS", 5000)
    max_output = _positive_int(env, "PIPELINE_MAX_OUTPUT_CHARS", 8000)
    lease = _positive_int(env, "PIPELINE_LEASE_SECONDS", 300)
    # The model call must finish well inside the lease so the worker can
    # report success or failure before the backend re-claims the job.
    timeout = _positive_float(env, "MODEL_REQUEST_TIMEOUT_SECONDS", 120.0)
    if timeout >= lease:
        raise ConfigError(
            "MODEL_REQUEST_TIMEOUT_SECONDS must be shorter than PIPELINE_LEASE_SECONDS "
            "so a failure can be reported before the lease expires."
        )

    temperature = _positive_float(env, "MODEL_TEMPERATURE", 0.2)
    if temperature > 2.0:
        raise ConfigError("MODEL_TEMPERATURE must be at most 2.0.")

    raw_extra = env.get("MODEL_EXTRA_BODY", "").strip()
    if raw_extra:
        try:
            extra_body = json.loads(raw_extra)
        except ValueError as exc:
            raise ConfigError("MODEL_EXTRA_BODY must be valid JSON.") from exc
        if not isinstance(extra_body, dict):
            raise ConfigError("MODEL_EXTRA_BODY must be a JSON object.")
    else:
        extra_body = {}

    return Config(
        backend_base_url=base_url,
        pipeline_api_key=api_key,
        max_input_chars=max_input,
        max_output_chars=max_output,
        lease_seconds=lease,
        max_attempts=_positive_int(env, "PIPELINE_MAX_ATTEMPTS", 3),
        poll_interval_seconds=_positive_float(env, "PIPELINE_POLL_INTERVAL_SECONDS", 2.0),
        model_endpoint=model_endpoint,
        model_id=model_id,
        # Empty by default: a self-hosted server usually needs no key, and
        # this must never become a third-party provider credential.
        model_api_key=env.get("MODEL_API_KEY", "").strip(),
        model_temperature=temperature,
        model_max_tokens=_positive_int(env, "MODEL_MAX_TOKENS", 1024),
        model_request_timeout_seconds=timeout,
        model_extra_body=extra_body,
        pipeline_version=env.get("PIPELINE_VERSION", "").strip() or "talkitout-pipeline 0.2.0",
        log_level=env.get("PIPELINE_LOG_LEVEL", "INFO").strip().upper(),
    )
