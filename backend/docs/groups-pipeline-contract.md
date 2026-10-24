# Groups Pipeline Integration Contract

**contract_version: 1** (this exact value travels in every claim payload;
breaking changes bump it and are announced to worker owners first)

Audience: the teammate building the real groups rewrite pipeline (Python).
The backend side of this contract lives in `src/internal/pipeline.ts`; the
HTTP and database schema the Flutter app uses do **not** change because of
it. This contract deliberately mirrors the conventions of the feed-analysis
adapter (`src/feed-analysis/`): versioned boundary, strict result
validation, bounded retries, stale-result discarding, and no logging of raw
text on either side.

The backend contains **no NLP, rewriting, scoring, or classification
logic**. Until the real pipeline plugs in, a clearly-labeled stub
(`src/worker/stubWorker.ts`, prefix `[stub rewrite]`, constant scores)
processes jobs in-process.

## 1. Integration modes

- **Mode A (default, recommended): claim/result over HTTP.** The worker
  polls `POST /internal/pipeline/claim`, processes the returned jobs, and
  posts one decision per job to `POST /internal/pipeline/result` (or
  `POST /internal/pipeline/fail`). The worker never opens a database
  connection and is never given database credentials.
- **Mode B: direct database access — NOT offered.** Workers must not read
  or write `raw_messages`, `jobs`, or any other table. The backend is the
  only writer; the internal API is the only door.

Exactly one consumer mode runs at a time, controlled by `PIPELINE_MODE`:

- `PIPELINE_MODE=stub` (default): the in-process stub worker runs as today.
- `PIPELINE_MODE=external`: the stub worker is suppressed at startup, so
  the in-process and external consumers can never compete for jobs. The
  external worker is then the only claimant.

## 2. Claiming work — `POST /internal/pipeline/claim`

Request (optional): `{"max_jobs": 5}` — at most 10, default 5.

The backend claims due jobs with `FOR UPDATE SKIP LOCKED` (multiple worker
processes may poll concurrently), marks them `running`, and sets their
lease (see §6). Jobs whose lease has expired become claimable again.
Jobs whose message has already been accepted/rejected are marked done by
the backend and never handed out.

Response `200`:

```json
{
  "jobs": [
    {
      "job_id": "8e1f...-uuid of the jobs row",
      "raw_message_id": "b2a4...-uuid of the raw_messages row",
      "text": "the original message text submitted by the contributor",
      "group_agenda": "Making NLP notes",
      "contract_version": 1
    }
  ]
}
```

`jobs` is empty when there is nothing due. Poll interval of a few seconds
is appropriate.

### What is NEVER sent to the worker

- sender identity (no user id, no username, no name, no email),
- `is_anonymous` (the worker must not even learn whether a message was
  anonymous),
- any other member's data,
- credentials, tokens, or group identifiers beyond the agenda text.

The payload keys are exactly `job_id`, `raw_message_id`, `text`,
`group_agenda`, `contract_version`. Nothing else is added.

## 3. Reporting a result — `POST /internal/pipeline/result`

```json
{
  "job_id": "8e1f...",
  "raw_message_id": "b2a4...",
  "outcome": "ok",
  "rewritten_text": "the moderated rewrite of the message",
  "intent_preservation_score": 0.93,
  "relevance_score": 0.88,
  "relevance_label": "relevant",
  "pipeline_version": "my-pipeline 1.2.0"
}
```

Field rules (enforced with strict schema validation):

| field | when `outcome:"ok"` | when `outcome:"error"` |
|---|---|---|
| `job_id`, `raw_message_id` | required | required |
| `rewritten_text` | required, non-empty, ≤ `PIPELINE_MAX_OUTPUT_CHARS` | absent |
| `intent_preservation_score` | required, number 0..1 | absent |
| `relevance_score` | required, number 0..1 | absent |
| `relevance_label` | required, one of `relevant`, `borderline`, `off_topic` | absent |
| `pipeline_version` | required, non-empty string | absent |
| `error_code` | absent | required, non-empty string (e.g. `model_timeout`) |

**Relevance is advisory only.** Scores and labels are shown to the group
controller to help review. They never hide, reject, or auto-approve a
message, and the backend will not build relevance-based hiding. The worker
must not refuse to return `ok` because relevance is low.

Response `200`, one of:

- `{"applied": true}` — the rewrite is stored; the message becomes
  controller-reviewable.
- `{"applied": false, "reason": "message_decided"}` — the message was
  accepted/rejected meanwhile; the result is discarded and the job is done.
- `{"applied": false, "reason": "already_done"}` — duplicate result for a
  finished job; idempotent no-op.
- `{"applied": false, "reason": "unknown_job"}` — no such job.
- `{"applied": false, "reason": "error_recorded"}` — `outcome:"error"`
  recorded as a failed attempt (retry scheduled).
- `{"applied": false, "reason": "failed_permanently"}` — `outcome:"error"`
  after the final allowed attempt.

An invalid body (wrong shape, missing fields, over-long rewrite, score out
of range) returns the standard `422` error envelope **and counts as a
failed attempt** for that job.

## 4. Reporting a failure — `POST /internal/pipeline/fail`

For workers that fail before producing any payload (crash, exception):
`{"job_id": "...", "error_code": "worker_crash"}`. Same response shapes as
§3. Only a `running` job can be failed; failing a job in another state is
a no-op (`{"applied": false, "reason": "not_running"}`). `outcome:"error"`
via `/result` is equivalent.

## 5. Idempotency and stale results

- Resubmitting the same `job_id` result is a no-op (`applied:false`,
  `already_done`), never an error, never a duplicate side effect.
- A result for a message that is no longer `pending` is discarded
  (`message_decided`); a decision (accept/reject) made while the pipeline
  runs always wins.
- Results are applied in one transaction: `pipeline_status='done'`,
  `rewritten_text`, both scores, and the label are written together with
  the job's `done` status.

## 6. Limits, leases, retries

| setting | env var | default |
|---|---|---|
| max input characters (rejected at submission with 422) | `PIPELINE_MAX_INPUT_CHARS` | 5000 |
| max `rewritten_text` characters (longer result = failed attempt) | `PIPELINE_MAX_OUTPUT_CHARS` | 8000 |
| lease: seconds before a `running` job is claimable again | `PIPELINE_LEASE_SECONDS` | 300 |
| attempts before permanent failure | `PIPELINE_MAX_ATTEMPTS` | 3 |

- The worker should keep **one in-flight job at a time per process** and
  finish within the lease, or report a failure before the lease expires.
- There is no server-side per-job timeout: the lease is the timeout. A job
  whose lease expired is handed to the next claim; claims count as
  attempts, so a crash-looping worker eventually fails the job.
- Retry backoff after a failed attempt is `2s × attempts` (server-side).
- `error_code` is recorded in logs (job id + code only); no text is logged.

## 7. Failure semantics (end state)

After the final allowed attempt: `jobs.status='failed'` and
`raw_messages.pipeline_status='failed'`. The message **stays
`status='pending'` and controller-reviewable** — it is never dropped or
auto-rejected. Accepting a message with no rewrite returns
`409 {"error":{"code":"no_rewrite","message":"This message has no rewrite yet."}}`
(unchanged API behavior; the controller sees the original text in the
review queue and may reject it).

## 8. Authentication

- Header: `X-Pipeline-Key: <PIPELINE_API_KEY>` on every internal call.
- The backend compares keys in constant time.
- If `PIPELINE_API_KEY` is unset, every `/internal/pipeline/*` route is
  disabled and returns `503 {"error":{"code":"internal_api_disabled",...}}`.
- Wrong or missing key: `401 {"error":{"code":"invalid_pipeline_key",...}}`.
- The key is a shared secret for this API only; it grants no other access.

## 9. Privacy rules (both sides)

- Message text exists only in the claim payload and the result body.
- **Neither side logs raw text.** The backend logs job ids, outcomes, and
  error codes only; workers must do the same (no `print` of `text` or
  `rewritten_text`, no raw bodies in access logs).
- The worker learns nothing about the sender (see §2) and must not try to
  infer identity from text.
- Transport: run the worker on the same host or a private network; the
  internal routes are not exposed through the Flutter-facing base paths.

## 10. Worked example (fake worker)

`backend/scripts/fake-external-worker.sh` is a **test tool, not a
pipeline**: it claims one job and posts a canned rewrite with constant
scores. See §11 for a real worker's loop.

## 11. How a Python worker calls this

```python
# sketch only — the real pipeline logic lives on your side
import time, requests

BASE = "http://localhost:3000"
HEADERS = {"X-Pipeline-Key": PIPELINE_API_KEY}

def poll():
    r = requests.post(f"{BASE}/internal/pipeline/claim",
                      headers=HEADERS, json={"max_jobs": 1}, timeout=10)
    r.raise_for_status()
    return r.json()["jobs"]

def report(job, result):
    r = requests.post(f"{BASE}/internal/pipeline/result",
                      headers=HEADERS, json=result, timeout=10)
    r.raise_for_status()
    return r.json()   # {"applied": bool, "reason": str?}

while True:
    for job in poll():
        try:
            rewrite = my_model_rewrite(job["text"])           # your NLP here
            outcome = {
                "job_id": job["job_id"],
                "raw_message_id": job["raw_message_id"],
                "outcome": "ok",
                "rewritten_text": rewrite.text,
                "intent_preservation_score": rewrite.intent_score,
                "relevance_score": rewrite.relevance_score,
                "relevance_label": rewrite.relevance_label,
                "pipeline_version": "pipeline 1.0.0",
            }
        except Exception as e:
            outcome = {
                "job_id": job["job_id"],
                "raw_message_id": job["raw_message_id"],
                "outcome": "error",
                "error_code": type(e).__name__[:100],
            }
        # never print job["text"] or the rewrite here
        report(job, outcome)
    time.sleep(2)
```

Start the backend with `PIPELINE_MODE=external` and a generated
`PIPELINE_API_KEY`; the stub worker then stays down and your worker is the
only claimant.
