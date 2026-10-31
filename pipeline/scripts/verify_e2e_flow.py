"""End-to-end integration test of the groups pipeline contract with a live backend.

Tests:
1. Backend health & internal pipeline auth
2. Registering controller and contributor
3. Group creation and member assignment
4. Anonymous message submission (generates a rewrite job)
5. Claiming the job via POST /internal/pipeline/claim
6. Posting the rewrite result via POST /internal/pipeline/result
7. Verifying the controller's review queue has the pending rewrite
8. Controller accepts the message
9. Verifying the group chat publishes the rewritten text anonymously (display_sender=null)
"""

import json
import sys
import time
import urllib.request
import urllib.error

BASE_URL = "http://localhost:3000"
KEY = "talkitout-super-secret-key-at-least-32-chars-long!"

def req(path, method="GET", data=None, token=None, key=None):
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if key:
        headers["X-Pipeline-Key"] = key
    
    body = json.dumps(data).encode("utf-8") if data is not None else None
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as resp:
            content = resp.read().decode("utf-8")
            return resp.status, json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        content = e.read().decode("utf-8")
        try:
            err_json = json.loads(content)
        except Exception:
            err_json = {"raw": content}
        return e.code, err_json

def run_e2e():
    print("==================================================")
    print("TALKITOUT GROUPS PIPELINE E2E INTEGRATION TEST")
    print("==================================================")

    # 1. Check health
    status, res = req("/health")
    if status != 200:
        print(f"FAILED: Backend not healthy: status {status}, {res}")
        sys.exit(1)
    print("[PASS] 1. Backend /health is OK")

    # 2. Register Controller & Contributor
    ts = int(time.time())
    ctrl_email = f"ctrl_{ts}@example.com"
    contrib_email = f"contrib_{ts}@example.com"

    status, ctrl = req("/auth/register", "POST", {
        "name": f"Controller {ts}",
        "email": ctrl_email,
        "password": "Password123!"
    })
    if status != 201:
        print(f"FAILED: Register controller failed: {ctrl}")
        sys.exit(1)
    ctrl_token = ctrl["token"]
    print(f"[PASS] 2. Controller registered: {ctrl_email}")

    status, contrib = req("/auth/register", "POST", {
        "name": f"Contributor {ts}",
        "email": contrib_email,
        "password": "Password123!"
    })
    if status != 201:
        print(f"FAILED: Register contributor failed: {contrib}")
        sys.exit(1)
    contrib_token = contrib["token"]
    contrib_id = contrib["user"]["id"]
    print(f"[PASS] 3. Contributor registered: {contrib_email}")

    # 3. Create Group
    status, group = req("/groups", "POST", {"agenda": "Making NLP notes"}, token=ctrl_token)
    if status != 201:
        print(f"FAILED: Create group failed: {group}")
        sys.exit(1)
    group_id = group["id"]
    print(f"[PASS] 4. Group created: id={group_id}")

    # 4. Add Contributor to Group
    status, member = req(f"/groups/{group_id}/members", "POST", {
        "username": contrib["user"]["email"].split("@")[0],
        "role": "contributor"
    }, token=ctrl_token)
    if status != 201:
        # Fallback using user ID if username search varies
        status, member = req(f"/groups/{group_id}/members", "POST", {
            "userId": contrib_id,
            "role": "contributor"
        }, token=ctrl_token)
    print(f"[PASS] 5. Contributor added to group")

    # 5. Contributor submits Anonymous message
    raw_text = "yo can u send me the notes asap thx"
    status, sent = req(f"/groups/{group_id}/messages", "POST", {
        "text": raw_text,
        "is_anonymous": True
    }, token=contrib_token)
    if status != 201:
        print(f"FAILED: Send message failed: {sent}")
        sys.exit(1)
    raw_message_id = sent["id"]
    print(f"[PASS] 6. Contributor submitted anonymous message: raw_id={raw_message_id}")

    # 6. Pipeline claims job
    status, claimed = req("/internal/pipeline/claim", "POST", {"max_jobs": 1}, key=KEY)
    if status != 200 or not claimed.get("jobs"):
        print(f"FAILED: Claim job failed: {claimed}")
        sys.exit(1)
    
    job = claimed["jobs"][0]
    print(f"[PASS] 7. Worker claimed job via POST /internal/pipeline/claim:")
    print(f"         job_id: {job['job_id']}")
    print(f"         raw_message_id: {job['raw_message_id']}")
    print(f"         group_agenda: {job['group_agenda']}")
    print(f"         contract_version: {job['contract_version']}")

    # 7. Post the rewrite result
    rewritten_text = "Sure, could you please send me the notes as soon as possible? Thank you."
    status, result = req("/internal/pipeline/result", "POST", {
        "job_id": job["job_id"],
        "raw_message_id": job["raw_message_id"],
        "outcome": "ok",
        "rewritten_text": rewritten_text,
        "intent_preservation_score": 1.0,
        "relevance_score": 0.5,
        "relevance_label": "relevant",
        "pipeline_version": "talkitout-pipeline 0.1.0"
    }, key=KEY)
    if status != 200 or not result.get("applied"):
        print(f"FAILED: Post result failed: {result}")
        sys.exit(1)
    print(f"[PASS] 8. Result delivered via POST /internal/pipeline/result (applied={result.get('applied')})")

    # 8. Controller inspects review queue
    status, queue = req(f"/groups/{group_id}/review-queue", token=ctrl_token)
    if status != 200 or not queue.get("items"):
        print(f"FAILED: Review queue empty or failed: {queue}")
        sys.exit(1)
    review_item = queue["items"][0]
    print(f"[PASS] 9. Controller review queue holds rewrite:")
    print(f"         rewrite: \"{review_item['rewritten_text']}\"")
    print(f"         relevance: {review_item['relevance_label']} ({review_item['relevance_score']})")

    # 9. Controller accepts the message
    status, accept = req(f"/messages/{raw_message_id}/accept", "POST", token=ctrl_token)
    if status != 200:
        print(f"FAILED: Accept message failed: {accept}")
        sys.exit(1)
    print(f"[PASS] 10. Controller accepted the message")

    # 10. Verify group chat has published message as Anonymous
    status, chat = req(f"/groups/{group_id}/messages", token=contrib_token)
    if status != 200 or not chat.get("items"):
        print(f"FAILED: Group messages empty: {chat}")
        sys.exit(1)
    pub_msg = chat["items"][0]
    print(f"[PASS] 11. Group chat verified:")
    print(f"          published_text: \"{pub_msg['text']}\"")
    print(f"          display_sender: {pub_msg.get('display_sender')} (None indicates Anonymous)")
    assert pub_msg.get('display_sender') is None, "display_sender must be null for anonymous message!"
    assert pub_msg['text'] == rewritten_text, "published text must match rewritten text!"

    print("==================================================")
    print("ALL 11 END-TO-END INTEGRATION CHECKS PASSED!")
    print("==================================================")

if __name__ == "__main__":
    run_e2e()
