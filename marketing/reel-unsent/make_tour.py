"""Talk It Out — feature tour (English, about 90 seconds, 1080x1920, 30 fps).

Reuses the drawing engine and sound instruments from make_reel.py.

    python3 make_tour.py                 # full render -> talk-it-out-feature-tour.mp4
    python3 make_tour.py --stills 12 30  # PNG stills at those seconds, for review

Every feature shown exists in the app (see API.md). The AI rewrite text is
real output from the project's model.
"""

from __future__ import annotations

import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import make_reel as R
from make_reel import (
    ACCENT_BORDER, ACCENT_SOFT, BORDER, CANVAS, INK, INK_FAINT, INK_SOFT, MUTED, WHITE,
    K, P, PH_H, PH_W, S, SCR_H, SCR_W, SS, W, H, FPS,
    circle_layer, clamp, comp, comp_centered, draw_text, ease_back, ease_in_out, ease_out,
    font, icon_check, icon_heart, icon_logo, icon_mask, icon_person, icon_send, icon_sparkle,
    icon_x, lerp, prog, rrect_layer, scaled, text_layer, window, wrap,
)

HERE = Path(__file__).resolve().parent
OUT = HERE / "talk-it-out-feature-tour.mp4"
DUR = 86.0
NFRAMES = int(DUR * FPS)
RED = (220, 38, 38)

AV_LEAD = None


def avatars():
    global AV_LEAD
    if AV_LEAD is None:
        AV_LEAD = {
            "lead": icon_person(P(30), MUTED + (255,), INK_SOFT + (255,)),
            "anon": icon_mask(P(30), INK + (255,), WHITE + (255,)),
            "me": icon_person(P(30), ACCENT_SOFT + (255,), INK + (255,)),
        }
    return AV_LEAD


# ─── small UI pieces (pt units) ───────────────────────────────────────────

def chip(img, x, y, label, filled=False, size=12, pad=12, alpha=1.0):
    fnt = font("SemiBold", P(size))
    w = fnt.getlength(label) / SS / K + pad * 2
    h = size + 14
    lay = rrect_layer(P(w), P(h), P(h / 2), (INK if filled else WHITE) + (255,), INK + (255,) if not filled else None, 1)
    draw_text(lay, label, "SemiBold", P(size), (P(w / 2), P(h / 2)), WHITE if filled else INK, anchor="mm")
    comp(img, lay, S(P(x)), S(P(y)), alpha)
    return w


def button(img, x, y, w, h, label, filled=True, k=1.0, alpha=1.0, size=15):
    lay = rrect_layer(P(w), P(h), P(12), (INK if filled else WHITE) + (255,), None if filled else INK + (255,), 1.2)
    draw_text(lay, label, "SemiBold", P(size), (P(w / 2), P(h / 2)), WHITE if filled else INK, anchor="mm")
    comp_centered(img, lay, P(x + w / 2), P(y + h / 2), alpha=alpha, k=k)


def card(img, x, y, w, h, fill=WHITE, border=BORDER, r=14, alpha=1.0):
    comp(img, rrect_layer(P(w), P(h), P(r), fill + (255,), border + (255,), 1), S(P(x)), S(P(y)), alpha)


def text_lines(img, lines, x, y, size=15, weight="Regular", color=INK, lh=None, alpha=1.0):
    lh = lh or size * 1.4
    for i, ln in enumerate(lines):
        draw_text(img, ln, weight, P(size), (P(x), P(y + i * lh)), color, alpha=alpha)


def big_title(img, title, subtitle=None):
    R.status_bar(img)
    draw_text(img, title, "ExtraBold", P(28), (P(20), P(48)), INK)
    if subtitle:
        draw_text(img, subtitle, "Regular", P(13), (P(20), P(86)), INK_SOFT)


def nav_bar(img, active=0, badge=None):
    y = 744
    ImageDraw.Draw(img).rectangle((0, S(P(y)), S(SCR_W), S(SCR_H)), fill=WHITE)
    ImageDraw.Draw(img).line([(0, S(P(y))), (S(SCR_W), S(P(y)))], fill=BORDER, width=S(1))
    labels = ["Groups", "Feed", "Alerts", "Profile"]
    for i, lb in enumerate(labels):
        cx = 49 + i * 97
        col = INK if i == active else INK_FAINT
        comp_centered(img, rrect_layer(P(20), P(18), P(5), None, col + (255,), 1.8), P(cx), P(y + 22))
        draw_text(img, lb, "SemiBold" if i == active else "Medium", P(11), (P(cx), P(y + 38)), col, anchor="mt")
        if badge and badge[0] == i:
            comp_centered(img, circle_layer(P(16), RED + (255,)), P(cx + 13), P(y + 14))
            draw_text(img, str(badge[1]), "Bold", P(9.5), (P(cx + 13), P(y + 14)), WHITE, anchor="mm")


def app_bar_back(img, title, subtitle):
    R.app_bar(img, title, subtitle)


def search_field(img, x, y, w, text, placeholder="Search", typing_cursor=False):
    card(img, x, y, w, 40, MUTED, BORDER, 12)
    comp(img, circle_layer(P(12), None, INK_SOFT + (255,), 1.6), S(P(x + 14)), S(P(y + 12)))
    ImageDraw.Draw(img).line([(S(P(x + 24)), S(P(y + 23))), (S(P(x + 29)), S(P(y + 28)))], fill=INK_SOFT, width=S(P(1.6)))
    if text:
        tw, _ = draw_text(img, text, "Regular", P(15), (P(x + 38), P(y + 11)), INK)
        if typing_cursor:
            comp(img, rrect_layer(P(1.6), P(18), 1, INK + (255,)), S(P(x + 40)) + S(tw), S(P(y + 11)))
    else:
        draw_text(img, placeholder, "Regular", P(15), (P(x + 38), P(y + 11)), INK_FAINT)


def typed(text, lt, a, b):
    return text[: int(len(text) * ease_in_out(prog(lt, a, b)))]


def pop(lt, at, dur=0.35):
    """(alpha, scale) for an element that pops in at `at`."""
    x = prog(lt, at, at + dur)
    return ease_out(x), lerp(0.88, 1.0, ease_back(x))


# ─── screens (each takes local time lt) ───────────────────────────────────

def scr_groups(lt):
    img = R.screen_base()
    big_title(img, "Groups")
    search_field(img, 20, 104, 350, "", "Search groups")
    a, k = pop(lt, 1.0, 0.45)
    y = 160
    if a > 0:
        lay = Image.new("RGBA", (S(P(350)), S(P(120))), (0, 0, 0, 0))
        comp(lay, rrect_layer(P(350), P(118), P(14), WHITE + (255,), INK + (255,), 1.4), 0, 0)
        draw_text(lay, "Design critique", "Bold", P(15), (P(16), P(14)), INK)
        draw_text(lay, "Rohan invited you · 5 members", "Regular", P(12.5), (P(16), P(36)), INK_SOFT)
        draw_text(lay, "You join only if you accept.", "Regular", P(12), (P(16), P(56)), INK_SOFT)
        button(lay, 16, 76, 150, 32, "Decline", filled=False, size=13)
        press = prog(lt, 4.3, 4.5)
        button(lay, 182, 76, 150, 32, "Accept", k=1 - 0.06 * math.sin(math.pi * press), size=13)
        comp(img, scaled(lay, k), S(P(20)), S(P(y)), a)
    rows = [
        ("Q3 launch plan", "Anonymous user: Can we add QA time…", "9:40", 3, True, None),
        ("Dashboard improvements", "2 messages waiting for your review", "9:12", 0, False, "CONTROLLER"),
        ("Making NLP notes", "Priya: Uploaded the dataset notes", "Tue", 1, False, None),
        ("Hiring loop", "Rahul: Panel moved to Thursday", "Mon", 0, False, None),
    ]
    shift = 132 * ease_out(prog(lt, 1.0, 1.45))
    for i, (name, last, when, unread, pinned, tag) in enumerate(rows):
        ry = 166 + shift + i * 72
        ra = ease_out(prog(lt, 0.15 + i * 0.12, 0.55 + i * 0.12))
        lay = Image.new("RGBA", (S(P(350)), S(P(66))), (0, 0, 0, 0))
        comp(lay, rrect_layer(P(46), P(46), P(12), INK + (255,)), 0, S(P(10)))
        draw_text(lay, name[0], "Bold", P(18), (P(23), P(33)), WHITE, anchor="mm")
        draw_text(lay, name, "SemiBold", P(15), (P(58), P(12)), INK)
        if tag:
            nw = font("SemiBold", P(15)).getlength(name) / SS / K
            tl = rrect_layer(P(78), P(18), P(4), INK + (255,))
            draw_text(tl, tag, "Bold", P(8.5), (P(39), P(9)), WHITE, anchor="mm")
            comp(lay, tl, S(P(64 + nw)), S(P(13)))
        draw_text(lay, last, "Regular", P(13), (P(58), P(34)), INK_SOFT)
        draw_text(lay, when, "Regular", P(12), (P(346), P(13)), INK_SOFT, anchor="rt")
        if unread:
            comp_centered(lay, circle_layer(P(20), INK + (255,)), P(336), P(43))
            draw_text(lay, str(unread), "Bold", P(11), (P(336), P(43)), WHITE, anchor="mm")
        if pinned:
            comp(lay, icon_sparkle(P(10), INK_SOFT + (255,)), S(P(306)), S(P(16)))
        comp(img, lay, S(P(20)), S(P(ry)), ra)
    nav_bar(img, 0, badge=(2, 4))
    return img


def scr_compose(lt):
    return R.composer_screen(8.6 + lt * (3.4 / 6.0))


def scr_review(lt):
    return R.review_screen(12.0 + lt * (6.0 / 9.0))


def scr_mine(lt):
    if lt < 2.4:
        return R.chat_screen(18.0 + lt * 1.2)
    img = R.screen_base()
    app_bar_back(img, "My messages", "Only you see this · status only")
    rows = [("Anonymous", "Accepted", "just now", True), ("Named", "Pending review", "2m ago", False),
            ("Anonymous", "Rejected", "yesterday", False), ("Named", "Accepted", "Mon", False)]
    for i, (kind, status, when, fresh) in enumerate(rows):
        a, k = pop(lt, 2.55 + i * 0.15)
        lay = Image.new("RGBA", (S(P(350)), S(P(64))), (0, 0, 0, 0))
        comp(lay, rrect_layer(P(350), P(60), P(14), (ACCENT_SOFT if fresh else WHITE) + (255,), BORDER + (255,), 1), 0, 0)
        comp(lay, (avatars()["anon"] if kind == "Anonymous" else avatars()["me"]), S(P(14)), S(P(15)))
        draw_text(lay, f"{kind} message", "SemiBold", P(14), (P(56), P(12)), INK)
        draw_text(lay, when, "Regular", P(12), (P(56), P(33)), INK_SOFT)
        filled = status == "Accepted"
        fnt = font("SemiBold", P(11.5))
        cw = fnt.getlength(status) / SS / K + 22
        cl = rrect_layer(P(cw), P(24), P(12), (INK if filled else WHITE) + (255,), None if filled else INK + (255,), 1)
        draw_text(cl, status, "SemiBold", P(11.5), (P(cw / 2), P(12)), WHITE if filled else INK, anchor="mm")
        comp(lay, cl, S(P(336 - cw)), S(P(18)))
        comp(img, scaled(lay, k), S(P(20)), S(P(118 + i * 72)), a)
    a = ease_out(prog(lt, 3.4, 3.8))
    text_lines(img, ["No message text, no rewrite and no reason", "are shown here, by design."],
               20, 418, 12.5, "Regular", INK_SOFT, alpha=a)
    return img


def photo_layer(w, h):
    lay = Image.new("RGBA", (S(P(w)), S(P(h))), (0, 0, 0, 255))
    d = ImageDraw.Draw(lay)
    for i in range(S(P(h))):
        c = int(lerp(232, 205, i / S(P(h))))
        d.line([(0, i), (S(P(w)), i)], fill=(c, c - 6, c - 16))
    d.rounded_rectangle((S(P(18)), S(P(16)), S(P(w - 18)), S(P(h - 30))), radius=S(P(6)), fill=(250, 250, 248),
                        outline=(180, 175, 165), width=S(P(2)))
    for j, ww in enumerate((150, 110, 170, 90)):
        d.line([(S(P(34)), S(P(36 + j * 18))), (S(P(34 + ww)), S(P(36 + j * 18)))], fill=(60, 60, 70), width=S(P(3)))
    d.rectangle((S(P(w - 90)), S(P(36)), S(P(w - 36)), S(P(80))), outline=(200, 60, 60), width=S(P(3)))
    m = Image.new("L", lay.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, lay.size[0] - 1, lay.size[1] - 1), radius=S(P(12)), fill=255)
    lay.putalpha(m)
    return lay


def scr_chat_features(lt):
    img = R.screen_base()
    content = Image.new("RGBA", (S(SCR_W), S(P(1180))), CANVAS + (255,))
    av = avatars()
    y = 110
    # Reply with a quote.
    lay = Image.new("RGBA", (S(P(360)), S(P(130))), (0, 0, 0, 0))
    comp(lay, av["me"], 0, S(P(92)))
    comp(lay, rrect_layer(P(306), P(124), P(16), WHITE + (255,), BORDER + (255,), 1), S(P(42)), 0)
    draw_text(lay, "Priya", "SemiBold", P(12), (P(56), P(10)), INK_SOFT)
    comp(lay, rrect_layer(P(278), P(46), P(8), MUTED + (255,)), S(P(56)), S(P(30)))
    comp(lay, rrect_layer(P(3), P(46), 1, INK + (255,)), S(P(56)), S(P(30)))
    draw_text(lay, "Anonymous user", "SemiBold", P(11), (P(66), P(35)), INK)
    draw_text(lay, "This plan is not clear and our sugg…", "Regular", P(12), (P(66), P(53)), INK_SOFT)
    draw_text(lay, "Agreed. Let's list priorities first.", "Regular", P(15), (P(56), P(88)), INK)
    comp(content, lay, S(P(14)), S(P(y)))
    # Reactions on it.
    for j, (kind, n) in enumerate((("heart", "5"), ("check", "3"))):
        a, k = pop(lt, 0.8 + j * 0.25)
        pill = rrect_layer(P(58), P(28), P(14), WHITE + (255,), BORDER + (255,), 1)
        ic = icon_heart(P(16), RED + (255,)) if kind == "heart" else icon_check(P(16), INK + (255,), P(2.4))
        comp(pill, ic, S(P(10)), S(P(6)))
        draw_text(pill, n, "SemiBold", P(13), (P(32), P(7)), INK)
        comp_centered(content, pill, P(70 + 29 + j * 66), P(y + 140), alpha=a, k=k)
    y = 280
    # Poll.
    card(content, 56, y, 306, 196)
    comp(content, av["lead"], S(P(14)), S(P(y + 160)))
    draw_text(content, "Rahul · Lead · POLL", "SemiBold", P(11), (P(70), P(y + 12)), INK_SOFT)
    draw_text(content, "Which day for the launch review?", "SemiBold", P(15), (P(70), P(y + 32)), INK)
    opts = [("Tuesday", 0.62), ("Wednesday", 0.28), ("Thursday", 0.10)]
    grow = ease_out(prog(lt, 2.0, 3.0))
    for j, (o, v) in enumerate(opts):
        oy = y + 62 + j * 40
        comp(content, rrect_layer(P(276), P(32), P(8), MUTED + (255,)), S(P(70)), S(P(oy)))
        if grow > 0:
            comp(content, rrect_layer(max(P(8), P(276 * v * grow)), P(32), P(8), ACCENT_BORDER + (255,)), S(P(70)), S(P(oy)))
        draw_text(content, o, "Medium", P(13), (P(82), P(oy + 8)), INK)
        draw_text(content, f"{int(v * 100 * grow)}%", "SemiBold", P(13), (P(334), P(oy + 8)), INK, anchor="rt")
    draw_text(content, "18 votes", "Regular", P(11.5), (P(70), P(y + 180)), INK_SOFT)
    y = 500
    # Photo with hidden details removed.
    comp(content, av["me"], S(P(14)), S(P(y + 196)))
    card(content, 56, y, 306, 226)
    draw_text(content, "Priya · photo", "SemiBold", P(11), (P(70), P(y + 12)), INK_SOFT)
    comp(content, photo_layer(278, 150), S(P(70)), S(P(y + 32)))
    a, k = pop(lt, 4.2, 0.4)
    badge = rrect_layer(P(256), P(26), P(13), INK + (255,))
    comp(badge, icon_check(P(14), WHITE + (255,), P(2.2)), S(P(10)), S(P(6)))
    draw_text(badge, "Location & camera details removed", "Medium", P(11), (P(28), P(6)), WHITE)
    comp_centered(content, badge, P(70 + 139), P(y + 198), alpha=a, k=k)
    # Scroll through the content.
    scroll = 340 * ease_in_out(prog(lt, 3.0, 4.0))
    view = content.crop((0, S(P(scroll)), S(SCR_W), S(P(scroll)) + S(P(640))))
    img.alpha_composite(view, (0, S(P(100))))
    # Pinned banner and app bar on top.
    R.app_bar(img, R.GROUP, "6 members")
    ImageDraw.Draw(img).rectangle((0, S(P(99)), S(SCR_W), S(P(135))), fill=ACCENT_SOFT)
    ImageDraw.Draw(img).line([(0, S(P(135))), (S(SCR_W), S(P(135)))], fill=ACCENT_BORDER, width=S(1))
    comp(img, icon_sparkle(P(12), INK + (255,)), S(P(18)), S(P(111)))
    draw_text(img, "Pinned · Launch checklist is due Friday", "Medium", P(12.5), (P(38), P(109)), INK)
    # Composer with an @mention.
    ImageDraw.Draw(img).rectangle((0, S(P(740)), S(SCR_W), S(SCR_H)), fill=WHITE)
    ImageDraw.Draw(img).line([(0, S(P(740))), (S(SCR_W), S(P(740)))], fill=BORDER, width=S(1))
    comp(img, rrect_layer(P(300), P(44), P(22), MUTED + (255,)), S(P(16)), S(P(752)))
    msg = typed("Thanks @pri", lt, 5.6, 6.6)
    if msg:
        tw, _ = draw_text(img, msg, "Regular", P(15), (P(32), P(764)), INK)
    else:
        draw_text(img, "Write a message…", "Regular", P(15), (P(32), P(764)), INK_FAINT)
    comp_centered(img, icon_send(P(44)), P(350), P(774))
    a, k = pop(lt, 6.4, 0.35)
    if a > 0:
        sug = Image.new("RGBA", (S(P(270)), S(P(110))), (0, 0, 0, 0))
        comp(sug, rrect_layer(P(270), P(108), P(14), WHITE + (255,), BORDER + (255,), 1), 0, 0)
        for j, (n, h) in enumerate((("Priya Sharma", "@priya"), ("Prithvi Rao", "@prithvi"))):
            comp(sug, avatars()["me"], S(P(12)), S(P(14 + j * 46)))
            draw_text(sug, n, "SemiBold", P(14), (P(52), P(14 + j * 46)), INK)
            draw_text(sug, h, "Regular", P(12), (P(52), P(32 + j * 46)), INK_SOFT)
        if lt > 7.2:
            comp(sug, rrect_layer(P(258), P(42), P(10), (ACCENT_SOFT[0], ACCENT_SOFT[1], ACCENT_SOFT[2], 160)),
                 S(P(6)), S(P(8)))
        comp(img, scaled(sug, k), S(P(20)), S(P(632)), a)
    return img


def scr_catchup(lt):
    img = R.screen_base()
    app_bar_back(img, R.GROUP, "6 members")
    draw_text(img, "Catch up", "ExtraBold", P(24), (P(20), P(116)), INK)
    draw_text(img, "Summary of the last 60 messages", "Regular", P(13), (P(20), P(148)), INK_SOFT)
    sections = [
        ("HIGHLIGHTS", ["Launch review moves to Tuesday.", "QA needs two more days in week 2.",
                        "Priya will share the checklist."]),
        ("OPEN QUESTIONS", ["Who owns the release notes?"]),
    ]
    y = 186
    step = 0
    for title, items in sections:
        a = ease_out(prog(lt, 0.4 + step * 0.35, 0.8 + step * 0.35))
        draw_text(img, title, "SemiBold", P(11), (P(20), P(y)), INK_SOFT, alpha=a)
        y += 24
        for it in items:
            step += 1
            a, k = pop(lt, 0.5 + step * 0.4)
            lay = Image.new("RGBA", (S(P(350)), S(P(46))), (0, 0, 0, 0))
            comp(lay, rrect_layer(P(350), P(42), P(12), WHITE + (255,), BORDER + (255,), 1), 0, 0)
            comp(lay, circle_layer(P(7), INK + (255,)), S(P(14)), S(P(18)))
            draw_text(lay, it, "Medium", P(14), (P(30), P(12)), INK)
            comp(img, scaled(lay, k), S(P(20)), S(P(y)), a)
            y += 50
        y += 12
    a = ease_out(prog(lt, 2.9, 3.3))
    draw_text(img, "KEY TOPICS", "SemiBold", P(11), (P(20), P(y)), INK_SOFT, alpha=a)
    x = 20
    for j, tp in enumerate(("launch", "QA", "checklist", "release notes")):
        x += chip(img, x, y + 22, tp, filled=j == 0, size=12, alpha=ease_out(prog(lt, 3.0 + j * 0.12, 3.4 + j * 0.12))) + 8
    a = ease_out(prog(lt, 3.6, 4.0))
    text_lines(img, ["Built only from approved messages.", "No names, no senders."], 20, y + 74, 12.5,
               "Regular", INK_SOFT, alpha=a)
    return img


def qr_layer(d, seed=3):
    n = 25
    rng = np.random.default_rng(seed)
    cells = rng.random((n, n)) > 0.52
    img = Image.new("RGBA", (S(P(d)), S(P(d))), WHITE + (255,))
    dr = ImageDraw.Draw(img)
    c = S(P(d)) / (n + 2)

    def finder(x, y):
        dr.rectangle((c * (x + 1), c * (y + 1), c * (x + 8), c * (y + 8)), fill=INK)
        dr.rectangle((c * (x + 2), c * (y + 2), c * (x + 7), c * (y + 7)), fill=WHITE)
        dr.rectangle((c * (x + 3), c * (y + 3), c * (x + 6), c * (y + 6)), fill=INK)

    for i in range(n):
        for j in range(n):
            inside = (i < 8 and j < 8) or (i < 8 and j >= n - 8) or (i >= n - 8 and j < 8)
            if cells[i, j] and not inside:
                dr.rectangle((c * (j + 1), c * (i + 1), c * (j + 2), c * (i + 2)), fill=INK)
    finder(0, 0)
    finder(n - 7, 0)
    finder(0, n - 7)
    return img


def scr_invite(lt):
    img = R.screen_base()
    R.status_bar(img)
    if lt < 3.9:
        draw_text(img, "Invite members", "Bold", P(18), (P(195), P(56)), INK, anchor="mt")
        q = typed("anitta", lt, 0.3, 1.0)
        search_field(img, 20, 94, 350, q, "Search name or @handle", typing_cursor=lt < 1.2)
        if lt > 1.15:
            a = ease_out(prog(lt, 1.15, 1.45))
            comp(img, icon_sparkle(P(12), INK_SOFT + (255,)), S(P(22)), S(P(149)))
            draw_text(img, "No exact match. Showing names that look or sound similar.", "Regular", P(11.5),
                      (P(40), P(148)), INK_SOFT, alpha=a)
            people = [("Anita Sharma", "@anita · In 2 of your groups", False),
                      ("Ankita Rao", "@ankita", False), ("Kabir Mehta", "@kabir · Invited", True)]
            for j, (n, sub, invited) in enumerate(people):
                a, k = pop(lt, 1.35 + j * 0.12)
                py = 180 + j * 64
                lay = Image.new("RGBA", (S(P(350)), S(P(56))), (0, 0, 0, 0))
                comp(lay, avatars()["me"], S(P(4)), S(P(12)))
                draw_text(lay, n, "SemiBold", P(15), (P(48), P(10)), INK)
                draw_text(lay, sub, "Regular", P(12.5), (P(48), P(31)), INK_SOFT)
                if invited:
                    cl = rrect_layer(P(64), P(24), P(12), MUTED + (255,))
                    draw_text(cl, "Invited", "SemiBold", P(11), (P(32), P(12)), INK_SOFT, anchor="mm")
                    comp(lay, cl, S(P(280)), S(P(16)))
                else:
                    sel = j == 0 and lt > 2.1
                    comp(lay, circle_layer(P(24), (INK if sel else WHITE) + (255,), (INK if sel else INK_FAINT) + (255,),
                                           1.6), S(P(316)), S(P(16)))
                    if sel:
                        comp(lay, icon_check(P(24), WHITE + (255,), P(2.6)), S(P(316)), S(P(16)))
                comp(img, scaled(lay, k), S(P(20)), S(P(py)), a)
            if lt > 2.1:
                press = prog(lt, 2.9, 3.1)
                button(img, 236, 46, 134, 34, "Invite (1)", k=1 - 0.06 * math.sin(math.pi * press), size=13)
        if lt > 3.15:
            a = window(lt, 3.15, 3.9, 0.2)
            lay = rrect_layer(P(300), P(40), P(20), INK + (255,))
            draw_text(lay, "Invitation sent. Anita joins after accepting.", "Medium", P(12), (P(150), P(20)), WHITE,
                      anchor="mm")
            comp(img, lay, S(P(45)), S(P(690)), a)
    else:
        a = ease_out(prog(lt, 3.9, 4.3))
        draw_text(img, "Invite people", "Bold", P(22), (P(195), P(60)), INK, anchor="mt", alpha=a)
        text_lines(img, ["Anyone with the link joins as a contributor.", "You still review every message."],
                   48, 98, 12.5, "Regular", INK_SOFT, alpha=a)
        qa, qk = pop(lt, 4.2, 0.5)
        card(img, 85, 150, 220, 220, WHITE, BORDER, 18, alpha=qa)
        comp_centered(img, qr_layer(196), P(195), P(260), alpha=qa, k=qk)
        comp_centered(img, icon_logo(P(40)), P(195), P(260), alpha=qa, k=qk)
        la = ease_out(prog(lt, 4.6, 5.0))
        card(img, 20, 392, 350, 48, MUTED, BORDER, 12, alpha=la)
        draw_text(img, "talkitout.app/join/7KQ2-M9", "Medium", P(14), (P(36), P(407)), INK, alpha=la)
        draw_text(img, "Link works for 7 days", "Regular", P(12), (P(195), P(452)), INK_SOFT, anchor="mt", alpha=la)
        press = prog(lt, 5.6, 5.8)
        button(img, 20, 484, 170, 46, "Copy link", filled=False, alpha=la, k=1 - 0.05 * math.sin(math.pi * press))
        button(img, 200, 484, 170, 46, "Share", alpha=la)
        if lt > 5.8:
            a = window(lt, 5.8, 7.0, 0.2)
            lay = rrect_layer(P(170), P(40), P(20), INK + (255,))
            draw_text(lay, "Invite link copied.", "Medium", P(12.5), (P(85), P(20)), WHITE, anchor="mm")
            comp(img, lay, S(P(110)), S(P(690)), a)
    return img


def scr_feed(lt):
    img = R.screen_base()
    big_title(img, "Feed")
    # Tabs.
    for j, t in enumerate(("For You", "Latest", "Following")):
        x = 20 + j * 96
        on = j == 0
        draw_text(img, t, "SemiBold" if on else "Medium", P(14), (P(x), P(98)), INK if on else INK_SOFT)
        if on:
            comp(img, rrect_layer(P(56), P(3), P(1.5), INK + (255,)), S(P(x)), S(P(120)))
    x = 20
    for j, tp in enumerate(("Leadership", "Remote work", "Engineering")):
        x += chip(img, x, 134, tp, filled=False, size=12, alpha=ease_out(prog(lt, 0.2 + j * 0.1, 0.6 + j * 0.1))) + 8
    # Question.
    a, k = pop(lt, 0.4, 0.45)
    q = Image.new("RGBA", (S(P(350)), S(P(176))), (0, 0, 0, 0))
    comp(q, rrect_layer(P(350), P(172), P(16), WHITE + (255,), BORDER + (255,), 1), 0, 0)
    comp(q, avatars()["me"], S(P(14)), S(P(14)))
    draw_text(q, "Meera K.", "SemiBold", P(13.5), (P(52), P(14)), INK)
    draw_text(q, "Leadership · 2h", "Regular", P(11.5), (P(52), P(31)), INK_SOFT)
    text_lines(q, ["How do you give feedback to a senior", "without sounding rude?"], 14, 58, 16, "SemiBold", INK, 22)
    comp(q, icon_heart(P(16), RED + (255,)), S(P(14)), S(P(118)))
    draw_text(q, "48", "SemiBold", P(13), (P(36), P(119)), INK)
    draw_text(q, "12 answers", "Medium", P(13), (P(76), P(119)), INK_SOFT)
    following = lt > 2.2
    press = prog(lt, 2.0, 2.2)
    fl = rrect_layer(P(96), P(30), P(15), (INK if following else WHITE) + (255,), None if following else INK + (255,), 1.2)
    draw_text(fl, "Following" if following else "Follow", "SemiBold", P(12.5), (P(48), P(15)), WHITE if following else INK,
              anchor="mm")
    comp_centered(q, fl, P(290), P(126), k=1 - 0.06 * math.sin(math.pi * press))
    comp(q, rrect_layer(P(322), P(1), 0, BORDER + (255,)), S(P(14)), S(P(150)))
    draw_text(q, "Why you're seeing this: you follow Leadership", "Regular", P(10.5), (P(14), P(156)), INK_FAINT)
    comp(img, scaled(q, k), S(P(20)), S(P(178)), a)
    # Best answer with upvotes.
    a, k = pop(lt, 2.7, 0.45)
    if a > 0:
        an = Image.new("RGBA", (S(P(350)), S(P(170))), (0, 0, 0, 0))
        comp(an, rrect_layer(P(350), P(166), P(16), ACCENT_SOFT + (255,), ACCENT_BORDER + (255,), 1.2), 0, 0)
        best = lt > 4.0
        if best:
            bk = ease_back(prog(lt, 4.0, 4.35))
            bl = rrect_layer(P(108), P(24), P(12), INK + (255,))
            comp(bl, icon_check(P(14), WHITE + (255,), P(2.2)), S(P(10)), S(P(5)))
            draw_text(bl, "Best answer", "SemiBold", P(11.5), (P(28), P(5)), WHITE)
            comp_centered(an, bl, P(14 + 54), P(26), k=max(0.01, bk))
        else:
            draw_text(an, "TOP ANSWER", "SemiBold", P(11), (P(14), P(18)), INK_SOFT)
        text_lines(an, ["Lead with the shared goal, describe one", "specific moment, then ask what they",
                        "think. Keep it to the work, not the person."], 14, 48, 14.5, "Regular", INK, 20)
        votes = 41 + (1 if lt > 3.4 else 0)
        press = prog(lt, 3.2, 3.4)
        up = rrect_layer(P(74), P(30), P(15), (INK if lt > 3.4 else WHITE) + (255,), None if lt > 3.4 else INK + (255,), 1.2)
        draw_text(up, f"▲ {votes}", "SemiBold", P(13), (P(37), P(15)), WHITE if lt > 3.4 else INK, anchor="mm")
        comp_centered(an, up, P(14 + 37), P(130 + 15), k=1 - 0.08 * math.sin(math.pi * press))
        draw_text(an, "Rohan · Upvoted by 41 people", "Regular", P(11.5), (P(98), P(138)), INK_SOFT)
        comp(img, scaled(an, k), S(P(20)), S(P(370)), a)
    nav_bar(img, 1)
    return img


def scr_alerts(lt):
    img = R.screen_base()
    big_title(img, "Alerts", "5 new")
    rows = [
        ("review", "Review requested", "A message in Dashboard improvements is waiting for your review."),
        ("invite", "Group invitation", "Rohan invited you to Design critique."),
        ("answer", "New answer", "Meera answered the question you follow."),
        ("best", "Best answer", "Your answer was marked best."),
        ("mention", "Mentioned", "Priya mentioned you in Q3 launch plan."),
    ]
    for i, (kind, title, body) in enumerate(rows):
        a, k = pop(lt, 0.25 + i * 0.28)
        lay = Image.new("RGBA", (S(P(350)), S(P(84))), (0, 0, 0, 0))
        comp(lay, rrect_layer(P(350), P(80), P(14), WHITE + (255,), BORDER + (255,), 1), 0, 0)
        comp(lay, circle_layer(P(34), MUTED + (255,)), S(P(12)), S(P(14)))
        ic = {"review": icon_sparkle(P(16), INK + (255,)), "invite": icon_person(P(20), MUTED + (255,), INK + (255,)),
              "answer": icon_heart(P(16), INK + (255,)), "best": icon_check(P(18), INK + (255,), P(2.4)),
              "mention": icon_mask(P(20), MUTED + (255,), INK + (255,))}[kind]
        comp(lay, ic, S(P(29)) - ic.size[0] // 2, S(P(31)) - ic.size[1] // 2)
        draw_text(lay, title.upper(), "SemiBold", P(10.5), (P(58), P(13)), INK_SOFT)
        text_lines(lay, wrap(body, "Regular", P(13.5), P(276))[:2], 58, 31, 13.5, "Regular", INK, 19)
        comp_centered(lay, circle_layer(P(8), INK + (255,)), P(336), P(18))
        comp(img, scaled(lay, k), S(P(20)), S(P(110 + i * 90)), a)
    nav_bar(img, 2, badge=(2, 5))
    return img


def scr_safety(lt):
    img = R.screen_base()
    R.status_bar(img)
    comp(img, rrect_layer(P(390), P(120), 0, ACCENT_SOFT + (255,)), 0, S(P(40)))
    comp_centered(img, icon_person(P(84), INK + (255,), WHITE + (255,)), P(70), P(160))
    draw_text(img, "Kabir Mehta", "Bold", P(20), (P(20), P(212)), INK)
    draw_text(img, "@kabir · Engineering", "Regular", P(13), (P(20), P(240)), INK_SOFT)
    button(img, 20, 270, 170, 40, "Invite to group", size=13)
    button(img, 200, 270, 170, 40, "Message", filled=False, size=13)
    # Menu sheet.
    sh = ease_out(prog(lt, 0.8, 1.25))
    if sh > 0:
        dim = Image.new("RGBA", (S(SCR_W), S(SCR_H)), (0, 0, 0, int(90 * sh)))
        img.alpha_composite(dim)
        sheet = Image.new("RGBA", (S(SCR_W), S(P(320))), (0, 0, 0, 0))
        comp(sheet, rrect_layer(390 * K, P(340), P(22), WHITE + (255,)), 0, 0)
        comp(sheet, rrect_layer(P(40), P(5), P(3), BORDER + (255,)), S(P(175)), S(P(10)))
        items = [("Block Kabir", "They can't find you, message you or see your questions."),
                 ("Report question", "Five reports hide it from everyone."),
                 ("Cancel", "")]
        for j, (t1, t2) in enumerate(items):
            iy = 34 + j * 78
            hl = j == 0 and lt > 2.0
            if hl:
                comp(sheet, rrect_layer(P(358), P(66), P(12), MUTED + (255,)), S(P(16)), S(P(iy - 6)))
            col = RED if j < 2 else INK
            draw_text(sheet, t1, "SemiBold", P(16), (P(30), P(iy + 4)), col)
            if t2:
                draw_text(sheet, t2, "Regular", P(12), (P(30), P(iy + 28)), INK_SOFT)
        comp(img, sheet, 0, S(SCR_H) - sheet.size[1] * sh)
    if lt > 2.7:
        a = window(lt, 2.7, 4.6, 0.2)
        lay = rrect_layer(P(300), P(40), P(20), INK + (255,))
        draw_text(lay, "Blocked. Kabir won't see you anymore.", "Medium", P(12.5), (P(150), P(20)), WHITE, anchor="mm")
        comp(img, lay, S(P(45)), S(P(96)), a)
    return img


def scr_signin(lt):
    img = R.screen_base()
    R.status_bar(img)
    if lt < 2.6:
        comp_centered(img, icon_logo(P(52)), P(195), P(98))
        draw_text(img, "Talk It Out", "Bold", P(22), (P(195), P(134)), INK, anchor="mt")
        draw_text(img, "Thoughtful conversations, refined together.", "Regular", P(12.5), (P(195), P(166)), INK_SOFT,
                  anchor="mt")
        card(img, 30, 206, 330, 46, WHITE, BORDER, 12)
        draw_text(img, "you@company.com", "Regular", P(14), (P(46), P(221)), INK_FAINT)
        card(img, 30, 262, 330, 46, WHITE, BORDER, 12)
        draw_text(img, "Password", "Regular", P(14), (P(46), P(277)), INK_FAINT)
        draw_text(img, "Forgot?", "SemiBold", P(13), (P(360), P(322)), INK, anchor="rt")
        button(img, 30, 350, 330, 48, "Sign in")
        draw_text(img, "or", "Regular", P(12), (P(195), P(414)), INK_SOFT, anchor="mt")
        press = prog(lt, 1.3, 1.5)
        g = rrect_layer(P(330), P(48), P(12), WHITE + (255,), BORDER + (255,), 1.2)
        comp(g, circle_layer(P(24), WHITE + (255,), INK_SOFT + (255,), 1.4), S(P(78)), S(P(12)))
        draw_text(g, "G", "Bold", P(13), (P(90), P(24)), INK, anchor="mm")
        draw_text(g, "Continue with Google", "SemiBold", P(15), (P(178), P(24)), INK, anchor="mm")
        comp_centered(img, g, P(195), P(462), k=1 - 0.05 * math.sin(math.pi * press))
        draw_text(img, "Create an account", "SemiBold", P(14), (P(195), P(510)), INK, anchor="mt")
    else:
        lt2 = lt - 2.6
        for j in range(3):
            comp(img, rrect_layer(P(40), P(4), P(2), (INK if j <= 1 else BORDER) + (255,)), S(P(131 + j * 44)), S(P(64)))
        draw_text(img, "STEP 2 OF 3", "SemiBold", P(10.5), (P(195), P(78)), INK_SOFT, anchor="mt")
        draw_text(img, "Enter your code", "Bold", P(22), (P(195), P(104)), INK, anchor="mt")
        draw_text(img, "We emailed a 6-digit code to you@company.com", "Regular", P(12.5), (P(195), P(138)),
                  INK_SOFT, anchor="mt")
        digits = "482917"
        n = int(6 * ease_in_out(prog(lt2, 0.2, 1.3)) + 0.0001)
        for j in range(6):
            x = 36 + j * 54
            filled = j < n
            card(img, x, 178, 46, 56, WHITE, INK if j == n else BORDER, 10)
            if filled:
                draw_text(img, digits[j], "Bold", P(22), (P(x + 23), P(206)), INK, anchor="mm")
        ok = lt2 > 1.6
        button(img, 30, 258, 330, 48, "Verified  ✓" if ok else "Continue", k=1 - 0.05 * math.sin(math.pi * prog(lt2, 1.4, 1.6)))
        a = ease_out(prog(lt2, 1.8, 2.2))
        text_lines(img, ["Codes expire in 15 minutes and work once."], 30, 324, 12.5, "Regular", INK_SOFT, alpha=a)
    return img


# ─── scenes ───────────────────────────────────────────────────────────────

# (start, end, chapter, title, subtitle, screen, camera keys [(lt, zoom, focus_pt)], sounds [(lt, kind)])
SCENES = [
    (10.0, 16.0, "01  GROUPS", "Your team, in one place.",
     "Pinned groups, unread counts, and invitations you choose to accept.", scr_groups,
     [(0, 1.0, 404), (3.6, 1.0, 404), (4.2, 1.3, 230), (5.7, 1.3, 230), (6.0, 1.0, 404)],
     [(1.0, "pop"), (4.4, "tap")]),
    (16.0, 22.0, "02  ANONYMOUS MESSAGES", "Say it anonymously.",
     "Hidden from the group. Visible only to the group's controller.", scr_compose,
     [(0, 1.0, 404), (0.6, 1.42, 705), (5.6, 1.42, 705), (6.0, 1.0, 404)],
     [(3.65, "tick"), (4.7, "tap")]),
    (22.0, 31.0, "03  AI REWRITE + REVIEW", "AI fixes the tone.",
     "Never the meaning. Facts, numbers and questions stay.", scr_review,
     [(0, 1.0, 404), (0.7, 1.42, 400), (6.6, 1.42, 400), (7.1, 1.3, 640), (8.7, 1.3, 640), (9.0, 1.0, 404)],
     [(1.6, "shimmer"), (3.6, "tick"), (7.5, "tap")]),
    (31.0, 36.0, "04  SHARED WHEN READY", "Only the kind version is shared.",
     "Track your own messages privately: status only.", scr_mine,
     [(0, 1.0, 404), (0.4, 1.3, 430), (2.2, 1.3, 430), (2.5, 1.0, 404), (3.0, 1.25, 260), (4.7, 1.25, 260),
      (5.0, 1.0, 404)],
     [(0.05, "pop"), (2.55, "pop")]),
    (36.0, 44.5, "05  GROUP CHAT", "A real group chat.",
     "Replies, reactions, polls, pins, photos and @mentions.", scr_chat_features,
     [(0, 1.0, 404), (0.5, 1.3, 260), (1.8, 1.3, 260), (2.2, 1.3, 420), (2.9, 1.3, 420), (3.6, 1.3, 470),
      (5.2, 1.3, 470), (5.6, 1.35, 700), (8.2, 1.35, 700), (8.5, 1.0, 404)],
     [(0.8, "pop"), (1.05, "pop"), (2.0, "shimmer"), (4.2, "pop"), (6.4, "pop"), (7.2, "tick")]),
    (44.5, 49.5, "06  CATCH UP", "Missed the discussion?",
     "Highlights, open questions and key topics in seconds.", scr_catchup,
     [(0, 1.0, 404), (0.5, 1.25, 330), (4.6, 1.25, 330), (5.0, 1.0, 404)],
     [(0.9, "pop"), (1.3, "pop"), (1.7, "pop"), (2.1, "pop")]),
    (49.5, 57.0, "07  INVITE YOUR TEAM", "Bring the right people in.",
     "Find teammates by name or @handle, typos and all. Or share a link.", scr_invite,
     [(0, 1.0, 404), (0.4, 1.3, 260), (3.7, 1.3, 260), (4.0, 1.0, 404), (4.4, 1.25, 330), (7.2, 1.25, 330),
      (7.5, 1.0, 404)],
     [(2.1, "tick"), (3.0, "tap"), (4.2, "pop"), (5.7, "tap")]),
    (57.0, 64.5, "08  COMMUNITY FEED", "Ask the wider community.",
     "Questions, upvoted answers, best answers and a For You feed.", scr_feed,
     [(0, 1.0, 404), (0.6, 1.25, 290), (2.4, 1.25, 290), (2.9, 1.3, 450), (7.2, 1.3, 450), (7.5, 1.0, 404)],
     [(0.4, "pop"), (2.1, "tap"), (2.7, "pop"), (3.3, "tap"), (4.0, "tick")]),
    (64.5, 69.0, "09  NOTIFICATIONS", "Never miss what matters.",
     "Reviews, invitations, answers and mentions.", scr_alerts,
     [(0, 1.0, 404), (0.3, 1.2, 330), (4.2, 1.2, 330), (4.5, 1.0, 404)],
     [(0.25, "pop"), (0.53, "pop"), (0.81, "pop"), (1.09, "pop"), (1.37, "pop")]),
    (69.0, 74.0, "10  SAFETY", "Safe by design.",
     "Block or report anyone. Contributors never see each other's original words.", scr_safety,
     [(0, 1.0, 404), (1.2, 1.2, 560), (4.6, 1.2, 560), (5.0, 1.0, 404)],
     [(0.8, "whoosh"), (2.0, "tap")]),
    (74.0, 79.5, "11  EASY SIGN-IN", "Start in seconds.",
     "Sign in with Google or email. Forgot your password? Reset with a code.", scr_signin,
     [(0, 1.0, 404), (0.3, 1.25, 330), (2.3, 1.25, 330), (2.6, 1.0, 404), (2.9, 1.3, 220), (5.2, 1.3, 220),
      (5.5, 1.0, 404)],
     [(1.4, "tap"), (4.2, "tick")]),
]
PHONE_IN, PHONE_OUT = 10.0, 79.5


def scene_at(t):
    for sc in SCENES:
        if sc[0] <= t < sc[1]:
            return sc
    return None


def camera_local(keys, lt):
    if lt <= keys[0][0]:
        return keys[0][1], keys[0][2]
    for (t0, z0, f0), (t1, z1, f1) in zip(keys, keys[1:]):
        if t0 <= lt <= t1:
            x = ease_in_out(prog(lt, t0, t1))
            return lerp(z0, z1, x), lerp(f0, f1, x)
    return keys[-1][1], keys[-1][2]


def fit_size(txt, weight, size, width):
    while font(weight, size).getlength(txt) / SS > width and size > 30:
        size -= 2
    return size


def scene_caption(frame, sc, t):
    start, end, chapter, title, sub = sc[:5]
    a = R.window(t, start, end, 0.3)
    if a <= 0:
        return
    l1 = ease_out(prog(t, start + 0.05, start + 0.45))
    l2 = ease_out(prog(t, start + 0.15, start + 0.55))
    l3 = ease_out(prog(t, start + 0.25, start + 0.65))
    draw_text(frame, chapter, "SemiBold", 24, (W / 2, 232), INK_SOFT, alpha=a * l1, anchor="mt", dy=(1 - l1) * 16)
    size = fit_size(title, "ExtraBold", 58, 940)
    draw_text(frame, title, "ExtraBold", size, (W / 2, 272), INK, alpha=a * l2, anchor="mt", dy=(1 - l2) * 22)
    for i, ln in enumerate(wrap(sub, "Regular", 32, 900)[:2]):
        draw_text(frame, ln, "Regular", 32, (W / 2, 350 + i * 42), INK_SOFT, alpha=a * l3, anchor="mt",
                  dy=(1 - l3) * 22)


FOCUS_Y = 1110
BAND = None


def band():
    global BAND
    if BAND is None:
        hh = 560
        ys = np.arange(S(hh)) / SS
        a = np.where(ys < 450, 1.0, np.clip(1 - (ys - 450) / 100, 0, 1)) * 0.97
        alpha = Image.fromarray((a[:, None] * 255).astype(np.uint8), "L").resize((S(W), S(hh)))
        BAND = Image.new("RGBA", (S(W), S(hh)), CANVAS + (255,))
        BAND.putalpha(alpha)
    return BAND


def render(t: float, k: int) -> Image.Image:
    if R.DARK_BG is None:
        R.DARK_BG, R.LIGHT_BG = R.make_dark_bg(), R.make_light_bg()

    if t < 6.6:
        # The opening: the unsent message (English).
        frame = R.DARK_BG.copy()
        hook_a = 1 - ease_in_out(prog(t, 4.2, 4.5))
        if t < 2.7:
            R.caption(frame, ["We've all typed", "this message."], t, 0.1, 2.7, y=520, size=64, color=WHITE)
        elif t < 4.5:
            R.caption(frame, ["…and then", "deleted it."], t, 2.7, 4.45, y=520, size=64, color=WHITE)
        if hook_a > 0:
            field = rrect_layer(900, 230, 46, (28, 28, 32, 255), (63, 63, 70, 255), 1.5)
            n = int(len(R.ORIGINAL) * (ease_in_out(prog(t, 0.3, 2.0)) if t < 2.7 else 1 - prog(t, 2.75, 3.9)))
            lines = wrap(R.ORIGINAL[:n], "Medium", 46, 700) if n else []
            for i, ln in enumerate(lines[:3]):
                draw_text(field, ln, "Medium", 46, (44, 40 + i * 60), WHITE)
            last = lines[-1] if lines else ""
            cx = 44 + (font("Medium", 46).getlength(last) / SS if last else 0) + 6
            if int(t * 2.2) % 2 == 0 or 0.3 < t < 3.9:
                comp(field, rrect_layer(4, 54, 2, WHITE + (230,)), S(cx), S(40 + max(0, len(lines) - 1) * 60))
            comp(frame, field, S(90), S(900), hook_a)
            pulse = 1 + 0.07 * math.sin(math.pi * prog(t, 2.0, 2.6))
            comp_centered(frame, icon_send(120, WHITE, INK), 870, 1210, alpha=hook_a, k=pulse)
            draw_text(frame, "Send", "Medium", 30, (870, 1290), INK_FAINT, alpha=hook_a * 0.9, anchor="mt")
        if t >= 4.5:
            a = ease_out(prog(t, 4.55, 5.1))
            draw_text(frame, "Because being honest", "Bold", 80, (W / 2, 830), WHITE, alpha=a, anchor="mt",
                      dy=(1 - a) * 30)
            word = text_layer("risky.", font("ExtraBold", 80), INK)[0]
            pre = text_layer("at work feels ", font("Bold", 80), WHITE)[0]
            hi = ease_out(prog(t, 5.15, 5.5))
            tot = pre.size[0] + word.size[0] + S(28)
            x0 = S(W / 2) - tot / 2
            y0 = S(945) + (1 - a) * S(30)
            comp(frame, pre, x0, y0, a)
            box = Image.new("RGBA", (int((word.size[0] + S(28)) * max(0.01, hi)), word.size[1] + S(26)),
                            ACCENT_SOFT + (255,))
            comp(frame, box, x0 + pre.size[0], y0 - S(13), a)
            comp(frame, word, x0 + pre.size[0] + S(14), y0, a)
        if t >= 6.3:
            r = ease_in_out(prog(t, 6.3, 6.6))
            mask = Image.new("L", (S(W), S(H)), 0)
            rad = S(r * 1200)
            ImageDraw.Draw(mask).ellipse((S(W / 2) - rad, S(H / 2) - rad, S(W / 2) + rad, S(H / 2) + rad), fill=255)
            frame = Image.composite(R.LIGHT_BG, frame, mask)
        grain = 5.0
    else:
        frame = R.LIGHT_BG.copy()
        grain = 2.5
        # Intro card.
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
        # Phone tour.
        if PHONE_IN <= t < PHONE_OUT + 0.4:
            sc = scene_at(min(t, PHONE_OUT - 0.001))
            lt = t - sc[0]
            scr = sc[5](lt)
            # Slide between scenes.
            idx = SCENES.index(sc)
            if idx > 0 and lt < 0.35:
                prev = SCENES[idx - 1]
                pscr = prev[5](prev[1] - prev[0] - 0.01)
                x = ease_in_out(prog(lt, 0, 0.35))
                mix = Image.new("RGBA", scr.size, CANVAS + (255,))
                mix.alpha_composite(pscr, (int(-x * scr.size[0] * 0.35), 0))
                mix.alpha_composite(R.with_alpha(scr, x), (int((1 - x) * scr.size[0] * 0.25), 0))
                scr = mix
            phone = R.phone_layer(scr)
            enter = ease_out(prog(t, PHONE_IN, PHONE_IN + 0.7))
            leave = ease_in_out(prog(t, PHONE_OUT - 0.1, PHONE_OUT + 0.35))
            zoom, focus = camera_local(sc[6], lt)
            off = focus * K + (PH_H - SCR_H) / 2 - PH_H / 2
            w_ = clamp((zoom - 1) / 0.25)
            base_cy = 500 + PH_H / 2
            cy = lerp(base_cy, FOCUS_Y - off * zoom, w_) + (1 - enter) * 600 + leave * 700
            sh = scaled(R.phone_shadow(), zoom)
            vis = enter * (1 - leave)
            comp(frame, sh, S(W / 2) - sh.size[0] / 2, S(cy) - sh.size[1] / 2, vis)
            comp_centered(frame, phone, W / 2, cy, alpha=vis, k=zoom)
            comp(frame, band(), 0, 0, vis)
            scene_caption(frame, sc, t)
            # Chapter progress dots.
            for j in range(len(SCENES)):
                on = j == idx
                dot = rrect_layer(30 if on else 10, 10, 5, (INK if on else (214, 208, 198)) + (255,))
                x = W / 2 - (len(SCENES) * 18 + 20) / 2 + j * 18 + (20 if j > idx else 0)
                comp(frame, dot, S(x), S(196), vis)
        # Outro.
        if t >= 79.7:
            li = ease_back(prog(t, 79.8, 80.3))
            comp_centered(frame, icon_logo(190), W / 2, 700, alpha=clamp(li * 1.2), k=max(0.01, 0.6 + 0.4 * li))
            a1 = ease_out(prog(t, 80.1, 80.6))
            draw_text(frame, "Talk It Out", "ExtraBold", 108, (W / 2, 840), INK, alpha=a1, anchor="mt", dy=(1 - a1) * 24)
            a2 = ease_out(prog(t, 80.5, 81.0))
            draw_text(frame, "Speak up. Stay kind.", "Regular", 54, (W / 2, 985), INK_SOFT, alpha=a2, anchor="mt",
                      dy=(1 - a2) * 20)
            a3 = ease_back(prog(t, 81.2, 81.6))
            if a3 > 0:
                pill = rrect_layer(420, 96, 48, INK + (255,))
                draw_text(pill, "Try it — link in bio", "SemiBold", 36, (210, 48), WHITE, anchor="mm")
                comp_centered(frame, pill, W / 2, 1150, alpha=clamp(a3), k=max(0.01, 0.8 + 0.2 * a3))
            a4 = ease_out(prog(t, 81.8, 82.3))
            feats = "Anonymous messages · AI tone rewrite · Controller review · Community feed"
            for i, ln in enumerate(wrap(feats, "Medium", 28, 860)):
                draw_text(frame, ln, "Medium", 28, (W / 2, 1270 + i * 40), INK, alpha=a4, anchor="mt")
            a5 = ease_out(prog(t, 82.4, 82.9))
            for i, ln in enumerate(["Anonymous messages are hidden from the group",
                                    "but visible to the group's controller."]):
                draw_text(frame, ln, "Regular", 26, (W / 2, 1390 + i * 36), INK_SOFT, alpha=a5 * 0.9, anchor="mt")

    out = frame.convert("RGB").reduce(SS)
    return R.add_grain(out, k, grain)


# ─── soundtrack ───────────────────────────────────────────────────────────

GROOVE_END, SOFT_A, SOFT_B, OUTRO_AT = 79.4, 44.5, 49.5, 79.7


def build_audio() -> np.ndarray:
    sh = OUTRO_AT - 79.7  # shift for the outro
    SR = R.SR
    total = int(DUR * SR) + SR
    music = np.zeros(total)
    sfx = np.zeros(total)

    def add(buf, sig, at, gain=1.0):
        i = int(at * SR)
        if i >= total:
            return
        j = min(total, i + len(sig))
        buf[i:j] += gain * sig[: j - i]

    nf = R.note_freq
    # Opening tension.
    for i in range(13):
        add(sfx, R.click(0.22 if i % 2 else 0.3), 0.05 + i * 0.5)
    for i in range(len(R.ORIGINAL)):
        if R.ORIGINAL[i] != " ":
            add(sfx, R.click(0.12), 0.3 + 1.7 * ease_in_out(i / len(R.ORIGINAL)))
    for i in range(28):
        add(sfx, R.click(0.1), 2.75 + i * (1.15 / 28))
    b = 1.2
    while b < 4.5:
        add(music, R.heartbeat(), b)
        add(music, R.heartbeat(), b + 0.22, 0.6)
        b += 0.86
    add(music, R.boom(), 4.5)
    add(sfx, R.whoosh(0.5, 0.25), 6.1)

    # Intro: piano opens (6.6 - 10).
    for at, chord in [(6.6, ["C3", "G3", "E4"]), (8.3, ["A2", "E3", "C4"])]:
        for j, nn in enumerate(chord):
            add(music, R.piano(nf(nn), 3.2, 0.32), at + j * 0.09)
        add(music, R.pad([nf(nn) for nn in chord], 2.4, 0.05), at)
    for at, nn in [(7.4, "G4"), (8.0, "E4"), (9.1, "C5")]:
        add(music, R.piano(nf(nn), 1.8, 0.22), at)
    add(music, R.riser(1.0, 0.15), 9.0)

    # The tour groove: 100 BPM, softer under Catch up, resolving at the end.
    spb = 0.6
    chords = [["C3", "G3", "E4"], ["G2", "D3", "B3"], ["A2", "E3", "C4"], ["F2", "C3", "A3"]]
    melody = ["E5", "D5", "C5", "G4", "A4", "G4", "E4", "D4"]
    beat, tt = 0, 10.0
    while tt < GROOVE_END:
        soft = SOFT_A <= tt < SOFT_B
        if not soft:
            add(music, R.kick(), tt, 0.8)
            if beat % 2 == 1:
                add(music, R.snare(), tt, 0.55)
            add(music, R.hat(), tt + spb / 2, 0.9)
            add(music, R.hat(), tt, 0.5)
        if beat % 2 == 0:
            ch = chords[(beat // 2) % 4]
            for j, nn in enumerate(ch):
                add(music, R.piano(nf(nn), 1.4, 0.22 if not soft else 0.28), tt + j * 0.02)
            add(music, R.pad([nf(nn) for nn in ch], 1.3, 0.045, 0.05), tt)
            bass = nf(ch[0][0] + "2")
            n = int(1.1 * SR)
            tb = np.arange(n) / SR
            add(music, 0.3 * np.sin(2 * np.pi * bass * tb) * np.exp(-tb * 2.5), tt)
        if beat % 4 == 3 and not soft and (beat // 16) % 2 == 1:
            add(music, R.piano(nf(melody[(beat // 4) % len(melody)]), 1.0, 0.16), tt)
        beat += 1
        tt += spb
    add(music, R.riser(1.6, 0.14), SOFT_B - 1.6)

    # Scene sounds.
    blips = {
        "pop": lambda: R.blip(500, 950, 0.08, 0.14),
        "tap": lambda: R.blip(900, 600, 0.07, 0.2),
        "tick": lambda: R.blip(1300, 1550, 0.06, 0.15),
        "shimmer": lambda: R.blip(1700, 2100, 0.12, 0.06),
        "whoosh": lambda: R.whoosh(0.4, 0.14, 15),
    }
    for sc in SCENES:
        add(sfx, R.whoosh(0.4, 0.12, 16), sc[0] - 0.15)
        for lt, kind in sc[7]:
            add(sfx, blips[kind](), sc[0] + lt)

    # Outro resolve.
    add(sfx, R.whoosh(0.5, 0.2, 17), 79.3 + sh)
    for j, nn in enumerate(["C3", "G3", "E4", "B4"]):
        add(music, R.piano(nf(nn), 5.0, 0.3), 79.7 + sh + j * 0.12)
    add(music, R.pad([nf(n) for n in ["C3", "G3", "E4", "B4"]], 6.0, 0.06, 0.6), 79.7 + sh)
    for at, nn in [(81.4, "G4"), (82.2, "E4"), (83.4, "C5")]:
        add(music, R.piano(nf(nn), 3.0, 0.18), at + sh)
    add(sfx, R.blip(700, 1100, 0.1, 0.12), 81.2 + sh)

    mix = R.reverb(music, 1.8, 0.28) + R.reverb(sfx, 0.6, 0.1)
    mix = mix[: int(DUR * SR)]
    fn = int(2.5 * SR)
    mix[-fn:] *= np.linspace(1, 0, fn)
    mix /= np.max(np.abs(mix)) + 1e-9
    return (mix * 0.89).astype(np.float32)


def main():
    if "--stills" in sys.argv:
        stills = HERE / "stills-tour"
        stills.mkdir(exist_ok=True)
        times = [float(a) for a in sys.argv[2:]]
        for t in times:
            render(t, int(t * FPS)).save(stills / f"t{t:05.2f}.png")
        return
    audio = HERE / "soundtrack-tour.wav"
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
