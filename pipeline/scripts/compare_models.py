"""Compare rewrite quality of two (or more) models on the same synthetic set.

SYNTHETIC TEXT ONLY: every message below is made-up developer test text,
never user data. By default only scores, error codes and timings are
printed; --show-output also prints the rewrites (safe: synthetic only).

For each model and each sample it records, through the worker's real
rewrite path and validator:
- ok:        the rewrite passed the validator (would reach the controller)
- softened:  the rewrite added hedging ("might", "unsure", ...) that the
             original did not have, i.e. a definite complaint became
             uncertain (the failure seen with qwen2.5:3b in Run 072)
- echo:      the message came back unchanged although it needs rewriting
- seconds:   wall time of the model call
Then the adversarial probes (talkitout_pipeline/adversarial.py) run too.

Usage (from pipeline/):
    python3 scripts/compare_models.py qwen2.5:3b qwen2.5:7b
"""

from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from talkitout_pipeline.adversarial import ADVERSARIAL_PROBES, evaluate_rewrite, summarize  # noqa: E402
from talkitout_pipeline.config import load_env_file  # noqa: E402
from talkitout_pipeline.errors import PipelineError  # noqa: E402
from talkitout_pipeline.model_adapter import OpenAICompatibleAdapter  # noqa: E402
from talkitout_pipeline.rewrite import RewriteService  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from smoke_model import smoke_config  # noqa: E402

AGENDA = "Dashboard improvements"

# (synthetic message, needs rewriting?)
SAMPLES: list[tuple[str, bool]] = [
    ("nobody fixed the login bug and it's been 3 weeks, this is ridiculous", True),
    ("the dashboard is still broken. nobody has looked at it", True),
    ("I'm sick of the charts not loading. we never get an answer from the team", True),
    ("who approved this garbage design?? it doesn't show half the data", True),
    ("stop ignoring the export bug. it fails every single time on files over 10 MB", True),
    ("the new filters are useless and nobody asked for them", True),
    ("why do we keep shipping without tests? the last 2 releases broke the dashboard", True),
    ("honestly the loading spinner takes 30 seconds, it's unusable", True),
    ("this is the third time I report this: the date picker shows the wrong month", True),
    ("the team lead never replies to dashboard tickets, it's not ok", True),
    ("Could we add a dark mode option to the dashboard next sprint?", False),
    ("Thanks for fixing the export button, it works well now.", False),
]

_HEDGES = re.compile(
    r"\b(might|may have|maybe|perhaps|possibly|unsure|not sure|i wonder|"
    r"it seems|seems like|i'm unclear|it appears|could be|i believe)\b",
    re.IGNORECASE,
)


def softened(original: str, rewrite: str) -> bool:
    return bool(_HEDGES.search(rewrite)) and not _HEDGES.search(original)


def run_model(model: str, endpoint: str, show: bool) -> dict:
    config = smoke_config(endpoint, model, {})
    adapter = OpenAICompatibleAdapter(
        endpoint=endpoint, model_id=model, timeout=config.model_request_timeout_seconds
    )
    service = RewriteService(adapter, config)
    stats = {"ok": 0, "softened": 0, "echo": 0, "errors": {}, "seconds": []}
    for text, needs in SAMPLES:
        start = time.monotonic()
        try:
            out = service.rewrite(text, AGENDA)
            elapsed = time.monotonic() - start
            stats["ok"] += 1
            soft = softened(text, out.rewritten_text)
            echo = needs and out.unchanged
            stats["softened"] += int(soft)
            stats["echo"] += int(echo)
            flag = " SOFTENED" if soft else (" ECHO" if echo else "")
            print(f"  [{model}] ok   {elapsed:5.1f}s intent={out.intent_preservation_score:.2f}{flag}")
            if show:
                print(f"      > {out.rewritten_text}")
        except PipelineError as err:
            elapsed = time.monotonic() - start
            code = getattr(err, "code", type(err).__name__)
            stats["errors"][code] = stats["errors"].get(code, 0) + 1
            print(f"  [{model}] FAIL {elapsed:5.1f}s {code}")
        stats["seconds"].append(elapsed)

    probe_results: dict[str, str] = {}
    for probe in ADVERSARIAL_PROBES:
        try:
            out = service.rewrite(probe.text, probe.agenda)
            status = evaluate_rewrite(probe, rewritten_text=out.rewritten_text, error_code=None)
        except PipelineError as err:
            status = evaluate_rewrite(
                probe, rewritten_text=None, error_code=getattr(err, "code", "error")
            )
        probe_results[probe.name] = status
    stats["probes"] = probe_results
    stats["probe_verdict"] = summarize(probe_results)
    return stats


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("models", nargs="+")
    parser.add_argument("--endpoint", default=None)
    parser.add_argument("--show-output", action="store_true")
    args = parser.parse_args()
    load_env_file()
    import os

    endpoint = args.endpoint or os.environ.get(
        "MODEL_ENDPOINT", "http://127.0.0.1:11434/v1/chat/completions"
    )
    results = {}
    for model in args.models:
        print(f"== {model}")
        results[model] = run_model(model, endpoint, args.show_output)

    print("\nmodel            usable  softened  echo  avg s  probes")
    n = len(SAMPLES)
    for model, s in results.items():
        usable = s["ok"] - s["softened"] - s["echo"]
        avg = sum(s["seconds"]) / len(s["seconds"])
        print(
            f"{model:<16} {usable:>2}/{n}   {s['softened']:>3}     {s['echo']:>3}  "
            f"{avg:5.1f}  {s['probe_verdict']} {s['probes']}"
        )
        if s["errors"]:
            print(f"{'':<16} errors: {s['errors']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
