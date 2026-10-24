import json
import unittest

from talkitout_pipeline.errors import ModelError
from talkitout_pipeline.model_adapter import OpenAICompatibleAdapter


def completion(text):
    return {
        "choices": [{"message": {"role": "assistant", "content": text}}]
    }


class OpenAICompatibleAdapterTests(unittest.TestCase):
    def make_adapter(self, responses, **overrides):
        queue = list(responses)
        calls = []

        def poster(url, headers, payload, timeout):
            calls.append({"url": url, "headers": dict(headers), "payload": payload})
            item = queue.pop(0)
            if isinstance(item, Exception):
                raise item
            status, body = item
            return status, body if isinstance(body, str) else json.dumps(body)

        adapter = OpenAICompatibleAdapter(
            endpoint="http://inference:8080/v1/chat/completions",
            model_id="our-model",
            timeout=5.0,
            poster=poster,
            **overrides,
        )
        return adapter, calls

    def test_happy_path_returns_content(self):
        adapter, calls = self.make_adapter([(200, completion("a professional reply"))])
        out = adapter.complete(
            [{"role": "user", "content": "hi"}], temperature=0.2, max_tokens=64
        )
        self.assertEqual(out, "a professional reply")
        request = calls[0]["payload"]
        self.assertEqual(request["model"], "our-model")
        self.assertEqual(request["temperature"], 0.2)
        self.assertEqual(request["max_tokens"], 64)
        self.assertEqual(request["messages"][0]["content"], "hi")

    def test_no_authorization_header_without_api_key(self):
        adapter, calls = self.make_adapter([(200, completion("x"))])
        adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertNotIn("Authorization", calls[0]["headers"])

    def test_authorization_header_with_api_key(self):
        adapter, calls = self.make_adapter([(200, completion("x"))], api_key="selfhosted-key")
        adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(calls[0]["headers"]["Authorization"], "Bearer selfhosted-key")

    def test_empty_content_is_model_empty_output(self):
        adapter, _ = self.make_adapter([(200, completion("   "))])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_empty_output")

    def test_malformed_structure_is_bad_response(self):
        adapter, _ = self.make_adapter([(200, {"choices": []})])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_bad_response")

    def test_malformed_json_is_bad_response(self):
        adapter, _ = self.make_adapter([(200, "{oops")])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_bad_response")

    def test_500_is_unavailable(self):
        adapter, _ = self.make_adapter([(500, {"error": {}})])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_unavailable")

    def test_429_is_unavailable(self):
        adapter, _ = self.make_adapter([(429, {"error": {}})])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_unavailable")

    def test_401_is_bad_response(self):
        adapter, _ = self.make_adapter([(401, {"error": {}})])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_bad_response")

    def test_timeout_maps_to_model_timeout(self):
        adapter, _ = self.make_adapter([TimeoutError()])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_timeout")

    def test_connection_error_maps_to_unavailable(self):
        adapter, _ = self.make_adapter([OSError("refused")])
        with self.assertRaises(ModelError) as ctx:
            adapter.complete([{"role": "user", "content": "hi"}], temperature=0.1, max_tokens=8)
        self.assertEqual(ctx.exception.code, "model_unavailable")


if __name__ == "__main__":
    unittest.main()
