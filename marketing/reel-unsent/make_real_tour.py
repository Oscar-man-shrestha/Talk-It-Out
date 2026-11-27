"""Talk It Out — feature tour built from REAL app screenshots (English, 88 s).

The screenshots in showcase/shots/ were captured from the running app
(showcase/cap.py) after seeding a showcase story through the API
(showcase/seed.py). Nothing on the phone screen is drawn by hand.

    python3 make_real_tour.py               # -> talk-it-out-feature-tour-real.mp4
    python3 make_real_tour.py --stills 20 40
"""

from __future__ import annotations

import math
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import make_reel as R
import make_tour as T
from make_reel import (
    ACCENT_SOFT, CANVAS, INK, INK_FAINT, INK_SOFT, WHITE, K, PH_H, SCR_H, SCR_W, S, SS, W, H, FPS,
    circle_layer, clamp, comp, comp_centered, draw_text, ease_back, ease_in_out, ease_out, font,
    icon_logo, icon_send, lerp, prog, rrect_layer, scaled, text_layer, wrap,
)

HERE = Path(__file__).resolve().parent
SHOTS = HERE / "showcase" / "shots"
OUT = HERE / "talk-it-out-feature-tour-real.mp4"
DUR = 88.0
NFRAMES = int(DUR * FPS)
CSS_W, CSS_H = 390, 815  # capture viewport

# Areas to blur (CSS px): the local invite link address.
BLURS = {"07_qr": [(420 - 400, 527, 370, 44), (16, 742, 250, 46)]}


@lru_cache(maxsize=None)
def shot(name):
    im = Image.open(SHOTS / f"{name}.png").convert("RGB")
    for (x, y, w, h) in BLURS.get(name, []):
        box = tuple(int(v * 3) for v in (x, y, x + w, y + h))
        im.paste(im.crop(box).filter(ImageFilter.GaussianBlur(14)), box)
    return im.resize((S(SCR_W), S(SCR_H)), Image.LANCZOS).convert("RGBA")


@lru_cache(maxsize=1)
def tall():
    im = Image.open(SHOTS / "05_tall.png").convert("RGB")
    k = S(SCR_W) / im.width
    return im.resize((S(SCR_W), int(im.height * k)), Image.LANCZOS).convert("RGBA"), k * 3  # px per CSS px


def css(v):
    """CSS px of the capture -> screen pixels (at SS)."""
    return v * S(SCR_W) / CSS_W


def ripple(img, x, y, lt, at):
    if not (at <= lt <= at + 0.6):
        return
    r = ease_out(prog(lt, at, at + 0.6))
    d = 26 + 70 * r
    lay = circle_layer(d / K, (9, 9, 11, int(70 * (1 - r))))
    comp(img, lay, css(x) - lay.size[0] / 2, css(y) - lay.size[1] / 2)
    dot = circle_layer(22 / K, (9, 9, 11, int(110 * (1 - r))))
    comp(img, dot, css(x) - dot.size[0] / 2, css(y) - dot.size[1] / 2)


def sequence(frames, taps=()):
    """frames: [(lt_start, shot_name)], crossfading 0.22 s; taps: [(lt, x, y)]."""
    def screen(lt):
        cur = 0
        for i, (t0, _) in enumerate(frames):
            if lt >= t0:
                cur = i
        img = shot(frames[cur][1]).copy()
        if cur > 0:
            x = prog(lt, frames[cur][0], frames[cur][0] + 0.22)
            if x < 1:
                img = Image.blend(shot(frames[cur - 1][1]), img, ease_in_out(x))
        for at, tx, ty in taps:
            ripple(img, tx, ty, lt, at)
        return img
    return screen


def chat_scroll(lt):
    """The real chat, captured in one tall screenshot, scrolled like the app."""
    im, k = tall()
    top_h, bottom_h = 240, 262          # header and composer (CSS px), kept fixed
    full_h = im.height / k              # tall height in CSS px
    mid_h = CSS_H - top_h - bottom_h
    start, end = 700, full_h - bottom_h - mid_h
    y = lerp(start, end, ease_in_out(prog(lt, 0.6, 6.4)))
    img = Image.new("RGBA", (S(SCR_W), S(SCR_H)), CANVAS + (255,))
    img.alpha_composite(im.crop((0, 0, im.width, int(top_h * k))), (0, 0))
    img.alpha_composite(im.crop((0, int(y * k), im.width, int((y + mid_h) * k))), (0, int(css(top_h))))
    img.alpha_composite(im.crop((0, int((full_h - bottom_h) * k), im.width, im.height)), (0, int(css(top_h + mid_h))))
    return img


def chat_features(lt):
    if lt < 6.8:
        return chat_scroll(lt)
    img = shot("05_mention").copy()
    x = prog(lt, 6.8, 7.02)
    if x < 1:
        img = Image.blend(chat_scroll(6.79), img, ease_in_out(x))
    return img


# (start, end, chapter, title, subtitle, screen, camera [(lt, zoom, focus_css_y)], sounds [(lt, kind)])
SCENES = [
    (10.0, 15.5, "01  GROUPS", "Your team, in one place.",
     "Pinned groups, unread counts, and invitations you choose to accept.",
     sequence([(0, "01_groups")]),
     [(0, 1.0, 404), (0.8, 1.32, 300), (3.2, 1.32, 300), (3.8, 1.32, 520), (5.2, 1.32, 520), (5.5, 1.0, 404)],
     [(0.8, "whoosh")]),
    (15.5, 23.0, "02  ANONYMOUS MESSAGES", "Say it anonymously.",
     "Hidden from the group. Visible only to the group's controller.",
     sequence([(0, "02_chat"), (1.1, "02_typed"), (3.0, "02_anon"), (4.9, "02_sent_later")],
              taps=[(0.9, 150, 775), (2.8, 40, 633), (4.6, 330, 774)]),
     [(0, 1.0, 404), (0.6, 1.38, 655), (4.8, 1.38, 655), (5.3, 1.3, 430), (7.2, 1.3, 430), (7.5, 1.0, 404)],
     [(0.9, "tap"), (2.8, "tick"), (4.6, "tap")]),
    (23.0, 32.0, "03  AI REWRITE + REVIEW", "AI fixes the tone.",
     "Never the meaning. The group's controller approves every message.",
     sequence([(0, "03_queue"), (2.4, "03_review"), (6.6, "03_publish_tap"), (7.6, "03_published")],
              taps=[(6.4, 290, 778)]),
     [(0, 1.0, 404), (0.5, 1.3, 400), (2.2, 1.3, 400), (2.6, 1.0, 404), (3.1, 1.38, 590), (6.0, 1.38, 590),
      (6.4, 1.3, 700), (7.4, 1.3, 700), (7.7, 1.0, 404)],
     [(2.4, "pop"), (6.4, "tap"), (7.6, "tick")]),
    (32.0, 37.5, "04  SHARED WHEN READY", "Only the kind version is shared.",
     "In the group it reads \"Anonymous user\". You see your status privately.",
     sequence([(0, "04_chat_anon"), (3.0, "04_mine")]),
     [(0, 1.0, 404), (0.4, 1.35, 470), (2.7, 1.35, 470), (3.0, 1.0, 404), (3.3, 1.3, 200), (5.2, 1.3, 200),
      (5.5, 1.0, 404)],
     [(0.3, "pop"), (3.0, "pop")]),
    (37.5, 46.5, "05  GROUP CHAT", "A real group chat.",
     "Reactions, replies, polls, pins, photos and @mentions.",
     chat_features,
     [(0, 1.0, 404), (0.5, 1.22, 404), (6.6, 1.22, 404), (7.1, 1.35, 660), (8.7, 1.35, 660), (9.0, 1.0, 404)],
     [(1.0, "pop"), (2.6, "pop"), (4.0, "pop"), (5.4, "pop"), (7.0, "tick")]),
    (46.5, 51.5, "06  CATCH UP", "Missed the discussion?",
     "The points the group keeps coming back to, picked automatically.",
     sequence([(0, "06_catchup")]),
     [(0, 1.0, 404), (0.5, 1.3, 560), (4.6, 1.3, 560), (5.0, 1.0, 404)],
     [(0.3, "whoosh")]),
    (51.5, 59.0, "07  INVITE YOUR TEAM", "Bring the right people in.",
     "Find teammates by name or @handle, typos and all. Or share a link.",
     sequence([(0, "07_members"), (1.3, "07_selected"), (4.2, "07_link_options"), (5.6, "07_qr")],
              taps=[(1.1, 195, 158), (3.9, 195, 214), (5.4, 195, 762)]),
     [(0, 1.0, 404), (0.3, 1.25, 200), (1.1, 1.25, 200), (1.6, 1.35, 260), (3.9, 1.35, 260), (4.3, 1.0, 404),
      (4.6, 1.25, 600), (7.2, 1.25, 600), (7.5, 1.0, 404)],
     [(1.1, "tap"), (2.0, "tick"), (3.9, "tap"), (5.4, "tap")]),
    (59.0, 66.5, "08  COMMUNITY FEED", "Ask the wider community.",
     "Questions, upvoted answers, best answers and a For You feed.",
     sequence([(0, "08_feed"), (2.6, "08_question"), (5.0, "08_answers")]),
     [(0, 1.0, 404), (0.4, 1.25, 330), (2.3, 1.25, 330), (2.6, 1.0, 404), (2.9, 1.3, 300), (4.7, 1.3, 300),
      (5.1, 1.35, 400), (7.2, 1.35, 400), (7.5, 1.0, 404)],
     [(2.6, "pop"), (5.0, "pop")]),
    (66.5, 71.0, "09  NOTIFICATIONS", "Never miss what matters.",
     "Mentions, new answers, best answers, invitations and reviews.",
     sequence([(0, "09_alerts")]),
     [(0, 1.0, 404), (0.4, 1.3, 400), (4.2, 1.3, 400), (4.5, 1.0, 404)],
     [(0.3, "pop")]),
    (71.0, 75.5, "10  SAFETY", "Safe by design.",
     "Block anyone. Report questions. Contributors never see each other's original words.",
     sequence([(0, "10_profile"), (1.7, "10_menu")], taps=[(1.5, 365, 28)]),
     [(0, 1.0, 404), (0.4, 1.3, 220), (4.2, 1.3, 220), (4.5, 1.0, 404)],
     [(1.5, "tap")]),
    (75.5, 81.5, "11  EASY SIGN-IN", "Start in seconds.",
     "Google or email. Forgot your password? Reset it with an emailed code.",
     sequence([(0, "11_login"), (2.3, "11_forgot_typed"), (4.1, "11_code_empty")], taps=[(2.1, 349, 284)]),
     [(0, 1.0, 404), (0.4, 1.28, 450), (2.0, 1.28, 450), (2.3, 1.0, 404), (2.6, 1.3, 260), (5.7, 1.3, 260),
      (6.0, 1.0, 404)],
     [(2.1, "tap"), (4.1, "pop")]),
]
PHONE_IN, PHONE_OUT = 10.0, 81.5
OUTRO = 81.7


_MASK = None


def phone_layer(screen):
    """Phone frame without a camera notch: the captures have no status bar,
    so a notch would cover the app's own header."""
    global _MASK
    from make_reel import PH_W
    body = rrect_layer(PH_W, PH_H, 72, INK + (255,))
    if _MASK is None:
        _MASK = Image.new("L", (S(SCR_W), S(SCR_H)), 0)
        ImageDraw.Draw(_MASK).rounded_rectangle((0, 0, S(SCR_W) - 1, S(SCR_H) - 1), radius=S(44), fill=255)
    scr = screen.copy()
    scr.putalpha(Image.composite(scr.getchannel("A"), Image.new("L", scr.size, 0), _MASK))
    body.alpha_composite(scr, (S((PH_W - SCR_W) / 2), S((PH_H - SCR_H) / 2)))
    return body


def scene_at(t):
    for sc in SCENES:
        if sc[0] <= t < sc[1]:
            return sc
    return None


def render(t: float, k: int) -> Image.Image:
    if R.DARK_BG is None:
        R.DARK_BG, R.LIGHT_BG = R.make_dark_bg(), R.make_light_bg()
    if t < 10.3:
        frame = T.render(t, k) if t < 6.6 else None
        if frame is not None:
            return frame
    frame = R.LIGHT_BG.copy()
    if t < 10.3:
        out = 1 - ease_in_out(prog(t, 9.6, 10.1))
        li = ease_back(prog(t, 6.7, 7.2))
        comp_centered(frame, icon_logo(170), W / 2, 760, alpha=clamp(li * 1.2) * out, k=max(0.01, 0.6 + 0.4 * li))
        a1 = ease_out(prog(t, 7.0, 7.5))
        draw_text(frame, "Meet Talk It Out", "ExtraBold", 92, (W / 2, 890), INK, alpha=a1 * out, anchor="mt",
                  dy=(1 - a1) * 24)
        a2 = ease_out(prog(t, 7.5, 8.0))
        for i, ln in enumerate(["Say what you really think at work.", "Kindly. Safely. Together."]):
            draw_text(frame, ln, "Regular", 44, (W / 2, 1020 + i * 58), INK_SOFT, alpha=a2 * out, anchor="mt",
                      dy=(1 - a2) * 18)
    if PHONE_IN <= t < PHONE_OUT + 0.4:
        sc = scene_at(min(t, PHONE_OUT - 0.001))
        lt = t - sc[0]
        scr = sc[5](lt)
        idx = SCENES.index(sc)
        if idx > 0 and lt < 0.35:
            prev = SCENES[idx - 1]
            pscr = prev[5](prev[1] - prev[0] - 0.01)
            x = ease_in_out(prog(lt, 0, 0.35))
            mix = Image.new("RGBA", scr.size, CANVAS + (255,))
            mix.alpha_composite(pscr, (int(-x * scr.size[0] * 0.35), 0))
            mix.alpha_composite(R.with_alpha(scr, x), (int((1 - x) * scr.size[0] * 0.25), 0))
            scr = mix
        phone = phone_layer(scr)
        enter = ease_out(prog(t, PHONE_IN, PHONE_IN + 0.7))
        leave = ease_in_out(prog(t, PHONE_OUT - 0.1, PHONE_OUT + 0.35))
        zoom, focus = T.camera_local(sc[6], lt)
        off = focus * K + (PH_H - SCR_H) / 2 - PH_H / 2
        w_ = clamp((zoom - 1) / 0.25)
        base_cy = 500 + PH_H / 2
        cy = lerp(base_cy, T.FOCUS_Y - off * zoom, w_) + (1 - enter) * 600 + leave * 700
        sh = scaled(R.phone_shadow(), zoom)
        vis = enter * (1 - leave)
        comp(frame, sh, S(W / 2) - sh.size[0] / 2, S(cy) - sh.size[1] / 2, vis)
        comp_centered(frame, phone, W / 2, cy, alpha=vis, k=zoom)
        comp(frame, T.band(), 0, 0, vis)
        T.scene_caption(frame, sc, t)
        for j in range(len(SCENES)):
            on = j == idx
            dot = rrect_layer(30 if on else 10, 10, 5, (INK if on else (214, 208, 198)) + (255,))
            x = W / 2 - (len(SCENES) * 18 + 20) / 2 + j * 18 + (20 if j > idx else 0)
            comp(frame, dot, S(x), S(196), vis)
    if t >= OUTRO:
        o = t - OUTRO
        li = ease_back(prog(o, 0.1, 0.6))
        comp_centered(frame, icon_logo(190), W / 2, 700, alpha=clamp(li * 1.2), k=max(0.01, 0.6 + 0.4 * li))
        a1 = ease_out(prog(o, 0.4, 0.9))
        draw_text(frame, "Talk It Out", "ExtraBold", 108, (W / 2, 840), INK, alpha=a1, anchor="mt", dy=(1 - a1) * 24)
        a2 = ease_out(prog(o, 0.8, 1.3))
        draw_text(frame, "Speak up. Stay kind.", "Regular", 54, (W / 2, 985), INK_SOFT, alpha=a2, anchor="mt",
                  dy=(1 - a2) * 20)
        a3 = ease_back(prog(o, 1.5, 1.9))
        if a3 > 0:
            pill = rrect_layer(420, 96, 48, INK + (255,))
            draw_text(pill, "Try it — link in bio", "SemiBold", 36, (210, 48), WHITE, anchor="mm")
            comp_centered(frame, pill, W / 2, 1150, alpha=clamp(a3), k=max(0.01, 0.8 + 0.2 * a3))
        a4 = ease_out(prog(o, 2.1, 2.6))
        for i, ln in enumerate(wrap("Anonymous messages · AI tone rewrite · Controller review · Community feed",
                                    "Medium", 28, 860)):
            draw_text(frame, ln, "Medium", 28, (W / 2, 1270 + i * 40), INK, alpha=a4, anchor="mt")
        a5 = ease_out(prog(o, 2.7, 3.2))
        for i, ln in enumerate(["Anonymous messages are hidden from the group",
                                "but visible to the group's controller."]):
            draw_text(frame, ln, "Regular", 26, (W / 2, 1390 + i * 36), INK_SOFT, alpha=a5 * 0.9, anchor="mt")
        a6 = ease_out(prog(o, 3.3, 3.8))
        draw_text(frame, "Screens recorded from the real app.", "Regular", 24, (W / 2, 1490), INK_FAINT,
                  alpha=a6, anchor="mt")
    out = frame.convert("RGB").reduce(SS)
    return R.add_grain(out, k, 2.5)


def build_audio():
    """The tour score from make_tour, re-timed to these scenes."""
    T.SCENES = SCENES
    T.DUR = DUR
    T.GROOVE_END, T.SOFT_A, T.SOFT_B, T.OUTRO_AT = 81.4, 46.5, 51.5, 81.7
    SR = R.SR
    base = T.build_audio()  # groove ends ~79.4 there; extend with a short bridge and our outro
    total = int(DUR * SR)
    mix = np.zeros(total, np.float32)
    mix[: len(base)] = base[:total]
    return mix


def main():
    if "--stills" in sys.argv:
        out = HERE / "stills-real"
        out.mkdir(exist_ok=True)
        for a in sys.argv[2:]:
            t = float(a)
            render(t, int(t * FPS)).save(out / f"t{t:05.2f}.png")
        return
    audio = HERE / "soundtrack-real.wav"
    print("building soundtrack…", flush=True)
    R.write_wav(audio, build_audio())
    print(f"rendering {NFRAMES} frames…", flush=True)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(audio),
        "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p", "-profile:v", "high",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-shortest", str(OUT),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for k in range(NFRAMES):
        proc.stdin.write(render(k / FPS, k).tobytes())
        if k % 150 == 0:
            print(f"  {k}/{NFRAMES}", flush=True)
    proc.stdin.close()
    proc.wait()
    print("wrote", OUT)


if __name__ == "__main__":
    main()
