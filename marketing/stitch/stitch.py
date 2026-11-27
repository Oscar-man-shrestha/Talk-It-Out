"""Tiny client for the Stitch MCP endpoint (key read from ~/.claude.json)."""
import json, sys, urllib.request
from pathlib import Path

KEY = json.loads((Path.home() / ".claude.json").read_text())["mcpServers"]["stitch"]["headers"]["X-Goog-Api-Key"]
URL = "https://stitch.googleapis.com/mcp"


def rpc(method, params=None, timeout=600):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}}).encode()
    req = urllib.request.Request(URL, body, {"X-Goog-Api-Key": KEY, "Content-Type": "application/json",
                                             "Accept": "application/json, text/event-stream"})
    txt = urllib.request.urlopen(req, timeout=timeout).read().decode()
    txt = txt[txt.find("{"):]
    return json.loads(txt)


def call(name, args, timeout=600):
    r = rpc("tools/call", {"name": name, "arguments": args}, timeout)
    if "error" in r:
        raise RuntimeError(r["error"])
    res = r["result"]
    out = []
    for c in res.get("content", []):
        if c.get("type") == "text":
            out.append(c["text"])
    if res.get("structuredContent"):
        return res["structuredContent"]
    joined = "\n".join(out)
    try:
        return json.loads(joined)
    except ValueError:
        return joined


if __name__ == "__main__":
    if sys.argv[1] == "schema":
        tools = rpc("tools/list")["result"]["tools"]
        for t in tools:
            if t["name"] in sys.argv[2:]:
                print(t["name"], json.dumps(t["inputSchema"])[:1500], "\n")
    else:
        print(json.dumps(call(sys.argv[1], json.loads(sys.argv[2])), indent=1)[:4000])
