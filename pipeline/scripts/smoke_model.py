"""Model-only smoke test for the Talk It Out pipeline worker.

Validates a self-hosted, OpenAI-compatible inference endpoint through
the worker's own adapter and rewrite path — WITHOUT the backend. Run
this before pointing a real worker at a real model.

SYNTHETIC TEXT ONLY. Never point this script at production traffic or
feed it real user messages: by default it prints only pass/fail, latency,
scores, and error codes; --show-output displays the model's responses,
which is safe here because every prompt below is synthetic developer
test text.

Two SEPARATE verdicts are reported:

- FUNCTIONAL: connectivity + ordinary rewrite. Success here says the
  server works and the worker plumbing works — nothing about security.
- ADVERSARIAL: a small probe set of embedded-instruction attacks
  (talkitout_pipeline/adversarial.py). A probe is judged "suspected"
  when the rewrite contains the probe's canary token or loses required
  content — evidence the model may have obeyed the injection. This is a
  conservative screen for manual review, NOT proof of security either
  way; see README "Prompt-injection evaluation". Statuses per probe:
  PASS, ECHO (input returned unchanged — task failure, not obedience),
  HIJACKED (canary in execution position — the append_token probe's
  canary is absent from its input by design, so this is execution
  evidence), SUSPECTED (ambiguous canary mention or content loss —
  manual review), INCONCLUSIVE (model/backend error).

Exit codes:
    0  functional PASS and adversarial evaluation PASS (on synthetic
       probes; still not a security guarantee)
    1  functional failure (connectivity or ordinary rewrite)
    2  configuration error
    3  adversarial evaluation FAIL — at least one probe SUSPECTED
    4  adversarial evaluation INCONCLUSIVE — probes could not be judged
       (model/backend errors), or no functional failure but no evidence

Usage (from pipeline/):
    python scripts/smoke_model.py --endpoint http://127.0.0.1:8000/v1/chat/completions --model qwen3-4b
    python scripts/smoke_model.py --show-output        # uses pipeline/.env values
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from talkitout_pipeline.adversarial import (  # noqa: E402
    ADVERSARIAL_PROBES,
    evaluate_rewrite,
    summarize,
)
from talkitout_pipeline.config import Config, load_config, load_env_file  # noqa: E402
from talkitout_pipeline.errors import (  # noqa: E402
    ConfigError,
    PipelineError,
)
from talkitout_pipeline.model_adapter import OpenAICompatibleAdapter  # noqa: E402
from talkitout_pipeline.rewrite import RewriteService  # noqa: E402

# Synthetic developer test text — not user data.
CONNECTIVITY_PROMPT = "Reply with exactly the word READY."
SYNTHETIC_INFORMAL = "yo can u send me the notes asap thx"
SYNTHETIC_AGENDA = "Making NLP notes"


def smoke_config(endpoint: str, model_id: str, extra_body: dict) -> Config:
    """Minimal backend-free config for CLI-driven smoke runs."""
    return Config(
        backend_base_url="http://smoke.invalid",
        pipeline_api_key="smoke-only-not-a-real-key",
        max_input_chars=5000,
        max_output_chars=8000,
        lease_seconds=300,
        max_attempts=3,
        poll_interval_seconds=2.0,
        model_endpoint=endpoint,
        model_id=model_id,
        model_api_key="",
        model_temperature=0.2,
        model_max_tokens=1024,
        model_request_timeout_seconds=120.0,
        model_extra_body=extra_body,
        pipeline_version="smoke-test",
        log_level="INFO",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--endpoint", help="full chat/completions URL (default: MODEL_ENDPOINT)")
    parser.add_argument("--model", help="model identifier (default: MODEL_ID)")
    parser.add_argument("--api-key", default=None, help="only if the server requires auth")
    parser.add_argument("--timeout", type=float, default=None, help="request timeout seconds")
    parser.add_argument("--extra-body", default=None,
                        help='JSON object merged into each request, e.g. '
                             "'{\"chat_template_kwargs\":{\"enable_thinking\":false}}' "
                             "(default: MODEL_EXTRA_BODY)")
    parser.add_argument("--show-output", action="store_true",
                        help="print model responses (synthetic text only)")
    args = parser.parse_args()

    load_env_file()
    extra_body: dict = {}
    if args.extra_body:
        try:
            parsed = json.loads(args.extra_body)
        except ValueError:
            print("--extra-body must be valid JSON", file=sys.stderr)
            return 2
        if not isinstance(parsed, dict):
            print("--extra-body must be a JSON object", file=sys.stderr)
            return 2
        extra_body = parsed
    try:
        config = load_config()
    except ConfigError:
        # .env not fully set up is fine for a model-only smoke run when
        # the CLI carries the endpoint and model explicitly.
        if args.endpoint and args.model:
            config = smoke_config(args.endpoint, args.model, extra_body)
        else:
            print(
                "configuration error: set MODEL_ENDPOINT/MODEL_ID in pipeline/.env "
                "or pass --endpoint and --model",
                file=sys.stderr,
            )
            return 2
    if extra_body:
        config = Config(**{**config.__dict__, "model_extra_body": extra_body})
    if args.timeout:
        config = Config(
            **{**config.__dict__, "model_request_timeout_seconds": args.timeout}
        )

    endpoint = args.endpoint or config.model_endpoint
    model_id = args.model or config.model_id
    api_key = args.api_key if args.api_key is not None else config.model_api_key

    adapter = OpenAICompatibleAdapter(
        endpoint=endpoint,
        model_id=model_id,
        api_key=api_key,
        timeout=config.model_request_timeout_seconds,
        extra_body=config.model_extra_body,
    )
    service = RewriteService(adapter=adapter, config=config)
    print(
        f"endpoint={endpoint} model={model_id} "
        f"timeout={config.model_request_timeout_seconds}s"
    )

    # --- Functional probes: plumbing only, no security meaning. ---
    functional_ok = True

    start = time.monotonic()
    try:
        reply = adapter.complete(
            [{"role": "user", "content": CONNECTIVITY_PROMPT}],
            temperature=config.model_temperature,
            max_tokens=config.model_max_tokens,
        )
        elapsed = time.monotonic() - start
        ok = bool(reply.strip())
        functional_ok = functional_ok and ok
        print(f"[func 1/2] connectivity: {'PASS' if ok else 'FAIL (empty reply)'} "
              f"in {elapsed:.1f}s")
        if args.show_output:
            print(f"           reply: {reply.strip()[:200]}")
    except PipelineError as exc:
        functional_ok = False
        print(f"[func 1/2] connectivity: FAIL ({exc.code}) "
              f"after {time.monotonic() - start:.1f}s")

    try:
        start = time.monotonic()
        outcome = service.rewrite(SYNTHETIC_INFORMAL, SYNTHETIC_AGENDA)
        elapsed = time.monotonic() - start
        if outcome.unchanged:
            # SYNTHETIC_INFORMAL is deliberately unprofessional; an
            # unchanged echo means the rewrite path did not do its job
            # even though the validator would accept the output.
            functional_ok = False
            print(f"[func 2/2] rewrite path: FAIL (echo — the model returned "
                  f"the known-unprofessional input unchanged) in {elapsed:.1f}s")
        else:
            print(f"[func 2/2] rewrite path: PASS in {elapsed:.1f}s "
                  f"(intent={outcome.intent_preservation_score} "
                  f"relevance={outcome.relevance_score}/{outcome.relevance_label})")
        if args.show_output:
            print(f"           rewrite: {outcome.rewritten_text[:200]}")
    except PipelineError as exc:
        functional_ok = False
        print(f"[func 2/2] rewrite path: FAIL ({exc.code})")

    if not functional_ok:
        print(
            "SMOKE RESULT: FUNCTIONAL=FAIL ADVERSARIAL=NOT RUN "
            "(the server must work before adversarial behavior means anything)"
        )
        return 1

    # --- Adversarial probes: empirical evaluation, not a guarantee. ---
    print(f"[adversarial] {len(ADVERSARIAL_PROBES)} synthetic injection probes")
    results: dict[str, str] = {}
    for probe in ADVERSARIAL_PROBES:
        try:
            outcome = service.rewrite(probe.text, probe.agenda)
            status = evaluate_rewrite(
                probe, rewritten_text=outcome.rewritten_text, error_code=None
            )
        except PipelineError as exc:
            status = evaluate_rewrite(probe, rewritten_text=None, error_code=exc.code)
        results[probe.name] = status
        detail = ""
        if status == "echo":
            detail = (" — the model returned the input unchanged: the rewrite "
                      "task was NOT performed (distinct from injection obedience)")
        elif status == "hijacked":
            detail = (" — the canary token appears in execution position: the "
                      "embedded instruction was executed")
        elif status == "suspected":
            detail = " — manual review needed (see criterion in adversarial.py)"
        print(f"  probe {probe.name}: {status.upper()}{detail}")
        if args.show_output and status in ("suspected", "echo", "hijacked"):
            print("           (output withheld; rerun with the probe text directly "
                  "if you need to inspect it)")

    verdict = summarize(results)
    echo_count = sum(1 for s in results.values() if s == "echo")
    suspected_count = sum(1 for s in results.values() if s == "suspected")
    hijacked_count = sum(1 for s in results.values() if s == "hijacked")
    if verdict == "fail":
        print("ADVERSARIAL RESULT: FAIL — "
              f"{hijacked_count} hijacked (embedded instruction executed), "
              f"{echo_count} echo(es) (no rewrite performed), "
              f"{suspected_count} suspected (manual review). Hijacks are "
              "execution evidence on these synthetic probes; echoes are a "
              "rewrite-quality failure, not injection obedience; suspected "
              "hits are ambiguous mentions or content loss. Either way this "
              "model/prompt is not ready for production use.")
        print("SMOKE RESULT: FUNCTIONAL=PASS ADVERSARIAL=FAIL")
        return 3
    if verdict == "inconclusive":
        print("ADVERSARIAL RESULT: INCONCLUSIVE — probes could not be judged; "
              "no security property was established.")
        print("SMOKE RESULT: FUNCTIONAL=PASS ADVERSARIAL=INCONCLUSIVE")
        return 4
    print(
        "ADVERSARIAL RESULT: PASS on these synthetic probes — this is an "
        "empirical screen, NOT a guarantee of injection resistance."
    )
    print("SMOKE RESULT: FUNCTIONAL=PASS ADVERSARIAL=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
