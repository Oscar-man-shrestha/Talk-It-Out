"""Seed the showcase story into a LOCAL Talk It Out backend, through its API.

Used to capture real screenshots for the feature tour. Everything goes
through the normal app paths: messages are rewritten by the real worker and
accepted by the controller. Local test accounts only (@example.test).

    python3 seed.py part1   # people, groups, first messages, feed
    python3 seed.py part2   # after Priya's anonymous message is published
"""

from __future__ import annotations

import io
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

BASE = "http://localhost:3000"
STATE = Path(__file__).with_name("state.json")
PASSWORD = "showcase123"  # local test accounts only

PEOPLE = {
    "rahul": ("Rahul Verma", "rahul@example.test", "rahul.v", "Engineering Lead"),
    "anita": ("Anita Sharma", "anita@example.test", "anita", "QA Engineer"),
    "meera": ("Meera Kapoor", "meera@example.test", "meera", "Product Designer"),
    "kabir": ("Kabir Mehta", "kabir@example.test", "kabir", "Backend Engineer"),
    "arjun": ("Arjun Nair", "arjun@example.test", "arjun", "Engineering Manager"),
    "ankita": ("Ankita Rao", "ankita@example.test", "ankita", "Data Analyst"),
    "rohan": ("Rohan Das", "rohan@example.test", "rohan.d", "Design Lead"),
}


def req(method, path, token=None, body=None, raw=None, ctype=None, ok=(200, 201, 202, 204)):
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if raw is not None:
        data, headers["Content-Type"] = raw, ctype
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r, timeout=60) as res:
            txt = res.read().decode() or "{}"
            return res.status, json.loads(txt)
    except urllib.error.HTTPError as e:
        txt = e.read().decode()
        if e.code in ok:
            return e.code, json.loads(txt or "{}")
        raise RuntimeError(f"{method} {path} -> {e.code} {txt}") from None


def login(email, password):
    return req("POST", "/auth/login", body={"email": email, "password": password})[1]


def account(key):
    name, email, handle, headline = PEOPLE[key]
    try:
        res = login(email, PASSWORD)
    except RuntimeError:
        res = req("POST", "/auth/register", body={"name": name, "email": email, "password": PASSWORD})[1]
    tok = res["token"]
    req("PUT", "/users/me/handle", tok, {"handle": handle}, ok=(200, 409))
    req("PUT", "/users/me/profile", tok, {"headline": headline})
    req("PUT", "/users/me/interests", tok, {"interests": ["leadership", "engineering", "communication"]})
    return {"token": tok, "id": res["user"]["id"], "name": name}


def priya():
    res = login("priya@example.com", "secret123")
    tok = res["token"]
    req("PUT", "/users/me/profile", tok, {"name": "Priya Sharma", "headline": "Product Manager"})
    req("PUT", "/users/me/handle", tok, {"handle": "priya"}, ok=(200, 409))
    req("PUT", "/users/me/interests", tok, {"interests": ["leadership", "remote_work", "engineering",
                                                         "communication", "career_growth"]})
    return {"token": tok, "id": res["user"]["id"], "name": "Priya Sharma"}


def join(group_id, controller, member):
    _, inv = req("POST", f"/groups/{group_id}/members", controller["token"], {"user_id": member["id"]},
                 ok=(202, 409))
    if inv.get("invitation_id"):
        req("POST", f"/invitations/{inv['invitation_id']}/accept", member["token"])


def announce(group_id, controller, text, **extra):
    return req("POST", f"/groups/{group_id}/messages/controller", controller["token"], {"text": text, **extra})[1]


def published(group_id, token):
    return req("GET", f"/groups/{group_id}/messages", token)[1]["items"]


def through_review(group_id, controller, author, text, anonymous=False, **extra):
    """Send as `author`, wait for the real rewrite, accept as `controller`."""
    _, m = req("POST", f"/groups/{group_id}/messages", author["token"],
               {"text": text, "is_anonymous": anonymous, **extra})
    mid = m["id"]
    for attempt in range(120):
        _, d = req("GET", f"/groups/{group_id}/review-queue/{mid}", controller["token"])
        if d.get("pipeline_status") == "done" and d.get("rewritten_text"):
            break
        if d.get("pipeline_status") == "failed":
            req("POST", f"/messages/{mid}/rewrite", controller["token"])
        time.sleep(1)
    else:
        raise RuntimeError("rewrite did not arrive")
    req("POST", f"/messages/{mid}/accept", controller["token"])
    time.sleep(0.3)
    items = published(group_id, controller["token"])
    return items[-1]


def whiteboard_jpeg() -> bytes:
    from PIL import Image, ImageDraw, ImageFilter
    w, h = 1200, 900
    img = Image.new("RGB", (w, h), (214, 210, 200))
    d = ImageDraw.Draw(img)
    d.rectangle((60, 60, w - 60, h - 120), fill=(246, 246, 243), outline=(150, 150, 150), width=8)
    colors = [(255, 228, 120), (160, 220, 255), (255, 180, 190), (190, 240, 180)]
    for i in range(8):
        x = 120 + (i % 4) * 250
        y = 140 + (i // 4) * 300
        d.rectangle((x, y, x + 190, y + 190), fill=colors[i % 4])
        for j in range(4):
            d.line((x + 20, y + 40 + j * 36, x + 150 - (j * 17) % 50, y + 40 + j * 36), fill=(70, 70, 80), width=6)
    d.line((120, 470, 1080, 470), fill=(60, 60, 200), width=5)
    d.rectangle((60, h - 120, w - 60, h - 90), fill=(170, 170, 170))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=88)
    return buf.getvalue()


def upload_image(group_id, author, data: bytes):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"whiteboard.jpg\"\r\n"
            f"Content-Type: image/jpeg\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    return req("POST", f"/groups/{group_id}/attachments", author["token"], raw=body,
               ctype=f"multipart/form-data; boundary={boundary}")[1]["id"]


def part1():
    st = {"people": {k: account(k) for k in PEOPLE}}
    st["people"]["priya"] = priya()
    P = st["people"]
    rahul = P["rahul"]
    # The team group.
    _, g = req("POST", "/groups", rahul["token"], {"agenda": "Q3 launch plan"})
    gid = g["id"]
    st["group"] = gid
    req("PATCH", f"/groups/{gid}", rahul["token"], {
        "description": "Planning the Q3 product launch: scope, QA and the release checklist.",
        "rules": "Be specific. Critique plans, not people."})
    for k in ("priya", "anita", "meera", "kabir", "arjun"):
        join(gid, rahul, P[k])
    announce(gid, rahul, "The Q3 launch plan is in the shared doc. Thoughts by Friday?")
    pin_msg = announce(gid, rahul, "Launch checklist is due this Friday.")
    pid = pin_msg.get("id") or published(gid, rahul["token"])[-1]["id"]
    req("POST", f"/groups/{gid}/messages/{pid}/pin", rahul["token"])
    through_review(gid, rahul, P["anita"], "Can we add QA time to week 2? Testing feels rushed.")
    req("PUT", f"/groups/{gid}/settings", P["priya"]["token"], {"pinned": True})

    # An invitation for Priya to answer on camera.
    _, g2 = req("POST", "/groups", P["rohan"]["token"], {"agenda": "Design critique"})
    for k in ("meera", "anita", "kabir"):
        join(g2["id"], P["rohan"], P[k])
    req("POST", f"/groups/{g2['id']}/members", P["rohan"]["token"], {"user_id": P["priya"]["id"]}, ok=(202, 409))

    # Feed: a question with answers, votes and a best answer.
    _, q = req("POST", "/posts", P["meera"]["token"], {
        "title": "How do you give feedback to a senior without sounding rude?",
        "content": "My lead often changes scope late. I want to raise it without it sounding like a complaint.",
        "topic": "leadership"})
    st["question"] = q["id"]
    req("POST", f"/posts/{q['id']}/follow", P["priya"]["token"])
    _, a1 = req("POST", f"/posts/{q['id']}/comments", P["arjun"]["token"], {
        "content": "Lead with the shared goal, describe one specific moment, then ask what they think. "
                   "Keep it about the work, not the person."})
    _, a2 = req("POST", f"/posts/{q['id']}/comments", P["anita"]["token"], {
        "content": "Ask for a short 1:1 and bring one example. Private beats public every time."})
    for k in ("priya", "kabir", "rahul", "anita", "ankita", "rohan"):
        req("POST", f"/posts/{q['id']}/comments/{a1['id']}/vote", P[k]["token"], ok=(200, 422))
    for k in ("kabir", "rohan"):
        req("POST", f"/posts/{q['id']}/comments/{a2['id']}/vote", P[k]["token"], ok=(200, 422))
    req("PUT", f"/posts/{q['id']}/best", P["meera"]["token"], {"comment_id": a1["id"]})
    for k in ("priya", "kabir", "rahul", "anita", "arjun", "ankita", "rohan"):
        req("POST", f"/posts/{q['id']}/reactions", P[k]["token"], {"type": "like"}, ok=(200, 201, 409))
    # Kabir's question; Priya's answer becomes the best one (a notification for her).
    _, q2 = req("POST", "/posts", P["kabir"]["token"], {
        "title": "What makes a stand-up actually useful?",
        "content": "Ours run 30 minutes and nobody listens. What works for your team?", "topic": "culture"})
    _, pa = req("POST", f"/posts/{q2['id']}/comments", P["priya"]["token"], {
        "content": "Keep it to blockers only, 10 minutes, and move details to threads."})
    req("PUT", f"/posts/{q2['id']}/best", P["kabir"]["token"], {"comment_id": pa["id"]})
    # A new answer on the question Priya follows (another notification).
    req("POST", f"/posts/{q['id']}/comments", P["kabir"]["token"], {
        "content": "Write it down first. If it still sounds fair a day later, say it."})
    STATE.write_text(json.dumps(st, indent=1))
    print("part1 done; group", gid)


def part2():
    st = json.loads(STATE.read_text())
    P = st["people"]
    for k in P:  # fresh tokens
        email = "priya@example.com" if k == "priya" else PEOPLE[k][1]
        P[k]["token"] = login(email, "secret123" if k == "priya" else PASSWORD)["token"]
    gid, rahul = st["group"], P["rahul"]
    items = published(gid, rahul["token"])
    anon = next(m for m in reversed(items) if m.get("display_sender") is None)
    for k, e in (("anita", "❤️"), ("meera", "❤️"), ("arjun", "❤️"), ("kabir", "👍"), ("rahul", "👍"), ("meera", "💡")):
        req("POST", f"/groups/{gid}/messages/{anon['id']}/reactions", P[k]["token"], {"emoji": e})
    announce(gid, rahul, "Fair point. Let's fix priorities together tomorrow at 10.")
    through_review(gid, rahul, P["anita"], "Agreed. Let's list the priorities first.", reply_to_id=anon["id"])
    _, poll = req("POST", f"/groups/{gid}/polls", rahul["token"], {
        "question": "Which day works for the launch review?", "options": ["Tuesday", "Wednesday", "Thursday"]})
    poll_msg = published(gid, rahul["token"])[-1]
    poll_id = (poll_msg.get("poll") or {}).get("id") or poll.get("poll", {}).get("id")
    for k, opt in (("anita", 0), ("meera", 0), ("arjun", 0), ("kabir", 1), ("priya", 0)):
        req("POST", f"/groups/{gid}/polls/{poll_id}/vote", P[k]["token"], {"option_index": opt})
    att = upload_image(gid, P["meera"], whiteboard_jpeg())
    through_review(gid, rahul, P["meera"], "Whiteboard from today's planning session.", attachment_id=att)
    through_review(gid, rahul, P["kabir"], "@priya could you share the checklist draft?")
    print("part2 done")


if __name__ == "__main__":
    {"part1": part1, "part2": part2}[sys.argv[1]]()
