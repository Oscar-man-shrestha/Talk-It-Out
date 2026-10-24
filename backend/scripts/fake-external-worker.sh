#!/usr/bin/env bash
# TEST TOOL ONLY — this is NOT a pipeline. It exercises the groups pipeline
# contract (docs/groups-pipeline-contract.md) by claiming one job and posting
# a canned result, so the integration can be tried without the Python worker.
#
# Start the backend with:
#   PIPELINE_MODE=external PIPELINE_API_KEY=<key> RUN_STUB_WORKER=true npm run dev
# (RUN_STUB_WORKER is ignored in external mode) and run:
#   PIPELINE_API_KEY=<key> bash scripts/fake-external-worker.sh
#
# Privacy: the message text received in the claim is never printed or echoed.
set -euo pipefail
BASE="${BASE:-http://localhost:3000}"
KEY="${PIPELINE_API_KEY:?Set PIPELINE_API_KEY to the same value as the backend}"

CLAIM=$(curl -s -X POST "$BASE/internal/pipeline/claim" \
  -H "X-Pipeline-Key: $KEY" -H 'Content-Type: application/json' -d '{"max_jobs":1}')
echo "claim: $CLAIM" | cut -c1-200

READ=$(printf '%s' "$CLAIM" | node -e "
const body = JSON.parse(require('fs').readFileSync(0, 'utf8'));
const job = (body.jobs || [])[0];
if (!job) { console.log('NONE'); process.exit(0); }
// Only the ids are used; text and agenda are never printed.
console.log([job.job_id, job.raw_message_id].join('\t'));
")

if [ "$READ" = "NONE" ]; then
  echo "no jobs to claim"
  exit 0
fi
JOB_ID="${READ%%$'\t'*}"
RAW_ID="${READ#*$'\t'}"

RESULT=$(printf '{"job_id":"%s","raw_message_id":"%s","outcome":"ok","rewritten_text":"[fake external rewrite] canned text from the test tool","intent_preservation_score":0.9,"relevance_score":0.8,"relevance_label":"relevant","pipeline_version":"fake-external-1"}' "$JOB_ID" "$RAW_ID")
echo "result: $(curl -s -X POST "$BASE/internal/pipeline/result" \
  -H "X-Pipeline-Key: $KEY" -H 'Content-Type: application/json' -d "$RESULT")"

# To report a failure instead, run:
#   curl -s -X POST "$BASE/internal/pipeline/fail" -H "X-Pipeline-Key: $KEY" \
#     -H 'Content-Type: application/json' \
#     -d '{"job_id":"<JOB_ID>","error_code":"test_failure"}'
