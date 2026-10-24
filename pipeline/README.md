# Talk It Out — Python NLP Rewrite Worker

The Python worker that replaces the backend's labeled stub: it claims
groups-message rewrite jobs from the backend's internal API, produces a
professional, meaning-preserving rewrite with a **self-hosted,
OpenAI-compatible model**, and reports the result. It is a separate
component from `backend/`; see `AGENTS.md` in this directory for the
governing rules and `backend/docs/groups-pipeline-contract.md`
(contract_version 1) for the HTTP contract — the source of truth.

**Status: foundation, not production.** No real model endpoint has been
connected; the model layer is tested with mocked HTTP only. The worker
fails honestly (contract `error` outcomes) when inference is unavailable
and never fabricates a rewrite.

## Architecture

```
pipeline/
  talkitout_pipeline/
    __main__.py       entry point: python -m talkitout_pipeline
    config.py         env-based configuration + validation (loads pipeline/.env)
    http_client.py    BackendClient: claim / result / fail, X-Pipeline-Key auth
    model_adapter.py  ModelAdapter protocol + OpenAICompatibleAdapter (self-hosted)
    rewrite.py        prompts, prompt-injection layer, deterministic output validation
    scoring.py        documented deterministic scores (NOT model confidence)
    language.py       English-only gate (decided policy)
    text_utils.py     UTF-16 length parity with the backend's counting
    worker.py         one-job-at-a-time polling loop, clean shutdown, safe logging
  tests/              stdlib unittest suite; no network, mocked inference
```

Data flow per job: `claim (max_jobs=1)` → English gate → model call →
deterministic validation → deterministic scores → `result` (or `error`
outcome / `/fail`). The worker never opens a database connection and
never receives sender identity, `is_anonymous`, or any member data.

## Backend endpoints used (exact, per contract v1)

- `POST /internal/pipeline/claim` — body `{"max_jobs": 1}`; response
  `{"jobs": [{job_id, raw_message_id, text, group_agenda, contract_version}]}`.
- `POST /internal/pipeline/result` — ok payload `{job_id, raw_message_id,
  outcome:"ok", rewritten_text, intent_preservation_score,
  relevance_score, relevance_label, pipeline_version}`; error payload
  `{job_id, raw_message_id, outcome:"error", error_code}`; response
  `{"applied": bool, "reason"?: str}` (duplicates and decided messages
  are documented no-ops).
- `POST /internal/pipeline/fail` — `{job_id, error_code}` (used only for
  unexpected crashes).
- Auth on every call: `X-Pipeline-Key` header; 401 `invalid_pipeline_key`
  and 503 `internal_api_disabled` stop the worker; 429/5xx/network errors
  skip the job (the backend's lease expiry re-queues it — attempts are
  counted per claim, so posting a failure would double-count).

## Configuration

Copy `.env.example` to `.env` and fill in real values (`.env` is
gitignored). All variables:

| Variable | Default | Meaning |
|---|---|---|
| `PIPELINE_BACKEND_BASE_URL` | — (required) | Backend base URL, e.g. `http://localhost:3000` |
| `PIPELINE_API_KEY` | — (required) | Must match the backend's `PIPELINE_API_KEY` |
| `PIPELINE_MAX_INPUT_CHARS` | `5000` | Mirror of the backend's (provisional) input limit |
| `PIPELINE_MAX_OUTPUT_CHARS` | `8000` | Mirror of the backend's (provisional) output limit |
| `PIPELINE_LEASE_SECONDS` | `300` | Mirror of the backend's lease |
| `PIPELINE_MAX_ATTEMPTS` | `3` | Mirror of the backend's retry cap |
| `PIPELINE_POLL_INTERVAL_SECONDS` | `2` | Sleep between empty claims |
| `MODEL_ENDPOINT` | — (required) | Full URL of the self-hosted OpenAI-compatible `/v1/chat/completions` |
| `MODEL_ID` | — (required) | Model identifier the server expects |
| `MODEL_API_KEY` | *(empty)* | Only if your self-hosted server requires auth; NOT a provider key |
| `MODEL_TEMPERATURE` | `0.2` | Generation temperature |
| `MODEL_MAX_TOKENS` | `1024` | Generation cap |
| `MODEL_REQUEST_TIMEOUT_SECONDS` | `120` | Must be shorter than the lease so failures are reported in time |
| `PIPELINE_VERSION` | `talkitout-pipeline 0.1.0` | Sent as `pipeline_version`; bump when the model or prompt changes |
| `PIPELINE_LOG_LEVEL` | `INFO` | Logging level |

The adapter is replaceable: any object with
`complete(messages, *, temperature, max_tokens) -> str` satisfies the
`ModelAdapter` protocol, so another serving stack or a fine-tuned model
can be dropped in without touching orchestration.

## Running

```bash
cd pipeline
python -m talkitout_pipeline          # requires the backend running with
                                      # PIPELINE_MODE=external and a matching key
python -m unittest discover -p "test_*.py"   # test suite (no network needed)
python -m compileall talkitout_pipeline      # syntax check
```

Requires Python 3.10+. No third-party dependencies (stdlib `urllib`),
so there is nothing to install for tests or development.

## Connecting a self-hosted inference server

The worker speaks the OpenAI Chat Completions request/response shape —
nothing more. Exact requirements:

- **Endpoint format:** one full URL in `MODEL_ENDPOINT`, e.g.
  `http://<host>:<port>/v1/chat/completions`. The worker sends a single
  non-streaming POST with `{model, messages, temperature, max_tokens}`.
  Streaming, tools, and logprobs are never used.
- **Response contract:** the server must return HTTP 200 JSON containing
  `choices[0].message.content` as a non-empty string. Anything else maps
  to a fixed model error: 5xx/429 → `model_unavailable`, other non-200
  (including the server's own 401/403) → `model_bad_response`, bad JSON
  or missing fields → `model_bad_response`, empty content →
  `model_empty_output`, timeout → `model_timeout`. The worker then
  reports an honest `error` outcome to the backend; it never fabricates.
- **Model identifier:** `MODEL_ID` must be the exact string the server
  expects. With vLLM that is `--served-model-name` (or the model path);
  with llama.cpp's server it is the model alias; with Ollama the model
  tag (e.g. `qwen3:4b`).
- **Authentication:** optional. If the server enforces a key, set
  `MODEL_API_KEY`; it is sent as `Authorization: Bearer …` to your
  server only. This must never become a third-party provider credential
  and never enters Git or logs.
- **Startup configuration:** put the values in `pipeline/.env` (see
  `.env.example`). `load_config()` validates at startup that
  `MODEL_REQUEST_TIMEOUT_SECONDS < PIPELINE_LEASE_SECONDS` (default
  120 < 300) so a hanging model still lets the worker report failure
  before the backend re-claims the job.

## Smoke test (model only, synthetic text)

`scripts/smoke_model.py` validates the adapter and the full rewrite
path (prompt building → inference → deterministic validation → scores)
against a live endpoint, with no backend and no real user data — every
prompt inside is synthetic developer text:

```bash
cd pipeline
python scripts/smoke_model.py --endpoint http://127.0.0.1:8000/v1/chat/completions \
    --model qwen3-4b --show-output
```

Probes: (1) raw adapter connectivity, (2) the rewrite path with scores,
(3) an informational prompt-injection probe. Output is PASS/FAIL, latency,
and scores; model text is printed only with `--show-output` (safe here —
synthetic text only; never point the script at production traffic).
Exit codes: 0 all probes passed, 1 failure, 2 configuration error.
Against an unreachable endpoint it fails honestly (`model_unavailable`).

## Benchmarking Qwen3-4B on free temporary compute (recommendation)

Qwen3-4B is small: ~8 GB in fp16, ~2.6 GB as a Q4 GGUF. Practical
options, all **temporary** — free notebooks sleep and lose their
runtime, so none of them is a persistent worker host; the real
deployment goes on infrastructure the team controls.

1. **Google Colab free tier (T4 16 GB) — recommended for a first
   benchmark.** vLLM supports the T4; use `--dtype half`:

   ```python
   # Colab cell 1: serve
   !pip install -q vllm
   !nohup vllm serve Qwen/Qwen3-4B --served-model-name qwen3-4b \
       --max-model-len 8192 --dtype half --port 8000 > vllm.log 2>&1 &
   # wait for "Uvicorn running on ...", then cell 2:
   !curl http://127.0.0.1:8000/v1/chat/completions -H "Content-Type: application/json" \
       -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Reply READY."}]}'
   ```

   Run the benchmark inside the same runtime (synthetic prompts only):
   measure p50/p95 end-to-end rewrite latency and tokens/sec over ~20–50
   varied synthetic messages, and replay the injection probe to estimate
   how often the model layer vs the deterministic validator catches it.
   To test the real worker against it, expose the port with a tunnel
   (e.g. `cloudflared tunnel --url http://localhost:8000`) or run the
   worker inside the notebook.

2. **Kaggle notebooks (T4/P100, ~30 h/week)** — same vLLM commands,
   same approach.

3. **CPU-only or laptop (no GPU needed):** llama.cpp's server with a
   Qwen3-4B GGUF (Q4_K_M, ~2.6 GB) or Ollama (`ollama serve` + the
   `qwen3:4b` tag; OpenAI-compatible at `http://127.0.0.1:11434/v1/…`).
   Slower per token, but enough to validate the full worker path and
   measure whether latency fits inside the 300 s lease.

Budget rule: a rewrite must comfortably finish inside
`PIPELINE_LEASE_SECONDS` (300 s default). If p95 latency exceeds ~60–90 s,
either lower `MODEL_REQUEST_TIMEOUT_SECONDS` accordingly or pick a
faster quantization — do not raise the lease to hide slowness.

## Scoring method (deterministic, documented — NOT model confidence)

The contract requires scores on every successful result. They are
computed by fixed, testable heuristics in `scoring.py`:

- **`intent_preservation_score`** — starts at 1.0; −0.25 if the rewrite
  is under 40% of the original's UTF-16 length (possible content loss);
  −0.2 per digit sequence present in the original but absent from the
  rewrite (capped at −0.4); clamped to [0, 1], rounded to 2 decimals.
- **`relevance_score` / `relevance_label`** — the fraction of the group
  agenda's words that appear in the rewrite; `relevant` ≥ 0.50,
  `borderline` ≥ 0.15, else `off_topic`. **Uncalibrated by design and
  advisory only** (contract §3): a low score never hides or rejects a
  message, and the backend treats it the same way.

Hard validation (rejects the output, reports `intent_not_preserved`):
every digit sequence, negation, and URL in the original must survive
into the rewrite; outputs may not exceed 4× the original length, echo
the prompt scaffold, or be blank/over-limit. Limitations: presence
checks are not meaning checks, and numerals must stay numerals — both
are documented trade-offs of deterministic checks.

## Limits status (do not finalize)

The backend's defaults — `PIPELINE_MAX_INPUT_CHARS=5000`,
`PIPELINE_MAX_OUTPUT_CHARS=8000` — are **placeholders** per the
teammate's brief, and the worker mirrors them **provisionally**. The
"2,000 input / 3,000 output" figures floated in discussion are NOT
backend reality and are not adopted. Final values are pending
confirmation after consultation with Claude (see `LOGS.md` Open
Decisions). Note the backend counts characters as UTF-16 code units
(zod string `.max()` on JS strings) — `text_utils.utf16_length` matches
that exactly, including emoji.

## Privacy

- Message text, rewritten text, sender identity, and secrets never
  appear in logs — log lines carry job ids, fixed error codes, and
  response reasons only. `tests` enforce this with sentinels.
- Message text exists only in memory and in the two HTTP bodies the
  contract defines; exceptions carry fixed codes, never content.
- `.env` and model credentials are gitignored; `.env.example` holds
  placeholders only.

## Open items (tracked in LOGS.md)

- Real model endpoint + a prompt-injection evaluation on that model
  (the deterministic layer is tested; the model layer is not).
- Final input/output character limits (pending Claude).
- Hosted-vs-local decision: **resolved as self-hosted** per the team's
  brief; no third-party inference API is used.
- `relevance_label` thresholds are provisional heuristics (D3/D18).
