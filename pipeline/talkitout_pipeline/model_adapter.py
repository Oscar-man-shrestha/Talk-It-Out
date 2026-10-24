"""Model adapter interface and the self-hosted inference adapter.

The interface is deliberately tiny so other models (or a fine-tuned
variant) can be dropped in later: any object with ``complete(messages,
temperature=..., max_tokens=...) -> str``. The shipped implementation
targets an OpenAI-compatible chat/completions endpoint on infrastructure
we control. There is no third-party provider and no provider API key;
MODEL_API_KEY is optional auth for the self-hosted server only.

Inference failures are explicit ModelErrors with fixed codes; the caller
turns them into honest error outcomes, never a fabricated rewrite.
"""

from __future__ import annotations

import json
import socket
import urllib.error
from typing import Any, Protocol

from .errors import ModelError
from .http_client import default_poster

Message = dict[str, str]  # {"role": ..., "content": ...}


class ModelAdapter(Protocol):
    def complete(
        self, messages: list[Message], *, temperature: float, max_tokens: int
    ) -> str: ...


class OpenAICompatibleAdapter:
    """Adapter for a self-hosted OpenAI-compatible inference server."""

    def __init__(
        self,
        *,
        endpoint: str,
        model_id: str,
        api_key: str = "",
        timeout: float = 120.0,
        poster=None,
    ) -> None:
        self._endpoint = endpoint
        self._model_id = model_id
        self._api_key = api_key
        self._timeout = timeout
        self._poster = poster or default_poster

    def complete(
        self, messages: list[Message], *, temperature: float, max_tokens: int
    ) -> str:
        payload = {
            "model": self._model_id,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        headers: dict[str, str] = {}
        if self._api_key:
            # Authorization for the self-hosted server only; the value is
            # never logged (default_poster never logs headers).
            headers["Authorization"] = f"Bearer {self._api_key}"
        try:
            status, body_text = self._poster(
                self._endpoint, headers, payload, self._timeout
            )
        except (socket.timeout, TimeoutError):
            raise ModelError("model request timed out", code="model_timeout") from None
        except (urllib.error.URLError, OSError):
            raise ModelError(
                "model endpoint unreachable", code="model_unavailable"
            ) from None

        if status >= 500:
            raise ModelError(
                f"model endpoint returned HTTP {status}", code="model_unavailable"
            )
        if status == 429:
            raise ModelError(
                "model endpoint is overloaded (HTTP 429)", code="model_unavailable"
            )
        if status != 200:
            # Includes 401/403 from the self-hosted server's own auth.
            raise ModelError(
                f"model endpoint returned HTTP {status}", code="model_bad_response"
            )
        try:
            body: Any = json.loads(body_text)
        except ValueError:
            raise ModelError(
                "model endpoint returned malformed JSON", code="model_bad_response"
            ) from None
        try:
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            raise ModelError(
                "model response is missing choices[0].message.content",
                code="model_bad_response",
            ) from None
        if not isinstance(content, str):
            raise ModelError(
                "model response content is not a string", code="model_bad_response"
            )
        if not content.strip():
            raise ModelError(
                "model returned an empty completion", code="model_empty_output"
            )
        return content
