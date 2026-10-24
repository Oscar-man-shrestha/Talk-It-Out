#!/usr/bin/env bash
# End-to-end demo of the full moderation flow against a running API
# (start it with: RUN_STUB_WORKER=true npm run dev).
# Uses curl + node for JSON parsing (no jq needed).
set -euo pipefail
BASE="${BASE:-http://localhost:3000}"

json_field() { node -pe "JSON.parse(process.argv[1])$1" "$2"; }

echo "== 1. Register controller and contributor =="
CTRL=$(curl -s -X POST "$BASE/auth/register" -H 'Content-Type: application/json' \
  -d '{"name":"Demo Controller","email":"demo-controller@example.com","password":"secret123"}')
CTRL_TOKEN=$(json_field .token "$CTRL")
CONTRIB=$(curl -s -X POST "$BASE/auth/register" -H 'Content-Type: application/json' \
  -d '{"name":"Demo Contributor","email":"demo-contributor@example.com","password":"secret123"}')
CONTRIB_TOKEN=$(json_field .token "$CONTRIB")
echo "controller and contributor registered (duplicate email would return 409 here)"

echo "== 2. Controller creates a group =="
GROUP=$(curl -s -X POST "$BASE/groups" -H "Authorization: Bearer $CTRL_TOKEN" \
  -H 'Content-Type: application/json' -d '{"agenda":"Making NLP notes"}')
GROUP_ID=$(json_field .id "$GROUP")
echo "group: $GROUP_ID"

echo "== 3. Controller adds the contributor by username =="
curl -s -X POST "$BASE/groups/$GROUP_ID/members" -H "Authorization: Bearer $CTRL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo-contributor","role":"contributor"}'
echo

echo "== 4. Contributor submits an ANONYMOUS message =="
SENT=$(curl -s -X POST "$BASE/groups/$GROUP_ID/messages" -H "Authorization: Bearer $CONTRIB_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"the intro slide should mention the evaluation dataset","is_anonymous":true}')
MSG_ID=$(json_field .id "$SENT")
echo "sent: $SENT"

echo "== 5. Wait for the stub worker (runs every ~1.5s in-process) =="
sleep 3
echo "review queue:"
curl -s "$BASE/groups/$GROUP_ID/review-queue" -H "Authorization: Bearer $CTRL_TOKEN"
echo

echo "== 6. Controller accepts the rewrite =="
ACCEPT=$(curl -s -X POST "$BASE/messages/$MSG_ID/accept" -H "Authorization: Bearer $CTRL_TOKEN")
echo "accept: $ACCEPT"

echo "== 7. Group chat (anonymous -> display_sender null) =="
curl -s "$BASE/groups/$GROUP_ID/messages" -H "Authorization: Bearer $CONTRIB_TOKEN"
echo

echo "== 8. Contributor checks their own message status =="
curl -s "$BASE/groups/$GROUP_ID/messages/mine" -H "Authorization: Bearer $CONTRIB_TOKEN"
echo

echo "== 9. Controller notifications =="
NOTIFS=$(curl -s "$BASE/notifications" -H "Authorization: Bearer $CTRL_TOKEN")
echo "list: $NOTIFS"
echo "unread: $(curl -s "$BASE/notifications/unread-count" -H "Authorization: Bearer $CTRL_TOKEN")"
NOTIF_ID=$(json_field ".items[0].id" "$NOTIFS")
curl -s -o /dev/null -w "mark read -> HTTP %{http_code}\n" \
  -X POST "$BASE/notifications/$NOTIF_ID/read" -H "Authorization: Bearer $CTRL_TOKEN"
echo "unread after: $(curl -s "$BASE/notifications/unread-count" -H "Authorization: Bearer $CTRL_TOKEN")"

echo "== 10. A second message is rejected and never reaches the chat =="
SENT2=$(curl -s -X POST "$BASE/groups/$GROUP_ID/messages" -H "Authorization: Bearer $CONTRIB_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"totally off topic","is_anonymous":false}')
MSG2=$(json_field .id "$SENT2")
sleep 3
curl -s -X POST "$BASE/messages/$MSG2/reject" -H "Authorization: Bearer $CTRL_TOKEN"
echo
echo "chat still has exactly one message:"
curl -s "$BASE/groups/$GROUP_ID/messages" -H "Authorization: Bearer $CONTRIB_TOKEN"
echo

echo "== 11. Controller posts a direct announcement (no review) =="
curl -s -X POST "$BASE/groups/$GROUP_ID/messages/controller" -H "Authorization: Bearer $CTRL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Review meeting at 5pm."}'
echo

echo "== 12. Feed: post, comment, like (fake analysis runs in-process) =="
POST=$(curl -s -X POST "$BASE/posts" -H "Authorization: Bearer $CONTRIB_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"content":"How should we label borderline relevance? nsfw-test"}')
POST_ID=$(json_field .id "$POST")
echo "created post: $POST_ID"
sleep 2   # let the feed worker finish the analysis
echo "post after analysis (nsfw_flag from the fake provider):"
curl -s "$BASE/posts/$POST_ID" -H "Authorization: Bearer $CONTRIB_TOKEN"
echo
curl -s -X POST "$BASE/posts/$POST_ID/comments" -H "Authorization: Bearer $CTRL_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"content":"Start with the definition from the notes."}'
echo
curl -s -X POST "$BASE/posts/$POST_ID/reactions" -H "Authorization: Bearer $CTRL_TOKEN" \
  -H 'Content-Type: application/json' -d '{"type":"like"}'
echo

echo "== 13. Convert the post into a group (author only) =="
curl -s -X POST "$BASE/posts/$POST_ID/group" -H "Authorization: Bearer $CONTRIB_TOKEN"
echo
echo "done."
