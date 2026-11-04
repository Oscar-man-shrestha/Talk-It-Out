# Connecting the local worker to the Kaggle model

Closes the gap recorded in `LOGS.md` Runs 064–067: vLLM serves
Qwen2.5-3B-Instruct inside the Kaggle notebook, but only on the notebook's
own `127.0.0.1`, so the worker on a laptop cannot reach it.

This runbook adds **API-key auth** to vLLM and exposes it through a
temporary Cloudflare tunnel. Without the key, a tunnel would put an open
model server on the public internet. Never commit the tunnel URL or either
key (`COLAB_EVALUATION.md`, "After choosing Kaggle or Hugging Face").
`pipeline/.env` and `backend/.env` are gitignored.

## 0. On the laptop: get the model key

`pipeline/.env` already holds a generated `MODEL_API_KEY`. Copy its value.
Do not paste it into a notebook cell; use Kaggle Secrets.

In Kaggle: **Add-ons → Secrets → Add secret**, label `MODEL_API_KEY`, paste
the value, and attach it to `model-endpoint-1`. Turn **Internet on** in the
notebook settings.

## 1. Kaggle: restart vLLM with the key

Run the notebook's normal cells up to and including the vLLM install. Then,
**instead of** the existing "start vLLM" cell, run:

```python
import os, shutil, subprocess, time, urllib.request
from kaggle_secrets import UserSecretsClient

MODEL_API_KEY = UserSecretsClient().get_secret("MODEL_API_KEY")
subprocess.run(["pkill", "-f", "vllm serve"], check=False)
time.sleep(5)
vllm = subprocess.Popen(
    [shutil.which("vllm"), "serve", HF_MODEL,
     "--served-model-name", SERVED_NAME,
     "--max-model-len", str(MAX_MODEL_LEN), "--dtype", "half",
     "--port", str(PORT), "--gpu-memory-utilization", "0.90",
     "--api-key", MODEL_API_KEY],
    stdout=open(VLLM_LOG, "w"), stderr=subprocess.STDOUT, start_new_session=True,
)
for _ in range(120):
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{PORT}/v1/models",
                                     headers={"Authorization": f"Bearer {MODEL_API_KEY}"})
        urllib.request.urlopen(req, timeout=3); print("vLLM ready (key required)"); break
    except Exception:
        time.sleep(5)
else:
    print(open(VLLM_LOG).read()[-3000:])
```

## 2. Kaggle: open the tunnel

```python
import re, subprocess, time, urllib.request
urllib.request.urlretrieve(
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64",
    "/tmp/cloudflared")
subprocess.run(["chmod", "+x", "/tmp/cloudflared"], check=True)
tunnel = subprocess.Popen(["/tmp/cloudflared", "tunnel", "--no-autoupdate",
                           "--url", f"http://127.0.0.1:{PORT}"],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                          start_new_session=True)
url = None
for line in tunnel.stdout:
    m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", line)
    if m:
        url = m.group(0); break
print(url)
```

Copy the printed `https://….trycloudflare.com` URL. **Clear this cell's
output before saving the notebook or downloading it into the repo.** The URL
dies when the session stops.

## 3. Laptop: point the worker at it

Edit `pipeline/.env`:

```
MODEL_ENDPOINT=https://<your-subdomain>.trycloudflare.com/v1/chat/completions
```

Check the model from the laptop. Synthetic prompts only; `--show-output`
prints the model's answers so the two **SUSPECTED** probes from Run 065
(`output_only_hijack`, `append_token`) can finally be reviewed by a human:

```bash
cd pipeline && python3 scripts/smoke_model.py --show-output
```

Exit code `0` = functional and adversarial PASS. Exit code `3` = adversarial
FAIL/SUSPECTED; read the printed outputs and record the verdict in
`LOGS.md`. Do not paste real user messages into either.

## 4. Laptop: switch the backend to the external worker

In `backend/.env` set `PIPELINE_MODE=external` (this also turns the
in-process stub off) and restart the backend. Then start the worker:

```bash
cd pipeline && python3 -m talkitout_pipeline
```

Submit a message in a group from the live app (`http://127.0.0.1:52001`) or
with `backend/scripts/demo-flow.sh`. The controller's review queue should
show a real rewrite instead of `[stub rewrite] …`.

To go back to the stub: set `PIPELINE_MODE=stub`, restart the backend, and
stop the worker.

## Why not run the model on the laptop?

`README.md` lists Ollama or llama.cpp as CPU/laptop options. The dev Mac this
was prepared on (8 GB M1) had under 0.5 GB of free disk, and the smallest
validated model needs about 2 GB. Free some disk and that route works too:
point `MODEL_ENDPOINT` at the local server and skip steps 0–2.
