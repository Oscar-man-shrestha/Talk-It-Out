# Temporary GPU notebook handoff: model evaluation

This guide is for a teammate who is setting up a temporary GPU runtime in
Colab, Kaggle, or another notebook. It evaluates the **groups rewrite model**
using synthetic prompts only. It does not run the backend worker loop and
does not need `PIPELINE_API_KEY`, backend access, or real contributor text.

## Current status

The repo already has the model adapter, rewrite service, and evaluator in
`pipeline/`. The last documented real-model checks used Qwen3-4B in Colab;
the latest evaluator changes have not yet been rerun against that model. The
local machine cannot access a notebook's `127.0.0.1` endpoint, so run all
steps below inside the notebook runtime. A fresh Python process is required
after syncing code to avoid stale imports.

## Notebook steps

### 1. Choose a GPU runtime

Select a GPU notebook runtime with enough memory for Qwen3-4B. Verify the
runtime actually exposes a GPU before installing or downloading the model:

```python
!nvidia-smi
```

Runtime availability, GPU type, quotas, and free-tier limits vary. If vLLM
does not support the assigned GPU, choose a compatible inference server and
keep its API OpenAI Chat Completions-compatible.

### 2. Get the repository code into the runtime

Use the repository checkout or upload the current `pipeline/` directory.
Do not copy `.env`, backend credentials, model-provider secrets, or real
message data into the notebook. Ensure the files include at least:

- `talkitout_pipeline/`
- `scripts/smoke_model.py`
- `tests/`

Then start a fresh process (or restart the notebook kernel) after syncing.

### 3. Start a local Qwen3-4B OpenAI-compatible server

For a compatible NVIDIA GPU and a runtime where vLLM supports that GPU:

```python
!pip install -q vllm
!nohup vllm serve Qwen/Qwen3-4B --served-model-name qwen3-4b \
    --max-model-len 8192 --dtype half --port 8000 > /tmp/vllm.log 2>&1 &
```

Wait for startup and verify the local server from the same notebook:

```python
import time, urllib.request

url = "http://127.0.0.1:8000/v1/models"
for attempt in range(60):
    try:
        print(urllib.request.urlopen(url, timeout=5).read().decode()[:500])
        break
    except Exception:
        if attempt == 59:
            raise RuntimeError("Model server did not become ready; inspect /tmp/vllm.log")
        time.sleep(5)
```

If startup fails, inspect only server diagnostics, confirm GPU compatibility,
and adjust the server/runtime choice. Do not expose port 8000 publicly for
this model-only evaluation.

### 4. Run the repo's synthetic model evaluation

Run from the `pipeline/` directory. It makes one functional connectivity
probe, one ordinary rewrite probe, and four synthetic prompt-injection
probes. `--show-output` is safe only because these fixtures are synthetic;
never pass real contributor text to the script.

```python
%cd /path/to/repo/pipeline
!python scripts/smoke_model.py \
    --endpoint http://127.0.0.1:8000/v1/chat/completions \
    --model qwen3-4b \
    --extra-body '{"chat_template_kwargs":{"enable_thinking":false}}' \
    --show-output
```

Interpret the exit code and both verdicts:

- `0`: functional and adversarial probes passed for this run only; not a
  security guarantee.
- `1`: connectivity or ordinary rewrite failed; adversarial probes did not
  run.
- `2`: command/configuration error.
- `3`: at least one adversarial probe was echo, suspected, or hijacked; review
  output/classification and report the exact probe statuses.
- `4`: adversarial evaluation inconclusive due to model errors.

The script reports per-probe statuses. For any ECHO, SUSPECTED, or HIJACKED
result, record the status and synthetic output for teammate review. A canary
mention in the three ambiguous probes is not proof of obedience; only the
append-token probe's documented `HIJACKED` criterion is execution evidence.
Do not describe a passing run as proof that prompt injection is solved.

### 5. Run the offline unit suite

These tests do not require the model server and protect deterministic
behavior. Run them after syncing the code:

```python
!python -m unittest discover -s tests -t .
```

The last recorded result is 148 passing tests. Report the current run's
actual count and any failures; do not rely on the previous result.

## Handoff report to send back

Include the notebook/runtime and GPU type, model/server version, exact smoke
command, exit code, functional verdict, four per-probe statuses, offline test
count, and any errors. Include only synthetic test outputs. Keep credentials
out of the report and repository.

## After choosing Kaggle or Hugging Face

This procedure is the model-only evaluation and is portable to any runtime
that can run the repo's Python code and provide a reachable OpenAI-compatible
endpoint. If the selected service cannot run the code and model in the same
private runtime, use an approved private route; do not put a tunnel URL,
credential, or provider API key in Git. The production worker remains
self-hosted per the current product decision and is connected to the backend
only in a separate integration smoke test with the privately shared
`PIPELINE_API_KEY`.
