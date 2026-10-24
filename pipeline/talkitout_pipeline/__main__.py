"""Entry point: python -m talkitout_pipeline

Loads pipeline/.env, validates configuration, and polls the backend
until SIGINT/SIGTERM. Startup logs contain configuration facts only —
never the API key or model key.
"""

from __future__ import annotations

import logging
import signal
import sys
import threading
import time

from . import PIPELINE_COMPONENT_VERSION
from .config import Config, load_config, load_env_file
from .errors import BackendFatal, ConfigError
from .http_client import BackendClient
from .model_adapter import OpenAICompatibleAdapter
from .rewrite import RewriteService
from .worker import Worker, setup_logging


def build_worker(config: Config) -> Worker:
    client = BackendClient(
        base_url=config.backend_base_url, api_key=config.pipeline_api_key
    )
    adapter = OpenAICompatibleAdapter(
        endpoint=config.model_endpoint,
        model_id=config.model_id,
        api_key=config.model_api_key,
        timeout=config.model_request_timeout_seconds,
    )
    service = RewriteService(adapter=adapter, config=config)
    return Worker(client=client, service=service, config=config, sleep=time.sleep)


def main() -> int:
    load_env_file()
    try:
        config = load_config()
    except ConfigError as exc:
        print(f"configuration error: {exc}", file=sys.stderr)
        return 2

    setup_logging(config.log_level)
    worker = build_worker(config)
    logger = logging.getLogger("talkitout.main")
    logger.info(
        "talk-it-out pipeline worker %s starting; backend=%s model_endpoint=%s model_id=%s "
        "(limits provisional: in=%d out=%d)",
        PIPELINE_COMPONENT_VERSION,
        config.backend_base_url,
        config.model_endpoint,
        config.model_id,
        config.max_input_chars,
        config.max_output_chars,
    )

    stop_via_signal(worker.stop_event)
    try:
        worker.run()
    except BackendFatal:
        return 1
    logger.info("worker stopped cleanly")
    return 0


def stop_via_signal(stop_event: threading.Event) -> None:
    def _handler(signum, frame):  # noqa: ANN001 - signal handler signature
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(sig, _handler)
        except (ValueError, OSError):  # not the main thread / unsupported
            pass


if __name__ == "__main__":
    raise SystemExit(main())
