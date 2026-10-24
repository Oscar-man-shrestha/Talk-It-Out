import os
import tempfile
import unittest
from pathlib import Path

from talkitout_pipeline.config import load_config, load_env_file
from talkitout_pipeline.errors import ConfigError

from .helpers import make_config


class LoadConfigTests(unittest.TestCase):
    def test_minimal_valid_env(self):
        config = load_config(
            {
                "PIPELINE_BACKEND_BASE_URL": "http://localhost:3000/",
                "PIPELINE_API_KEY": "k" * 32,
                "MODEL_ENDPOINT": "http://localhost:8080/v1/chat/completions",
                "MODEL_ID": "m",
            }
        )
        self.assertEqual(config.backend_base_url, "http://localhost:3000")
        self.assertEqual(config.max_input_chars, 5000)  # provisional backend default
        self.assertEqual(config.max_output_chars, 8000)  # provisional backend default
        self.assertEqual(config.lease_seconds, 300)
        self.assertEqual(config.max_attempts, 3)
        self.assertEqual(config.pipeline_version, "talkitout-pipeline 0.1.0")

    def test_missing_required_vars_raise(self):
        for missing in (
            "PIPELINE_BACKEND_BASE_URL",
            "PIPELINE_API_KEY",
            "MODEL_ENDPOINT",
            "MODEL_ID",
        ):
            env = {
                "PIPELINE_BACKEND_BASE_URL": "http://x",
                "PIPELINE_API_KEY": "k",
                "MODEL_ENDPOINT": "http://m",
                "MODEL_ID": "m",
            }
            env.pop(missing)
            with self.assertRaises(ConfigError, msg=missing):
                load_config(env)

    def test_placeholder_values_raise(self):
        with self.assertRaises(ConfigError):
            load_config(
                {
                    "PIPELINE_BACKEND_BASE_URL": "http://x",
                    "PIPELINE_API_KEY": "<generate-a-long-random-secret>",
                    "MODEL_ENDPOINT": "http://m",
                    "MODEL_ID": "m",
                }
            )

    def test_model_endpoint_must_be_http(self):
        with self.assertRaises(ConfigError):
            load_config(
                {
                    "PIPELINE_BACKEND_BASE_URL": "http://x",
                    "PIPELINE_API_KEY": "k",
                    "MODEL_ENDPOINT": "ftp://m",
                    "MODEL_ID": "m",
                }
            )

    def test_timeout_must_be_inside_lease(self):
        with self.assertRaises(ConfigError):
            load_config(
                {
                    "PIPELINE_BACKEND_BASE_URL": "http://x",
                    "PIPELINE_API_KEY": "k",
                    "MODEL_ENDPOINT": "http://m",
                    "MODEL_ID": "m",
                    "PIPELINE_LEASE_SECONDS": "60",
                    "MODEL_REQUEST_TIMEOUT_SECONDS": "60",
                }
            )

    def test_overrides(self):
        config = load_config(
            {
                "PIPELINE_BACKEND_BASE_URL": "http://backend:3000",
                "PIPELINE_API_KEY": "k",
                "MODEL_ENDPOINT": "http://m",
                "MODEL_ID": "m",
                "PIPELINE_MAX_INPUT_CHARS": "2000",
                "PIPELINE_MAX_OUTPUT_CHARS": "3000",
                "PIPELINE_POLL_INTERVAL_SECONDS": "5",
                "MODEL_TEMPERATURE": "0.7",
            }
        )
        self.assertEqual(config.max_input_chars, 2000)
        self.assertEqual(config.max_output_chars, 3000)
        self.assertEqual(config.poll_interval_seconds, 5.0)
        self.assertEqual(config.model_temperature, 0.7)

    def test_invalid_numbers_raise(self):
        base = {
            "PIPELINE_BACKEND_BASE_URL": "http://x",
            "PIPELINE_API_KEY": "k",
            "MODEL_ENDPOINT": "http://m",
            "MODEL_ID": "m",
        }
        for bad in ("-1", "abc", "2.5"):
            with self.assertRaises(ConfigError):
                load_config({**base, "PIPELINE_MAX_INPUT_CHARS": bad})

    def test_temperature_cap(self):
        base = {
            "PIPELINE_BACKEND_BASE_URL": "http://x",
            "PIPELINE_API_KEY": "k",
            "MODEL_ENDPOINT": "http://m",
            "MODEL_ID": "m",
        }
        with self.assertRaises(ConfigError):
            load_config({**base, "MODEL_TEMPERATURE": "3.0"})

    def test_extra_body_default_is_empty(self):
        config = load_config(
            {
                "PIPELINE_BACKEND_BASE_URL": "http://x",
                "PIPELINE_API_KEY": "k",
                "MODEL_ENDPOINT": "http://m",
                "MODEL_ID": "m",
            }
        )
        self.assertEqual(config.model_extra_body, {})

    def test_extra_body_parses_json_object(self):
        config = load_config(
            {
                "PIPELINE_BACKEND_BASE_URL": "http://x",
                "PIPELINE_API_KEY": "k",
                "MODEL_ENDPOINT": "http://m",
                "MODEL_ID": "m",
                "MODEL_EXTRA_BODY": '{"chat_template_kwargs":{"enable_thinking":false}}',
            }
        )
        self.assertEqual(
            config.model_extra_body,
            {"chat_template_kwargs": {"enable_thinking": False}},
        )

    def test_extra_body_rejects_non_object_and_bad_json(self):
        base = {
            "PIPELINE_BACKEND_BASE_URL": "http://x",
            "PIPELINE_API_KEY": "k",
            "MODEL_ENDPOINT": "http://m",
            "MODEL_ID": "m",
        }
        with self.assertRaises(ConfigError):
            load_config({**base, "MODEL_EXTRA_BODY": "[1,2]"})
        with self.assertRaises(ConfigError):
            load_config({**base, "MODEL_EXTRA_BODY": "{not json"})


class LoadEnvFileTests(unittest.TestCase):
    def test_parses_and_never_overrides_environment(self):
        with tempfile.TemporaryDirectory() as tmp:
            env_path = Path(tmp) / ".env"
            env_path.write_text(
                "# comment\n"
                "PIPELINE_API_KEY=from-file\n"
                "MALFORMED LINE WITHOUT EQUALS\n"
                'QUOTED="quoted-value"\n',
                encoding="utf-8",
            )
            old = os.environ.get("PIPELINE_API_KEY")
            os.environ["PIPELINE_API_KEY"] = "from-env"
            try:
                load_env_file(env_path)
                self.assertEqual(os.environ["PIPELINE_API_KEY"], "from-env")
                self.assertEqual(os.environ["QUOTED"], "quoted-value")
            finally:
                if old is None:
                    os.environ.pop("PIPELINE_API_KEY", None)
                    os.environ.pop("QUOTED", None)
                else:
                    os.environ["PIPELINE_API_KEY"] = old

    def test_missing_file_is_fine(self):
        load_env_file(Path(tempfile.gettempdir()) / "definitely-missing.env")


class ConfigDataclassTests(unittest.TestCase):
    def test_replaceable_overrides(self):
        config = make_config(max_output_chars=123)
        self.assertEqual(config.max_output_chars, 123)
        self.assertEqual(config.pipeline_api_key, "test-pipeline-key")


if __name__ == "__main__":
    unittest.main()
