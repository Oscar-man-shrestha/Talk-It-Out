"""Serve the rewrite model on a Kaggle GPU and expose it through a tunnel.

Run inside a Kaggle notebook (GPU T4 + Internet on), in one cell:

    import urllib.request
    exec(urllib.request.urlopen(
        "https://raw.githubusercontent.com/Oscar-man-shrestha/Talk-It-Out/"
        "temp/local-stack-run066/pipeline/scripts/kaggle_serve.py").read())

What it does (see pipeline/KAGGLE_ENDPOINT_RUNBOOK.md):
1. installs vLLM if missing (same command as model-endpoint-1.ipynb)
2. starts vLLM with Qwen2.5-3B-Instruct, the validated T4 settings, and a
   freshly generated API key, so the tunnelled server is not open
3. opens a Cloudflare quick tunnel to it
4. prints the endpoint URL and the key ONCE for the local pipeline/.env

The key is random per run and never written to disk. Clear the cell output
before saving or downloading the notebook. Contains no secrets itself.
"""

import importlib.util
import os
import re
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

HF_MODEL = "Qwen/Qwen2.5-3B-Instruct"
SERVED_NAME = "qwen2.5-3b-instruct"
PORT = 8000
MAX_MODEL_LEN = 4096
VLLM_LOG = "/tmp/vllm.log"
TUNNEL_LOG = "/tmp/cloudflared.log"
CLOUDFLARED = "/tmp/cloudflared"
CLOUDFLARED_URL = (
    "https://github.com/cloudflare/cloudflared/releases/latest/download/"
    "cloudflared-linux-amd64"
)


def log(msg: str) -> None:
    print(f"[kaggle_serve] {msg}", flush=True)


def models_ok(key: str) -> bool:
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORT}/v1/models", headers={"Authorization": f"Bearer {key}"}
    )
    try:
        urllib.request.urlopen(req, timeout=3)
        return True
    except Exception:
        return False


def main() -> None:
    if not shutil.which("nvidia-smi"):
        raise SystemExit("No GPU: set Session options -> Accelerator -> GPU T4 and rerun.")

    if importlib.util.find_spec("vllm") is None:
        log("installing vLLM (several minutes)...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "vllm"])
    else:
        log("vLLM already installed")

    key = secrets.token_urlsafe(32)
    subprocess.run(["pkill", "-f", "vllm serve"], check=False)
    subprocess.run(["pkill", "-f", "cloudflared"], check=False)
    time.sleep(3)

    os.environ.setdefault("VLLM_WORKER_MULTIPROC_METHOD", "spawn")
    vllm_bin = shutil.which("vllm")
    base = [vllm_bin, "serve"] if vllm_bin else [
        sys.executable, "-m", "vllm.entrypoints.openai.api_server", "--model"]
    cmd = base + [
        HF_MODEL,
        "--served-model-name", SERVED_NAME,
        "--max-model-len", str(MAX_MODEL_LEN),
        "--dtype", "half",
        "--port", str(PORT),
        "--gpu-memory-utilization", "0.90",
        "--api-key", key,
    ]
    log("starting vLLM (first start downloads weights)...")
    subprocess.Popen(
        cmd,
        stdout=open(VLLM_LOG, "w"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    for i in range(180):
        if models_ok(key):
            log(f"vLLM ready after ~{i * 5}s (API key required)")
            break
        time.sleep(5)
    else:
        print(open(VLLM_LOG).read()[-4000:])
        raise SystemExit("vLLM did not become ready; log tail above.")

    if not os.path.exists(CLOUDFLARED):
        urllib.request.urlretrieve(CLOUDFLARED_URL, CLOUDFLARED)
        os.chmod(CLOUDFLARED, 0o755)
    subprocess.Popen(
        [CLOUDFLARED, "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{PORT}"],
        stdout=open(TUNNEL_LOG, "w"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    url = None
    for _ in range(60):
        match = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", open(TUNNEL_LOG).read())
        if match:
            url = match.group(0)
            break
        time.sleep(2)
    if not url:
        print(open(TUNNEL_LOG).read()[-3000:])
        raise SystemExit("Tunnel URL not found; log tail above.")

    # Confirm the tunnel reaches vLLM and that auth is enforced.
    time.sleep(5)
    try:
        urllib.request.urlopen(f"{url}/v1/models", timeout=20)
        log("WARNING: the endpoint answered WITHOUT a key")
    except urllib.error.HTTPError as exc:
        log(f"unauthenticated request rejected as expected (HTTP {exc.code})")
    except Exception as exc:  # tunnel DNS can lag a few seconds
        log(f"unauthenticated probe inconclusive: {type(exc).__name__}")

    print("\n=== copy into pipeline/.env, then clear this output ===")
    print(f"MODEL_ENDPOINT={url}/v1/chat/completions")
    print(f"MODEL_ID={SERVED_NAME}")
    print(f"MODEL_API_KEY={key}")
    print("=== vLLM and the tunnel keep running until the session stops ===")


main()
