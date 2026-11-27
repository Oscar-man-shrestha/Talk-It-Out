import unittest
from unittest.mock import patch

from talkitout_pipeline.__main__ import build_worker
from talkitout_pipeline.model_adapter import OpenAICompatibleAdapter
from talkitout_pipeline.worker import Worker

from .helpers import make_config


class RecordingAdapter(OpenAICompatibleAdapter):
    """Records constructor kwargs, then behaves like the real adapter."""

    captured: dict = {}

    def __init__(self, **kwargs) -> None:
        RecordingAdapter.captured = kwargs
        super().__init__(**kwargs)


class BuildWorkerWiringTests(unittest.TestCase):
    """The production entry point must forward the model settings —
    including model_extra_body — to the adapter, exactly like the smoke
    script does (security review finding F1)."""

    def test_extra_body_is_forwarded_to_the_adapter(self):
        extra = {"chat_template_kwargs": {"enable_thinking": False}}
        config = make_config(model_extra_body=extra)
        with patch(
            "talkitout_pipeline.__main__.OpenAICompatibleAdapter", RecordingAdapter
        ):
            worker = build_worker(config)
        self.assertIsInstance(worker, Worker)
        self.assertEqual(RecordingAdapter.captured["extra_body"], extra)
        self.assertEqual(
            RecordingAdapter.captured["endpoint"], config.model_endpoint
        )
        self.assertEqual(RecordingAdapter.captured["model_id"], config.model_id)
        self.assertEqual(
            RecordingAdapter.captured["timeout"],
            config.model_request_timeout_seconds,
        )

    def test_empty_extra_body_is_forwarded_as_empty_dict(self):
        config = make_config()  # model_extra_body defaults to {}
        with patch(
            "talkitout_pipeline.__main__.OpenAICompatibleAdapter", RecordingAdapter
        ):
            build_worker(config)
        self.assertEqual(RecordingAdapter.captured["extra_body"], {})


if __name__ == "__main__":
    unittest.main()


class WarmUpTest(unittest.TestCase):
    def _config(self):
        from talkitout_pipeline.config import load_config
        return load_config({
            "PIPELINE_BACKEND_BASE_URL": "http://backend",
            "PIPELINE_API_KEY": "k",
            "MODEL_ENDPOINT": "http://model/v1/chat/completions",
            "MODEL_ID": "m",
            "MODEL_EXTRA_BODY": '{"keep_alive": "2h"}',
        })

    def test_warm_up_sends_a_tiny_request_with_keep_alive(self):
        from talkitout_pipeline.__main__ import warm_up_model
        seen = {}

        def poster(endpoint, headers, payload, timeout):
            seen.update(payload)
            return 200, '{"choices":[{"message":{"content":"ok"}}]}'

        self.assertTrue(warm_up_model(self._config(), poster=poster))
        self.assertEqual(seen["max_tokens"], 1)
        self.assertEqual(seen["keep_alive"], "2h")
        self.assertEqual(seen["messages"], [{"role": "user", "content": "ok"}])

    def test_warm_up_never_raises(self):
        from talkitout_pipeline.__main__ import warm_up_model

        def down(endpoint, headers, payload, timeout):
            raise OSError("connection refused")

        self.assertFalse(warm_up_model(self._config(), poster=down))

