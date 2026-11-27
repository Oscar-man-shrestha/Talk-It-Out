"""Talk It Out — "Unsent": a 28-second Instagram Reel (1080x1920, 30 fps).

Renders every frame with Pillow (2x supersampled), synthesizes an original
score with numpy, and muxes both with ffmpeg (loudness-normalized for Reels).

    python3 make_reel.py              # full render -> talk-it-out-unsent.mp4
    python3 make_reel.py --stills     # a few PNG stills for review
    python3 make_reel.py --silent     # also write a version with no audio

The rewrite shown on screen is real output from the project's AI model
(Qwen2.5-3B via the pipeline), not invented copy.
"""

from __future__ import annotations

import math
import subprocess
import sys
import wave
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
FONTS = HERE / "fonts"
OUT = HERE / "talk-it-out-unsent.mp4"

W, H, FPS, DUR = 1080, 1920, 30, 28.0
SS = 2  # supersampling factor
NFRAMES = int(DUR * FPS)

# Brand (lib/core/ui/brand.dart)
INK = (9, 9, 11)
INK_SOFT = (113, 113, 122)
INK_FAINT = (161, 161, 170)
CANVAS = (252, 250, 246)
MUTED = (246, 242, 234)
BORDER = (231, 227, 220)
ACCENT_SOFT = (247, 241, 230)
ACCENT_BORDER = (234, 223, 204)
WHITE = (255, 255, 255)

ORIGINAL = "This plan makes no sense and nobody listens to us."
REWRITE = "This plan is not clear and our suggestions are not being considered."
GROUP = "Q3 launch plan"


# ─── helpers ──────────────────────────────────────────────────────────────

def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def prog(t, start, end):
    """0..1 progress of t through [start, end]."""
    return clamp((t - start) / (end - start)) if end > start else float(t >= start)


def ease_out(x):
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def ease_back(x, s=1.6):
    return 1 + (s + 1) * (x - 1) ** 3 + s * (x - 1) ** 2


def lerp(a, b, x):
    return a + (b - a) * x


def window(t, a, b, fade=0.35):
    """Opacity that fades in at a and out at b."""
    return min(ease_out(prog(t, a, a + fade)), 1 - ease_in_out(prog(t, b - fade, b)))


def S(v):
    return int(round(v * SS))


@lru_cache(maxsize=None)
def font(weight: str, size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / f"Inter-{weight}.ttf"), max(1, S(size)))


def text_layer(txt, fnt, fill):
    l, t, r, b = fnt.getbbox(txt)
    img = Image.new("RGBA", (max(1, r - l + 2), max(1, b - t + 2)), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((-l + 1, -t + 1), txt, font=fnt, fill=fill)
    return img, (l, t)


def with_alpha(layer, alpha):
    if alpha >= 0.999:
        return layer
    a = layer.getchannel("A").point(lambda v: int(v * alpha))
    out = layer.copy()
    out.putalpha(a)
    return out


def comp(base, layer, x, y, alpha=1.0):
    """Composite layer at SS-pixel position (x, y) with extra opacity."""
    if alpha <= 0.003:
        return
    layer = with_alpha(layer, alpha)
    x, y = int(round(x)), int(round(y))
    # Crop to base bounds (alpha_composite rejects negative offsets).
    bw, bh = base.size
    lw, lh = layer.size
    if x >= bw or y >= bh or x + lw <= 0 or y + lh <= 0:
        return
    cx0, cy0 = max(0, -x), max(0, -y)
    cx1, cy1 = min(lw, bw - x), min(lh, bh - y)
    if cx0 or cy0 or cx1 < lw or cy1 < lh:
        layer = layer.crop((cx0, cy0, cx1, cy1))
    base.alpha_composite(layer, (x + cx0, y + cy0))


def draw_text(base, txt, weight, size, xy, fill, alpha=1.0, anchor="lt", dx=0.0, dy=0.0):
    """Text at 1x coordinates. anchor: l/m/r + t/m/b."""
    fnt = font(weight, size)
    layer, _ = text_layer(txt, fnt, fill)
    x, y = S(xy[0] + dx), S(xy[1] + dy)
    lw, lh = layer.size
    if anchor[0] == "m":
        x -= lw // 2
    elif anchor[0] == "r":
        x -= lw
    if anchor[1] == "m":
        y -= lh // 2
    elif anchor[1] == "b":
        y -= lh
    comp(base, layer, x, y, alpha)
    return lw / SS, lh / SS


def wrap(txt, weight, size, width):
    fnt = font(weight, size)
    words, lines, cur = txt.split(), [], ""
    for w_ in words:
        test = (cur + " " + w_).strip()
        if fnt.getlength(test) / SS <= width:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def rrect_layer(w, h, r, fill, outline=None, width=0):
    img = Image.new("RGBA", (S(w), S(h)), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (0, 0, S(w) - 1, S(h) - 1), radius=S(r), fill=fill, outline=outline, width=S(width)
    )
    return img


def circle_layer(d, fill, outline=None, width=0):
    img = Image.new("RGBA", (S(d), S(d)), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((0, 0, S(d) - 1, S(d) - 1), fill=fill, outline=outline, width=S(width))
    return img


def scaled(layer, k):
    if abs(k - 1) < 1e-3:
        return layer
    w, h = layer.size
    return layer.resize((max(1, int(w * k)), max(1, int(h * k))), Image.BICUBIC)


def comp_centered(base, layer, cx, cy, alpha=1.0, k=1.0):
    """Composite at 1x centre (cx, cy) with scale k."""
    layer = scaled(layer, k)
    comp(base, layer, S(cx) - layer.size[0] / 2, S(cy) - layer.size[1] / 2, alpha)


# ─── icons ────────────────────────────────────────────────────────────────

def icon_send(d, bg=INK, fg=WHITE):
    img = circle_layer(d, bg)
    dr = ImageDraw.Draw(img)
    c, u = S(d) / 2, S(d) / 100
    dr.polygon([(c - 18 * u, c - 20 * u), (c + 24 * u, c), (c - 18 * u, c + 20 * u), (c - 9 * u, c)], fill=fg)
    return img


def icon_logo(d):
    img = rrect_layer(d, d, d * 0.26, INK)
    dr = ImageDraw.Draw(img)
    u = S(d) / 100
    dr.rounded_rectangle((24 * u, 26 * u, 76 * u, 64 * u), radius=10 * u, fill=WHITE)
    dr.polygon([(34 * u, 62 * u), (34 * u, 76 * u), (48 * u, 63 * u)], fill=WHITE)
    for i, x in enumerate((38, 50, 62)):
        dr.ellipse(((x - 4) * u, 41 * u, (x + 4) * u, 49 * u), fill=INK)
    return img


def icon_heart(d, fill):
    img = Image.new("RGBA", (S(d), S(d)), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    u = S(d) / 100
    dr.ellipse((8 * u, 12 * u, 52 * u, 56 * u), fill=fill)
    dr.ellipse((48 * u, 12 * u, 92 * u, 56 * u), fill=fill)
    dr.polygon([(11 * u, 44 * u), (89 * u, 44 * u), (50 * u, 90 * u)], fill=fill)
    return img


def icon_check(d, stroke, width):
    img = Image.new("RGBA", (S(d), S(d)), (0, 0, 0, 0))
    u = S(d) / 100
    ImageDraw.Draw(img).line(
        [(22 * u, 52 * u), (42 * u, 72 * u), (80 * u, 30 * u)], fill=stroke, width=S(width), joint="curve"
    )
    return img


def icon_sparkle(d, fill):
    img = Image.new("RGBA", (S(d), S(d)), (0, 0, 0, 0))
    u = S(d) / 100
    c = 50
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        r = 50 if i % 2 == 0 else 14
        pts.append(((c + r * math.cos(ang)) * u, (c + r * math.sin(ang)) * u))
    ImageDraw.Draw(img).polygon(pts, fill=fill)
    return img


def icon_x(d, stroke, width):
    img = Image.new("RGBA", (S(d), S(d)), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    u = S(d) / 100
    dr.line([(10 * u, 10 * u), (90 * u, 90 * u)], fill=stroke, width=S(width))
    dr.line([(90 * u, 10 * u), (10 * u, 90 * u)], fill=stroke, width=S(width))
    return img


def icon_person(d, bg, fg):
    img = circle_layer(d, bg)
    dr = ImageDraw.Draw(img)
    u = S(d) / 100
    dr.ellipse((36 * u, 22 * u, 64 * u, 50 * u), fill=fg)
    dr.pieslice((20 * u, 56 * u, 80 * u, 116 * u), 180, 360, fill=fg)
    return img


def icon_mask(d, bg, fg):
    """Anonymous avatar: a simple masked face."""
    img = circle_layer(d, bg)
    dr = ImageDraw.Draw(img)
    u = S(d) / 100
    dr.rounded_rectangle((20 * u, 38 * u, 80 * u, 60 * u), radius=11 * u, fill=fg)
    dr.ellipse((30 * u, 43 * u, 44 * u, 55 * u), fill=bg)
    dr.ellipse((56 * u, 43 * u, 70 * u, 55 * u), fill=bg)
    return img


# ─── backgrounds ──────────────────────────────────────────────────────────

def make_dark_bg():
    img = Image.new("RGBA", (S(W), S(H)), INK + (255,))
    glow = Image.new("L", (W // 4, H // 4), 0)
    ImageDraw.Draw(glow).ellipse((W // 8 - 170, H // 8 - 240, W // 8 + 170, H // 8 + 200), fill=40)
    glow = glow.filter(ImageFilter.GaussianBlur(60)).resize((S(W), S(H)), Image.BICUBIC)
    warm = Image.new("RGBA", (S(W), S(H)), (60, 52, 40, 255))
    img = Image.composite(warm, img, glow)
    return img


def make_light_bg():
    img = Image.new("RGBA", (S(W), S(H)), CANVAS + (255,))
    glow = Image.new("L", (W // 4, H // 4), 0)
    ImageDraw.Draw(glow).ellipse((W // 8 - 200, H // 8 - 380, W // 8 + 200, H // 8 + 60), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(70)).resize((S(W), S(H)), Image.BICUBIC)
    warm = Image.new("RGBA", (S(W), S(H)), (255, 252, 244, 255))
    shade = Image.new("RGBA", (S(W), S(H)), ACCENT_SOFT + (255,))
    img = Image.composite(warm, shade, glow)
    return img


rng = np.random.default_rng(7)
# Zero-mean film grain (in 8-bit levels), a few frames' worth, cycled.
GRAIN = [rng.normal(0, 1, (H, W, 1)).astype(np.float32) for _ in range(6)]


def add_grain(frame_rgb, k, strength):
    """strength is the grain's standard deviation in 8-bit levels."""
    if strength <= 0:
        return frame_rgb
    arr = np.asarray(frame_rgb, dtype=np.float32) + GRAIN[k % len(GRAIN)] * strength
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


# ─── phone screens (drawn in 390x808 pt, scaled to the phone) ─────────────

PH_W, PH_H = 600, 1210          # phone body at 1x
SCR_W, SCR_H = 560, 1170        # screen inside the body
K = SCR_W / 390                 # pt -> 1x px


def P(v):
    return v * K


def screen_base():
    return Image.new("RGBA", (S(SCR_W), S(SCR_H)), CANVAS + (255,))


def status_bar(img):
    draw_text(img, "9:41", "SemiBold", P(13), (P(28), P(16)), INK)
    for i, h in enumerate((5, 7, 9, 11)):
        lay = rrect_layer(P(3), P(h), P(1), INK + (255,))
        comp(img, lay, S(P(318 + i * 5)), S(P(28 - h)))
    comp(img, rrect_layer(P(22), P(11), P(3), None, INK + (255,), P(1.2)), S(P(346)), S(P(17)))
    comp(img, rrect_layer(P(16), P(7), P(1.5), INK + (255,)), S(P(348)), S(P(19)))


def app_bar(img, title, subtitle):
    status_bar(img)
    ImageDraw.Draw(img).line([(S(P(22)), S(P(70))), (S(P(30)), S(P(62)))], fill=INK, width=S(P(2)))
    ImageDraw.Draw(img).line([(S(P(22)), S(P(70))), (S(P(30)), S(P(78)))], fill=INK, width=S(P(2)))
    comp(img, rrect_layer(P(34), P(34), P(9), INK + (255,)), S(P(44)), S(P(53)))
    draw_text(img, title[:1], "Bold", P(15), (P(61), P(70)), WHITE, anchor="mm")
    draw_text(img, title, "SemiBold", P(16), (P(88), P(53)), INK)
    draw_text(img, subtitle, "Regular", P(12), (P(88), P(73)), INK_SOFT)
    ImageDraw.Draw(img).line([(0, S(P(98))), (S(SCR_W), S(P(98)))], fill=BORDER, width=S(1))


def bubble(img, x, y, w, lines, name, avatar, alpha=1.0, k=1.0, mine=False, bg=WHITE):
    """Chat bubble at pt coords; returns bubble height in pt."""
    fs, lh = 15, 21
    bh = 16 + 18 + len(lines) * lh + 10
    lay = Image.new("RGBA", (S(P(w + 44)), S(P(bh + 4))), (0, 0, 0, 0))
    comp(lay, avatar, 0, S(P(bh - 34)))
    comp(lay, rrect_layer(P(w), P(bh), P(16), bg + (255,), BORDER + (255,), 1), S(P(42)), 0)
    draw_text(lay, name, "SemiBold", P(12), (P(56), P(10)), INK_SOFT)
    for i, ln in enumerate(lines):
        draw_text(lay, ln, "Regular", P(fs), (P(56), P(32 + i * lh)), INK)
    lay = scaled(lay, k)
    comp(img, lay, S(P(x)) + (1 - k) * S(P(w)) / 2, S(P(y)) + (1 - k) * S(P(bh)) / 2, alpha)
    return bh


def composer_screen(t):
    img = screen_base()
    app_bar(img, GROUP, "6 members")
    av_l = icon_person(P(30), MUTED + (255,), INK_SOFT + (255,))
    av_a = icon_mask(P(30), INK + (255,), WHITE + (255,))
    bubble(img, 14, 118, 300, ["Plan is shared. Thoughts", "by Friday?"], "Rahul · Lead", av_l)
    bubble(img, 14, 220, 300, ["Can we add QA time to", "week 2?"], "Anonymous user", av_a)

    # Composer at the bottom.
    y0 = 640
    ImageDraw.Draw(img).rectangle((0, S(P(y0)), S(SCR_W), S(SCR_H)), fill=WHITE)
    ImageDraw.Draw(img).line([(0, S(P(y0))), (S(SCR_W), S(P(y0)))], fill=BORDER, width=S(1))
    # Anonymous checkbox + disclosure (hard rules 4 and 7).
    tick = ease_back(prog(t, 10.55, 10.85))
    box = rrect_layer(P(20), P(20), P(5), (INK if tick > 0.5 else WHITE) + (255,), INK + (255,), 1.6)
    comp(img, box, S(P(20)), S(P(y0 + 16)))
    if tick > 0:
        chk = scaled(icon_check(P(20), WHITE + (255,), P(2.6)), max(0.01, tick))
        comp(img, chk, S(P(30)) - chk.size[0] / 2, S(P(y0 + 26)) - chk.size[1] / 2)
    draw_text(img, "Anonymous message", "SemiBold", P(14), (P(50), P(y0 + 17)), INK)
    for i, ln in enumerate(["Anonymous messages are hidden from the group",
                            "but visible to the controller."]):
        draw_text(img, ln, "Regular", P(11.5), (P(50), P(y0 + 38 + i * 15)), INK_SOFT)

    # Input field with typed text.
    fy = y0 + 84
    comp(img, rrect_layer(P(300), P(76), P(18), MUTED + (255,), BORDER + (255,), 1), S(P(16)), S(P(fy)))
    n = int(len(ORIGINAL) * ease_in_out(prog(t, 8.95, 10.35)))
    typed = ORIGINAL[:n]
    sent = t >= 11.35
    if sent:
        typed = ""
    if typed:
        for i, ln in enumerate(wrap(typed, "Regular", P(15), P(268))[:3]):
            draw_text(img, ln, "Regular", P(15), (P(30), P(fy + 12 + i * 20)), INK)
    else:
        draw_text(img, "Write a message…", "Regular", P(15), (P(30), P(fy + 12)), INK_FAINT)
    # Send button with press.
    press = prog(t, 11.15, 11.35)
    k = 1 - 0.12 * math.sin(math.pi * press)
    comp_centered(img, icon_send(P(48)), P(350), P(fy + 38), k=k)
    if 11.2 <= t <= 11.9:
        r = ease_out(prog(t, 11.2, 11.9))
        ring = circle_layer(P(48 + 60 * r), None, INK + (int(140 * (1 - r)),), 2)
        comp_centered(img, ring, P(350), P(fy + 38))

    # "Sent for review" banner.
    ba = window(t, 11.45, 12.6, 0.25)
    if ba > 0:
        lay = rrect_layer(P(262), P(40), P(20), INK + (255,))
        draw_text(lay, "Sent for review · rewriting…", "Medium", P(13), (P(131), P(20)), WHITE, anchor="mm")
        comp(img, lay, S(P(64)), S(P(570 + 10 * (1 - ease_out(prog(t, 11.45, 11.75))))), ba)
    return img


def shimmer_lines(img, x, y, widths, t):
    for i, w in enumerate(widths):
        lay = rrect_layer(P(w), P(11), P(5), (226, 220, 210, 255))
        comp(img, lay, S(P(x)), S(P(y + i * 20)), 0.55 + 0.45 * math.sin(t * 9 - i))


def review_screen(t):
    img = screen_base()
    status_bar(img)
    draw_text(img, "REVIEW", "SemiBold", P(11), (P(20), P(50)), INK_SOFT)
    draw_text(img, GROUP, "Bold", P(20), (P(20), P(66)), INK)
    comp(img, rrect_layer(P(108), P(26), P(13), None, INK + (255,), 1), S(P(262)), S(P(64)))
    draw_text(img, "PENDING REVIEW", "SemiBold", P(9.5), (P(316), P(77)), INK, anchor="mm")
    # Sender row: controllers see the sender; the chip shows it was anonymous.
    comp(img, rrect_layer(P(350), P(56), P(14), MUTED + (255,), BORDER + (255,), 1), S(P(20)), S(P(104)))
    comp(img, icon_mask(P(32), INK + (255,), WHITE + (255,)), S(P(32)), S(P(116)))
    draw_text(img, "Sent as anonymous", "SemiBold", P(14), (P(74), P(114)), INK)
    draw_text(img, "Hidden from the group", "Regular", P(12), (P(74), P(134)), INK_SOFT)

    # Original card.
    cy = 178
    comp(img, rrect_layer(P(350), P(122), P(14), WHITE + (255,), BORDER + (255,), 1), S(P(20)), S(P(cy)))
    draw_text(img, "ORIGINAL MESSAGE", "SemiBold", P(10.5), (P(36), P(cy + 16)), INK_SOFT)
    for i, ln in enumerate(wrap(f"“{ORIGINAL}”", "Italic", P(15), P(316))):
        draw_text(img, ln, "Italic", P(15), (P(36), P(cy + 40 + i * 21)), INK)

    # AI rewrite card.
    ry = 316
    comp(img, rrect_layer(P(350), P(170), P(14), ACCENT_SOFT + (255,), ACCENT_BORDER + (255,), 1.2),
         S(P(20)), S(P(ry)))
    comp(img, icon_sparkle(P(16), INK + (255,)), S(P(35)), S(P(ry + 13)))
    draw_text(img, "AI REWRITE", "SemiBold", P(10.5), (P(56), P(ry + 16)), INK)
    reveal = prog(t, 13.05, 14.3)
    if t < 13.05:
        shimmer_lines(img, 36, ry + 44, (300, 280, 200), t)
        draw_text(img, "Rewriting…", "Medium", P(12), (P(36), P(ry + 112)), INK_SOFT)
    else:
        words = REWRITE.split()
        shown = words[: max(1, int(len(words) * ease_out(reveal) + 0.999))]
        for i, ln in enumerate(wrap("“" + " ".join(shown) + ("”" if reveal >= 1 else ""), "Medium", P(16), P(316))):
            draw_text(img, ln, "Medium", P(16), (P(36), P(ry + 42 + i * 23)), INK)
        ka = ease_out(prog(t, 14.4, 14.8))
        if ka > 0:
            lay = Image.new("RGBA", (S(P(170)), S(P(22))), (0, 0, 0, 0))
            comp(lay, icon_check(P(18), INK + (255,), P(2.2)), 0, S(P(2)))
            draw_text(lay, "Meaning kept · 100%", "SemiBold", P(12), (P(22), P(4)), INK)
            comp(img, lay, S(P(36)), S(P(ry + 136)) + (1 - ka) * S(P(6)), ka)

    # Actions.
    by = 690
    comp(img, rrect_layer(P(164), P(52), P(12), WHITE + (255,), INK + (255,), 1.2), S(P(20)), S(P(by)))
    comp(img, icon_x(P(14), INK + (255,), P(2)), S(P(66)), S(P(by + 19)))
    draw_text(img, "Reject", "SemiBold", P(15), (P(110), P(by + 26)), INK, anchor="mm")
    press = prog(t, 17.0, 17.2)
    k = 1 - 0.06 * math.sin(math.pi * press)
    done = t >= 17.35
    pub = rrect_layer(P(178), P(52), P(12), INK + (255,))
    label = "Published  ✓" if done else "Publish rewrite"
    draw_text(pub, label, "SemiBold", P(15), (P(89), P(26)), WHITE, anchor="mm")
    comp_centered(img, pub, P(192 + 89), P(by + 26), k=k)
    return img


def chat_screen(t):
    img = screen_base()
    app_bar(img, GROUP, "6 members")
    av_l = icon_person(P(30), MUTED + (255,), INK_SOFT + (255,))
    av_a = icon_mask(P(30), INK + (255,), WHITE + (255,))
    av_p = icon_person(P(30), ACCENT_SOFT + (255,), INK + (255,))
    bubble(img, 14, 118, 300, ["Plan is shared. Thoughts", "by Friday?"], "Rahul · Lead", av_l)
    bubble(img, 14, 220, 300, ["Can we add QA time to", "week 2?"], "Anonymous user", av_a)

    # The new, published message.
    a1 = ease_out(prog(t, 18.05, 18.4))
    lines = wrap(REWRITE, "Regular", P(15), P(268))
    if a1 > 0:
        bh = bubble(img, 14, 322, 310, lines, "Anonymous user", av_a, alpha=a1, k=lerp(0.85, 1, ease_back(prog(t, 18.05, 18.45))))
        # Reactions.
        r1 = prog(t, 19.0, 19.3)
        if r1 > 0:
            count = "6" if t >= 20.8 else "4"
            pill = rrect_layer(P(64), P(28), P(14), WHITE + (255,), BORDER + (255,), 1)
            comp(pill, icon_heart(P(16), (220, 38, 38, 255)), S(P(12)), S(P(6)))
            draw_text(pill, count, "SemiBold", P(13), (P(36), P(7)), INK)
            comp_centered(img, pill, P(56 + 32), P(322 + bh + 6), alpha=ease_out(r1),
                          k=ease_back(r1) * (1 + 0.15 * math.sin(math.pi * prog(t, 20.8, 21.05))))
    # Lead's reply.
    a2 = ease_out(prog(t, 19.8, 20.15))
    if a2 > 0:
        bubble(img, 14, 480, 300, ["Good point. Let's fix", "priorities tomorrow."], "Rahul · Lead", av_l,
               alpha=a2, k=lerp(0.85, 1, ease_back(prog(t, 19.8, 20.2))))
    # Input bar.
    ImageDraw.Draw(img).rectangle((0, S(P(740)), S(SCR_W), S(SCR_H)), fill=WHITE)
    ImageDraw.Draw(img).line([(0, S(P(740))), (S(SCR_W), S(P(740)))], fill=BORDER, width=S(1))
    comp(img, rrect_layer(P(300), P(44), P(22), MUTED + (255,)), S(P(16)), S(P(752)))
    draw_text(img, "Write a message…", "Regular", P(15), (P(32), P(764)), INK_FAINT)
    comp_centered(img, icon_send(P(44)), P(350), P(774))
    return img


PHONE_MASK = None


def phone_layer(screen):
    global PHONE_MASK
    body = rrect_layer(PH_W, PH_H, 86, INK + (255,))
    if PHONE_MASK is None:
        PHONE_MASK = Image.new("L", (S(SCR_W), S(SCR_H)), 0)
        ImageDraw.Draw(PHONE_MASK).rounded_rectangle((0, 0, S(SCR_W) - 1, S(SCR_H) - 1), radius=S(66), fill=255)
    scr = screen.copy()
    scr.putalpha(Image.composite(scr.getchannel("A"), Image.new("L", scr.size, 0), PHONE_MASK))
    body.alpha_composite(scr, (S((PH_W - SCR_W) / 2), S((PH_H - SCR_H) / 2)))
    # Dynamic island.
    comp(body, rrect_layer(110, 32, 16, INK + (255,)), S(PH_W / 2 - 55), S(34))
    return body


SHADOW = None


def phone_shadow():
    global SHADOW
    if SHADOW is None:
        sh = Image.new("RGBA", (S(PH_W + 200), S(PH_H + 200)), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((S(100), S(130), S(PH_W + 100), S(PH_H + 110)), radius=S(86),
                                             fill=(60, 45, 25, 70))
        SHADOW = sh.filter(ImageFilter.GaussianBlur(S(40)))
    return SHADOW


# ─── the film ─────────────────────────────────────────────────────────────

DARK_BG = None
LIGHT_BG = None

# Camera keyframes: (time, zoom, focus point in screen pt).
CAMERA = [
    (8.3, 1.0, 404), (9.0, 1.0, 404), (9.7, 1.42, 705), (11.6, 1.42, 705), (12.0, 1.0, 404),
    (12.35, 1.0, 404), (13.1, 1.42, 400), (15.9, 1.42, 400), (16.45, 1.3, 640), (17.75, 1.3, 640),
    (18.0, 1.0, 404), (18.25, 1.0, 404), (18.9, 1.38, 470), (21.45, 1.38, 470), (21.8, 1.0, 404),
]
FOCUS_Y = 1060  # where the focus point lands on the canvas when zoomed


def camera(t):
    if t <= CAMERA[0][0]:
        return CAMERA[0][1], CAMERA[0][2]
    for (t0, z0, f0), (t1, z1, f1) in zip(CAMERA, CAMERA[1:]):
        if t0 <= t <= t1:
            x = ease_in_out(prog(t, t0, t1))
            return lerp(z0, z1, x), lerp(f0, f1, x)
    return CAMERA[-1][1], CAMERA[-1][2]


BAND = None


def caption_band():
    global BAND
    if BAND is None:
        a = np.zeros((S(480), 1), np.float32)
        ys = np.arange(S(480)) / SS
        a[:, 0] = np.where(ys < 370, 1.0, np.clip(1 - (ys - 370) / 110, 0, 1)) * 0.96
        alpha = Image.fromarray((a * 255).astype(np.uint8), "L").resize((S(W), S(480)))
        BAND = Image.new("RGBA", (S(W), S(480)), CANVAS + (255,))
        BAND.putalpha(alpha)
    return BAND


def caption(base, lines, t, a, b, y=240, size=58, color=INK, sub=None):
    alpha = window(t, a, b, 0.3)
    if alpha <= 0:
        return
    for i, ln in enumerate(lines):
        li = ease_out(prog(t, a + i * 0.12, a + i * 0.12 + 0.45))
        draw_text(base, ln, "Bold", size, (W / 2, y + i * size * 1.18), color,
                  alpha=alpha * li, anchor="mt", dy=(1 - li) * 28)


def render(t: float, k: int) -> Image.Image:
    global DARK_BG, LIGHT_BG
    if DARK_BG is None:
        DARK_BG, LIGHT_BG = make_dark_bg(), make_light_bg()

    if t < 7.0:
        frame = DARK_BG.copy()
        # Slow drift: the whole dark act breathes in.
        hook_a = 1 - ease_in_out(prog(t, 4.6, 5.0))
        # Kinetic caption.
        if t < 3.0:
            caption(frame, ["Sab ne kabhi na kabhi", "ye message type kiya hai."], t, 0.15, 3.0, y=520,
                    size=60, color=WHITE)
        elif t < 5.0:
            caption(frame, ["…aur phir", "delete kar diya."], t, 3.0, 4.95, y=520, size=60, color=WHITE)
        # The unsent message field.
        if hook_a > 0:
            fx, fy, fw, fh = 90, 900, 900, 230
            field = rrect_layer(fw, fh, 46, (28, 28, 32, 255), (63, 63, 70, 255), 1.5)
            if t < 3.0:
                n = int(len(ORIGINAL) * ease_in_out(prog(t, 0.35, 2.3)))
            else:
                n = int(len(ORIGINAL) * (1 - prog(t, 3.05, 4.45)))
            typed = ORIGINAL[:n]
            lines = wrap(typed, "Medium", 46, 700) if typed else []
            for i, ln in enumerate(lines[:3]):
                draw_text(field, ln, "Medium", 46, (44, 40 + i * 60), WHITE)
            if int(t * 2.2) % 2 == 0 or (0.35 < t < 2.3) or (3.05 < t < 4.45):
                last = lines[-1] if lines else ""
                cx = 44 + (font("Medium", 46).getlength(last) / SS if last else 0) + 6
                cy = 40 + max(0, len(lines) - 1) * 60
                comp(field, rrect_layer(4, 54, 2, WHITE + (230,)), S(cx), S(cy))
            if not typed and t > 4.45:
                draw_text(field, "Message", "Medium", 46, (44, 40), (113, 113, 122))
            comp(frame, field, S(fx), S(fy), hook_a)
            # Send button: the thumb hovers, never presses.
            pulse = 1 + 0.07 * math.sin(math.pi * prog(t, 2.35, 2.95))
            glow = window(t, 2.3, 3.1, 0.3)
            if glow > 0:
                comp_centered(frame, circle_layer(170, (255, 255, 255, 40)), 870, 1210, alpha=glow * hook_a,
                              k=1 + 0.2 * prog(t, 2.3, 3.1))
            comp_centered(frame, icon_send(120, WHITE, INK), 870, 1210, alpha=hook_a, k=pulse)
            draw_text(frame, "Send", "Medium", 30, (870, 1290), (161, 161, 170), alpha=hook_a * 0.9, anchor="mt")
        # Act break: the reason.
        if t >= 5.0:
            a = ease_out(prog(t, 5.05, 5.6))
            zoom = 1 + 0.035 * prog(t, 5.0, 7.0)
            l1, _ = text_layer("Kyunki sach bolna", font("Bold", 84 * zoom), WHITE)
            comp(frame, l1, S(W / 2) - l1.size[0] / 2, S(840) + (1 - a) * S(30), a)
            word = text_layer("risky", font("ExtraBold", 84 * zoom), INK)[0]
            rest = text_layer(" lagta hai.", font("Bold", 84 * zoom), WHITE)[0]
            hi = ease_out(prog(t, 5.6, 6.0))
            tot = word.size[0] + S(28) + rest.size[0]
            x0 = S(W / 2) - tot / 2
            y0 = S(960) + (1 - a) * S(30)
            box = Image.new("RGBA", (int((word.size[0] + S(28)) * max(0.01, hi)), word.size[1] + S(26)),
                            ACCENT_SOFT + (255,))
            comp(frame, box, x0, y0 - S(13), a)
            comp(frame, word, x0 + S(14), y0, a)
            comp(frame, rest, x0 + word.size[0] + S(28), y0, a)
        # Iris into the light.
        if t >= 6.75:
            r = ease_in_out(prog(t, 6.75, 7.0))
            mask = Image.new("L", (S(W), S(H)), 0)
            rad = S(r * 1200)
            ImageDraw.Draw(mask).ellipse((S(W / 2) - rad, S(H / 2) - rad, S(W / 2) + rad, S(H / 2) + rad), fill=255)
            frame = Image.composite(LIGHT_BG, frame, mask)
        grain = 5.0
    else:
        frame = LIGHT_BG.copy()
        grain = 2.5
        # "Ab ek aur raasta hai."
        if t < 8.6:
            caption(frame, ["Ab ek aur", "raasta hai."], t, 7.05, 8.55, y=820, size=92)
        # Phone act.
        if 8.3 <= t < 22.3:
            if t < 12.0:
                scr = composer_screen(t)
            elif t < 18.0:
                scr = review_screen(t)
            else:
                scr = chat_screen(t)
            # Screen-to-screen push.
            for edge in (12.0, 18.0):
                if edge - 0.0 <= t < edge + 0.35:
                    prev = composer_screen(edge - 0.01) if edge == 12.0 else review_screen(edge - 0.01)
                    x = ease_in_out(prog(t, edge, edge + 0.35))
                    mix = Image.new("RGBA", scr.size, CANVAS + (255,))
                    mix.alpha_composite(prev, (int(-x * scr.size[0] * 0.35), 0))
                    mix.alpha_composite(with_alpha(scr, x), (int((1 - x) * scr.size[0] * 0.25), 0))
                    scr = mix
            phone = phone_layer(scr)
            enter = ease_out(prog(t, 8.3, 9.0))
            leave = ease_in_out(prog(t, 21.8, 22.3))
            # Camera: push in on each beat (typing, rewrite, publish, chat).
            zoom, focus_pt = camera(t)
            cx = W / 2
            base_cy = 420 + PH_H / 2
            off = focus_pt * K + (PH_H - SCR_H) / 2 - PH_H / 2
            w_ = clamp((zoom - 1) / 0.3)
            cy = lerp(base_cy, FOCUS_Y - off * zoom, w_) + (1 - enter) * 520 + leave * 600
            sh = scaled(phone_shadow(), zoom)
            comp(frame, sh, S(cx) - sh.size[0] / 2, S(cy) - sh.size[1] / 2, enter * (1 - leave))
            comp_centered(frame, phone, cx, cy, alpha=enter * (1 - leave), k=zoom)
            # A soft cream band keeps captions readable over a zoomed phone.
            comp(frame, caption_band(), 0, 0, clamp(w_ * 1.6) * (1 - leave))
            # Captions over the phone act.
            caption(frame, ["Talk It Out pe bhejo."], t, 8.7, 11.95, y=250)
            caption(frame, ["Wahi baat.", "Behtar tone."], t, 12.05, 14.2, y=220)
            caption(frame, ["AI tone badalta hai,", "matlab nahi."], t, 14.25, 16.15, y=220)
            caption(frame, ["Lead review karta hai.", "Phir group dekhta hai."], t, 16.2, 18.0, y=220)
            caption(frame, ["Point pahuncha.", "Drama nahi."], t, 18.05, 22.0, y=220)
        # Payoff.
        if 22.2 <= t < 24.6:
            a = 1 - ease_in_out(prog(t, 24.25, 24.6))
            l1 = ease_out(prog(t, 22.3, 22.8))
            l2 = ease_out(prog(t, 22.75, 23.25))
            draw_text(frame, "Sach bhi bola.", "ExtraBold", 104, (W / 2, 800), INK, alpha=a * l1, anchor="mt",
                      dx=(1 - l1) * -60)
            w2, h2 = draw_text(frame, "Rishte bhi bache.", "ExtraBold", 104, (W / 2, 940), INK, alpha=a * l2,
                               anchor="mt", dx=(1 - l2) * 60)
            ul = ease_in_out(prog(t, 23.2, 23.7))
            if ul > 0:
                comp(frame, rrect_layer(w2 * ul, 10, 5, INK + (255,)), S(W / 2 - w2 / 2), S(940 + h2 + 18), a)
        # End card.
        if t >= 24.5:
            li = ease_back(prog(t, 24.55, 25.05))
            comp_centered(frame, icon_logo(190), W / 2, 720, alpha=clamp(li * 1.2), k=max(0.01, 0.6 + 0.4 * li))
            a1 = ease_out(prog(t, 24.9, 25.4))
            draw_text(frame, "Talk It Out", "ExtraBold", 104, (W / 2, 860), INK, alpha=a1, anchor="mt",
                      dy=(1 - a1) * 24)
            a2 = ease_out(prog(t, 25.3, 25.8))
            draw_text(frame, "Sach bolo. Shaanti se.", "Regular", 52, (W / 2, 1000), INK_SOFT, alpha=a2,
                      anchor="mt", dy=(1 - a2) * 20)
            a3 = ease_back(prog(t, 25.8, 26.2))
            if a3 > 0:
                pill = rrect_layer(330, 92, 46, INK + (255,))
                draw_text(pill, "Link in bio  →", "SemiBold", 36, (165, 46), WHITE, anchor="mm")
                comp_centered(frame, pill, W / 2, 1160, alpha=clamp(a3), k=max(0.01, 0.8 + 0.2 * a3))
            a4 = ease_out(prog(t, 26.2, 26.7))
            for i, ln in enumerate(["Anonymous messages are hidden from the group",
                                    "but visible to the group's controller."]):
                draw_text(frame, ln, "Regular", 27, (W / 2, 1300 + i * 38), INK_SOFT, alpha=a4 * 0.9, anchor="mt")

    out = frame.convert("RGB").reduce(SS)
    return add_grain(out, k, grain)


# ─── soundtrack ───────────────────────────────────────────────────────────

SR = 44100


def env_exp(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def note_freq(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    return 440.0 * 2 ** ((names[name[0]] + 12 * (int(name[-1]) - 4)) / 12)


def piano(freq, dur, vel=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h in range(1, 8):
        detune = 1 + 0.0007 * (h - 1)
        sig += (1 / h ** 1.4) * np.sin(2 * np.pi * freq * h * detune * t) * np.exp(-t * (1.6 + 1.3 * h))
    att = np.minimum(1, t / 0.006)
    return vel * sig * att


def pad(freqs, dur, vol=0.08, attack=0.8):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = sum(np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.003 * t) for f in freqs)
    envl = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / 0.6)
    return vol * sig * np.clip(envl, 0, 1) / len(freqs)


def noise(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def highpass(x, a=0.95):
    y = np.empty_like(x)
    prev_x = prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = a * (prev_y + v - prev_x)
        prev_x = v
        y[i] = prev_y
    return y


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def kick():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 46 + 90 * np.exp(-t * 28)
    return 0.95 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)


SNARE_N = highpass(noise(int(0.25 * SR), 3), 0.7)
HAT_N = highpass(noise(int(0.08 * SR), 4), 0.4)
CLICK_N = highpass(noise(int(0.012 * SR), 5), 0.3)


def snare():
    n = len(SNARE_N)
    t = np.arange(n) / SR
    return 0.45 * SNARE_N * np.exp(-t * 20) + 0.3 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28)


def hat():
    t = np.arange(len(HAT_N)) / SR
    return 0.16 * HAT_N * np.exp(-t * 55)


def click(vol=0.35):
    return vol * CLICK_N * env_exp(len(CLICK_N), 500)


def blip(f0, f1, dur, vol):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    return vol * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 40)


def whoosh(dur=0.55, vol=0.22, seed=9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = lowpass(noise(n, seed), 0.08)
    return vol * x * np.sin(np.pi * t / dur) ** 2 * 3


def riser(dur, vol=0.25):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = highpass(noise(n, 11), 0.97)
    tone = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 900, n)) / SR)
    envl = (t / dur) ** 2.2
    return vol * envl * (0.7 * x + 0.35 * tone)


def boom(dur=1.8, vol=0.8):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(72, 34, n)
    return vol * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)


def heartbeat():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    return 0.55 * np.sin(2 * np.pi * 52 * t) * np.exp(-t * 16)


def reverb(x, seconds=1.6, mix=0.22):
    n = int(seconds * SR)
    ir = noise(n, 21) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    ir[0] = 0
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    wet /= np.max(np.abs(wet)) + 1e-9
    return x + mix * wet * np.max(np.abs(x))


def build_audio() -> np.ndarray:
    total = int(DUR * SR) + SR
    music = np.zeros(total)
    sfx = np.zeros(total)

    def add(buf, sig, at, gain=1.0):
        i = int(at * SR)
        j = min(total, i + len(sig))
        buf[i:j] += gain * sig[: j - i]

    # Act 1: tension.
    for i in range(10):
        add(sfx, click(0.22 if i % 2 else 0.3), 0.05 + i * 0.5)
    rng_ = np.random.default_rng(1)
    for i in range(len(ORIGINAL)):
        ti = 0.35 + 1.95 * ease_in_out(i / len(ORIGINAL))
        if ORIGINAL[i] != " ":
            add(sfx, click(0.12 + 0.05 * rng_.random()), ti)
    for i in range(30):
        add(sfx, click(0.1), 3.05 + i * (1.4 / 30))
    beat = 1.5
    while beat < 5.0:
        add(music, heartbeat(), beat)
        add(music, heartbeat(), beat + 0.22, 0.6)
        beat += 0.86
    add(music, boom(), 5.0)
    add(sfx, whoosh(0.5, 0.25), 6.6)

    # Act 2: the piano opens up.
    prog_ = [(7.0, ["C3", "G3", "E4"]), (9.4, ["A2", "E3", "C4"]), (11.8, ["F2", "C3", "A3"]),
             (14.2, ["G2", "D3", "B3"])]
    for at, chord in prog_:
        for j, nn in enumerate(chord):
            add(music, piano(note_freq(nn), 3.2, 0.32), at + j * 0.09)
        add(music, pad([note_freq(nn) for nn in chord], 2.6, 0.05), at)
    melody = [(8.2, "G4"), (8.8, "E4"), (10.6, "E4"), (11.2, "C5"), (13.0, "C5"), (13.6, "A4")]
    for at, nn in melody:
        add(music, piano(note_freq(nn), 1.8, 0.22), at)
    # UI sounds.
    for i in range(len(ORIGINAL)):
        if ORIGINAL[i] != " ":
            add(sfx, click(0.07), 8.95 + 1.4 * ease_in_out(i / len(ORIGINAL)))
    add(sfx, blip(1300, 1500, 0.06, 0.18), 10.65)
    add(sfx, blip(900, 600, 0.07, 0.22), 11.2)
    add(sfx, whoosh(0.45, 0.2, 12), 11.85)
    add(sfx, blip(1700, 1900, 0.05, 0.08), 14.45)
    add(music, riser(3.3, 0.22), 14.7)
    add(sfx, blip(900, 600, 0.07, 0.22), 17.05)
    add(sfx, blip(1200, 1600, 0.09, 0.15), 17.35)

    # Act 3: the drop (100 BPM).
    bpm, start, end = 100, 18.0, 24.45
    spb = 60 / bpm
    chords = [["C3", "G3", "E4"], ["G2", "D3", "B3"], ["A2", "E3", "C4"], ["F2", "C3", "A3"]]
    b = 0
    tt = start
    while tt < end - 0.01:
        add(music, kick(), tt, 0.9)
        if b % 2 == 1:
            add(music, snare(), tt, 0.7)
        add(music, hat(), tt + spb / 2)
        add(music, hat(), tt, 0.6)
        if b % 2 == 0:
            ch = chords[(b // 2) % 4]
            for j, nn in enumerate(ch):
                add(music, piano(note_freq(nn), 1.4, 0.26), tt + j * 0.02)
            add(music, pad([note_freq(nn) for nn in ch], 1.3, 0.05, 0.05), tt)
            bass = note_freq(ch[0][0] + "2")
            n = int(1.1 * SR)
            tb = np.arange(n) / SR
            add(music, 0.32 * np.sin(2 * np.pi * bass * tb) * np.exp(-tb * 2.5), tt)
        b += 1
        tt += spb
    add(sfx, boom(1.2, 0.5), 18.0)
    for at in (18.05, 19.0, 19.8, 20.8):
        add(sfx, blip(500, 950, 0.08, 0.16), at)
    add(sfx, whoosh(0.5, 0.22, 13), 21.75)
    add(sfx, whoosh(0.5, 0.18, 14), 24.2)

    # Resolve.
    for j, nn in enumerate(["C3", "G3", "E4", "B4"]):
        add(music, piano(note_freq(nn), 3.6, 0.3), 24.5 + j * 0.12)
    add(music, pad([note_freq(n) for n in ["C3", "G3", "E4", "B4"]], 3.4, 0.06, 0.4), 24.5)
    add(sfx, blip(700, 1100, 0.1, 0.12), 25.8)

    mix = reverb(music, 1.8, 0.28) + reverb(sfx, 0.6, 0.1)
    mix = mix[: int(DUR * SR)]
    fade = np.ones_like(mix)
    fn = int(0.8 * SR)
    fade[-fn:] = np.linspace(1, 0, fn)
    mix *= fade
    mix /= np.max(np.abs(mix)) + 1e-9
    return (mix * 0.89).astype(np.float32)


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    stereo = np.stack([pcm, pcm], axis=1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())


# ─── main ─────────────────────────────────────────────────────────────────

def main():
    if "--stills" in sys.argv:
        stills = HERE / "stills"
        stills.mkdir(exist_ok=True)
        times = [float(a) for a in sys.argv[2:]] or [1.6, 4.0, 6.2, 7.6, 10.9, 13.6, 15.0, 17.4, 20.9, 23.6, 27.0]
        for t in times:
            render(t, int(t * FPS)).save(stills / f"t{t:05.2f}.png")
            print("still", t)
        return

    audio_path = HERE / "soundtrack.wav"
    print("building soundtrack…", flush=True)
    write_wav(audio_path, build_audio())

    print(f"rendering {NFRAMES} frames…", flush=True)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(audio_path),
        "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-profile:v", "high",
        "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-shortest", str(OUT),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for k in range(NFRAMES):
        proc.stdin.write(render(k / FPS, k).tobytes())
        if k % 60 == 0:
            print(f"  {k}/{NFRAMES}", flush=True)
    proc.stdin.close()
    proc.wait()
    print("wrote", OUT)
    if "--silent" in sys.argv:
        silent = HERE / "talk-it-out-unsent-no-audio.mp4"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(OUT), "-an", "-c:v", "copy", str(silent)],
                       check=True)
        print("wrote", silent)


if __name__ == "__main__":
    main()
