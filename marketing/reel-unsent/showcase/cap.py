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
        await app.click("alex@example.com")
        await app.type(email, 10)
        await app.click("Enter your security passkey")
        await app.type(password, 10)
        await page.keyboard.press("Enter")
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
