"""Capture real screenshots of the running Talk It Out web app (local only).

Needs Playwright (pip install playwright && python -m playwright install chromium),
the backend on :3000 and the live web build on :52001.

    python cap.py <step> [<step> ...]
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
from pathlib import Path

from playwright.async_api import async_playwright

APP = "http://localhost:52001"
SHOTS = Path(__file__).with_name("shots")
STATE = Path(__file__).with_name("state.json")
VIEW = {"width": 390, "height": 815}
PASSWORD = "showcase123"
ACCOUNTS = {
    "priya": ("priya@example.com", "secret123"),
    "rahul": ("rahul@example.test", PASSWORD),
    "kabir": ("kabir@example.test", PASSWORD),
    "newuser": (os.environ.get("NEW_EMAIL", ""), "firstrun123"),
}


class App:
    def __init__(self, page):
        self.page = page

    async def semantics(self):
        await self.page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
        await self.page.wait_for_timeout(500)

    async def labels(self):
        return await self.page.evaluate(
            "Array.from(document.querySelectorAll('flt-semantics')).map(e => [e.getAttribute('role')||'', "
            "(e.getAttribute('aria-label')||'').replace(/\\n/g,' | ').slice(0,70)]).filter(x => x[1])")

    async def find(self, text, nth=0, role=None, exact=False):
        js = """([text, nth, role, exact]) => {
          const els = Array.from(document.querySelectorAll('flt-semantics, flt-semantics input, flt-semantics textarea'))
            .filter(e => {
              const l = (e.getAttribute('aria-label') || e.getAttribute('placeholder') || '').replace(/\\n/g, ' ');
              if (role && (e.getAttribute('role') || e.tagName.toLowerCase()) !== role) return false;
              return exact ? l.trim() === text : l.includes(text);
            })
            .map(e => e.getBoundingClientRect())
            .filter(r => r.width > 0 && r.height > 0);
          const r = els[nth];
          return r ? [r.x + r.width / 2, r.y + r.height / 2, els.length] : null;
        }"""
        return await self.page.evaluate(js, [text, nth, role, exact])

    async def click(self, text, nth=0, role=None, exact=False, wait=700):
        pos = await self.find(text, nth, role, exact)
        if not pos:
            raise RuntimeError(f"not found: {text!r}\n{json.dumps(await self.labels(), indent=0)[:3000]}")
        await self.page.mouse.click(pos[0], pos[1])
        await self.page.wait_for_timeout(wait)
        return pos

    async def tap(self, x, y, wait=600):
        await self.page.mouse.click(x, y)
        await self.page.wait_for_timeout(wait)

    async def type(self, text, delay=35):
        await self.page.keyboard.type(text, delay=delay)

    async def go(self, route, wait=2200):
        await self.page.evaluate(f"location.hash = '#{route}'")
        await self.page.wait_for_timeout(wait)
        await self.semantics()

    async def snap(self, name, wait=500):
        await self.page.wait_for_timeout(wait)
        SHOTS.mkdir(exist_ok=True)
        await self.page.screenshot(path=str(SHOTS / f"{name}.png"))
        print("shot", name, flush=True)


async def open_app(pw, who=None, start="/login", view=None):
    browser = await pw.chromium.launch(args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    ctx = await browser.new_context(viewport=view or VIEW, device_scale_factor=3)
    page = await ctx.new_page()
    await page.goto(APP + "/#" + start)
    await page.wait_for_timeout(4500)
    app = App(page)
    await app.semantics()
    if who:
        email, password = ACCOUNTS[who]
        # Field positions on the login screen (Runs 118-125 layout, 390x815).
        await app.tap(195, 255, wait=300)
        await app.type(email, 10)
        await page.wait_for_timeout(600)
        await app.tap(180, 344, wait=900)
        await page.keyboard.insert_text(password)  # obscured fields drop typed keys
        await page.wait_for_timeout(500)
        await page.wait_for_timeout(400)
        await app.tap(195, 438, wait=200)  # Sign in
        await page.wait_for_timeout(3500)
        await app.semantics()
        # New accounts may see the welcome tour first.
        if "welcome" in page.url:
            try:
                await app.click("Skip")
            except RuntimeError:
                pass
    return browser, app


def state():
    return json.loads(STATE.read_text())


STEPS = {}


def step(fn):
    STEPS[fn.__name__] = fn
    return fn


@step
async def probe_groups(pw):
    b, app = await open_app(pw, "priya")
    await app.snap("probe_groups")
    print(json.dumps(await app.labels())[:2500])
    await b.close()


@step
async def priya_compose(pw):
    st = state()
    b, app = await open_app(pw, "priya")
    await app.tap(324, 203)  # close the welcome banner for a clean list
    await app.snap("01_groups")
    await app.go(f"/groups/{st['group']}")
    await app.snap("02_chat")
    await app.tap(150, 775)
    await app.type("This plan makes no sense and nobody listens to us.", 40)
    await app.snap("02_typed")
    await app.click("Anonymous message", exact=False)
    await app.snap("02_anon")
    labels = json.dumps(await app.labels())
    if "checked" not in labels.lower() and "true" not in labels.lower():
        print("WARNING: could not confirm the checkbox state from semantics; check 02_anon.png")
    import os
    if os.environ.get("SEND") != "1":
        print("dry run: not sending")
        print(json.dumps(await app.page.evaluate("Array.from(document.querySelectorAll('flt-semantics')).filter(e=>e.getBoundingClientRect().y>700).map(e=>[e.getAttribute('role'),e.getAttribute('aria-label'),Math.round(e.getBoundingClientRect().x),Math.round(e.getBoundingClientRect().y)])")))
        await b.close()
        return
    await app.tap(330, 774, wait=250)  # Send (no accessibility label in the app)
    await app.snap("02_sent", wait=100)
    await app.snap("02_sent_later", wait=1800)
    await b.close()


@step
async def rahul_review(pw):
    st = state()
    g, m = st["group"], st["anon_msg"]
    b, app = await open_app(pw, "rahul")
    await app.go(f"/groups/{g}/review", wait=3000)
    await app.snap("03_queue")
    await app.go(f"/groups/{g}/review/{m}", wait=3000)
    await app.snap("03_review")
    await app.page.mouse.wheel(0, 500)
    await app.snap("03_review_scrolled", wait=900)
    print(json.dumps(await app.labels())[:1500])
    if os.environ.get("PUBLISH") == "1":
        await app.tap(290, 778, wait=150)  # Publish rewrite
        await app.snap("03_publish_tap", wait=50)
        await app.snap("03_published", wait=1500)
    await b.close()


@step
async def priya_after(pw):
    st = state()
    g = st["group"]
    b, app = await open_app(pw, "priya")
    await app.go(f"/groups/{g}", wait=3000)
    await app.snap("04_chat_anon")
    await app.go(f"/groups/{g}/mine", wait=2500)
    await app.snap("04_mine")
    await b.close()


@step
async def priya_tour(pw):
    st = state()
    g = st["group"]
    b, app = await open_app(pw, "priya")
    await app.go(f"/groups/{g}", wait=3500)
    await app.snap("05_chat_bottom")
    for i in range(1, 5):
        await app.page.mouse.move(195, 400)
        await app.page.mouse.wheel(0, -320)
        await app.snap(f"05_chat_up{i}", wait=900)
    await app.page.mouse.wheel(0, 5000)
    await app.page.wait_for_timeout(900)
    await app.tap(150, 775)
    await app.type("Thanks @kab", 60)
    await app.snap("05_mention", wait=1200)
    for _ in range(11):
        await app.page.keyboard.press("Backspace")
    await app.tap(322, 28, wait=2500)  # Catch up
    await app.snap("06_catchup")
    await app.go("/feed", wait=3500)
    await app.snap("08_feed")
    await app.go(f"/feed/{st['question']}", wait=3500)
    await app.snap("08_question")
    await app.page.mouse.move(195, 400)
    await app.page.mouse.wheel(0, 450)
    await app.snap("08_answers", wait=900)
    await app.go("/notifications", wait=3000)
    await app.snap("09_alerts")
    await app.go(f"/people/{st['people']['kabir']['id']}", wait=3000)
    await app.snap("10_profile")
    print(json.dumps(await app.labels())[:1200])
    await b.close()


@step
async def priya_more(pw):
    st = state()
    g = st["group"]
    b, app = await open_app(pw, "priya")
    await app.go(f"/groups/{g}", wait=3500)
    for i in range(1, 9):
        await app.page.mouse.move(195, 400)
        await app.page.mouse.wheel(0, -260)
        await app.page.wait_for_timeout(1500)
        await app.snap(f"05_up{i}", wait=300)
    await app.go(f"/people/{st['people']['kabir']['id']}", wait=3000)
    await app.tap(365, 28, wait=1200)
    await app.snap("10_menu")
    await b.close()


@step
async def rahul_invite(pw):
    st = state()
    g = st["group"]
    b, app = await open_app(pw, "rahul")
    await app.go(f"/groups/{g}/members", wait=3000)
    await app.snap("07_members")
    await app.tap(195, 158, wait=1800)  # Invite members
    await app.snap("07_sheet")
    await app.type("ankitta", 110)
    await app.snap("07_search", wait=1800)
    await b.close()


@step
async def priya_tall(pw):
    st = state()
    b, app = await open_app(pw, "priya", view={"width": 390, "height": 2300})
    await app.go(f"/groups/{st['group']}", wait=4000)
    await app.snap("05_tall", wait=1500)
    await b.close()


@step
async def rahul_invite2(pw):
    st = state()
    b, app = await open_app(pw, "rahul")
    await app.go(f"/groups/{st['group']}/members", wait=3000)
    await app.tap(195, 158, wait=1800)
    await app.type("ankitta", 110)
    await app.page.wait_for_timeout(1500)
    await app.tap(361, 306, wait=700)  # select Ankita
    await app.snap("07_selected")
    await app.page.keyboard.press("Escape")
    await app.page.wait_for_timeout(800)
    await app.go(f"/groups/{st['group']}/members", wait=2500)
    await app.tap(195, 214, wait=2500)  # Invite with a link or QR code
    await app.snap("07_link_options")
    await app.tap(195, 762, wait=3000)  # Create invite link
    await app.snap("07_qr", wait=1000)
    await b.close()


@step
async def signin(pw):
    b, app = await open_app(pw)
    await app.snap("11_login")
    await app.tap(349, 284, wait=2000)  # Forgot?
    await app.semantics()
    await app.snap("11_forgot")
    print(json.dumps(await app.labels())[:600])
    pos = await app.find("example.com")
    if pos:
        await app.tap(pos[0], pos[1], wait=400)
    else:
        await app.tap(195, 240, wait=400)
    await app.type("priya@example.com", 30)
    await app.snap("11_forgot_typed")
    await app.page.keyboard.press("Enter")
    await app.page.wait_for_timeout(2500)
    await app.semantics()
    await app.snap("11_code_empty")
    code_file = SHOTS / "code.txt"
    for _ in range(600):
        if code_file.exists():
            break
        await app.page.wait_for_timeout(500)
    code = code_file.read_text().strip() if code_file.exists() else None
    if code:
        await app.tap(45, 278, wait=500)  # first code box
        await app.type(code, 160)
        await app.snap("11_code", wait=800)
        await app.tap(195, 349, wait=1800)  # Verify code
        await app.semantics()
        await app.snap("11_new_password", wait=500)
    print(json.dumps(await app.labels())[:800])
    await b.close()


@step
async def newuser(pw):
    """The first-time experience as a brand-new user sees it (UX review)."""
    import time
    out = "ux"
    b, app = await open_app(pw, start="/register")
    await app.snap(f"{out}_01_register")
    print(json.dumps(await app.labels())[:900])
    stamp = int(time.time()) % 100000
    for label, text in (("name", "Neha Gupta"), ("example.com", f"neha{stamp}@example.test"),
                        ("password", "firstrun123")):
        pos = await app.find(label)
        if pos:
            await app.tap(pos[0], pos[1], wait=300)
            await app.type(text, 15)
    await app.snap(f"{out}_02_register_filled")
    await app.page.keyboard.press("Enter")
    await app.page.wait_for_timeout(4000)
    await app.semantics()
    for i in range(3, 12):
        await app.snap(f"{out}_{i:02d}_step")
        labels = await app.labels()
        print(i, app.page.url, json.dumps(labels)[:500])
        clicked = False
        for nxt in ("Next", "Continue", "Get started", "Skip", "Done", "Start"):
            pos = await app.find(nxt)
            if pos:
                await app.tap(pos[0], pos[1], wait=2200)
                await app.semantics()
                clicked = True
                break
        if not clicked:
            break
    await b.close()


@step
async def firstrun(pw):
    """A brand-new account signing in for the first time (UX review)."""
    b, app = await open_app(pw, "newuser")
    for i in range(1, 14):
        await app.snap(f"ux_fr{i:02d}", wait=800)
        print(i, app.page.url.split("#")[-1], json.dumps(await app.labels())[:300], flush=True)
        clicked = False
        for nxt in ("Next", "Continue", "Get started", "Let's go", "Start", "Done", "Skip"):
            pos = await app.find(nxt)
            if pos:
                await app.tap(pos[0], pos[1], wait=2000)
                await app.semantics()
                clicked = True
                break
        if not clicked:
            break
    for route in ("/groups", "/feed", "/notifications", "/profile"):
        await app.go(route, wait=2800)
        await app.snap("ux_empty" + route.replace("/", "_"))
    await b.close()


@step
async def ux_after(pw):
    """The redesigned first-time screens (Stitch-based)."""
    b, app = await open_app(pw, start="/register")
    await app.snap("uxnew_01_register_empty")
    await app.tap(195, 289, wait=500)  # email field
    await app.page.keyboard.insert_text("neha@example.test")
    await app.snap("uxnew_02_register_email", wait=600)
    await b.close()
    b, app = await open_app(pw, "newuser")
    await app.go("/welcome", wait=2500)
    await app.snap("uxnew_03_welcome")
    await app.page.mouse.move(195, 500)
    await app.page.mouse.wheel(0, 900)
    await app.snap("uxnew_04_welcome_bottom", wait=900)
    await app.go("/groups", wait=2800)
    await app.snap("uxnew_05_groups_empty")
    await app.go("/feed", wait=3000)
    await app.snap("uxnew_06_interests")
    await b.close()


@step
async def probe_dupes(pw):
    st = state()
    b, app = await open_app(pw, "priya")
    await app.go(f"/groups/{st['group']}", wait=3500)
    js = """() => Array.from(document.querySelectorAll('flt-semantics')).map(e => (e.getAttribute('aria-label')||''))
      .filter(l => /\\. /.test(l) && (l.includes('Which day') || l.includes('Agreed') || l.includes('Whiteboard')))
      .map(l => l.slice(0, 50))"""
    for i in range(8):
        print(i, await app.page.evaluate(js))
        await app.page.mouse.move(195, 400)
        await app.page.mouse.wheel(0, -260)
        await app.page.wait_for_timeout(1500)
        await app.semantics()
    await b.close()


async def main():
    async with async_playwright() as pw:
        for name in sys.argv[1:]:
            await STEPS[name](pw)


if __name__ == "__main__":
    asyncio.run(main())
