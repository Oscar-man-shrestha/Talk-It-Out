"""Draws the Talk It Out icon (no image libraries needed) and writes every
size Android, Google Play and the web app use. Run: python3 tool/make_icons.py
"""
import os, struct, zlib

INK = (9, 9, 11)
WHITE = (255, 255, 255)
GREY = (82, 82, 91)

def rrect(x, y, x0, y0, x1, y1, r):
    cx = min(max(x, x0 + r), x1 - r); cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r and x0 <= x <= x1 and y0 <= y <= y1

def tri(x, y, a, b, c):
    def s(p, q, r): return (p[0]-r[0])*(q[1]-r[1]) - (q[0]-r[0])*(p[1]-r[1])
    d1, d2, d3 = s((x, y), a, b), s((x, y), b, c), s((x, y), c, a)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))

def glyph(u, v):
    """Colour at icon coordinates (0..1), or None for transparent."""
    # Front bubble with three dots.
    if rrect(u, v, 0.18, 0.38, 0.70, 0.74, 0.11) or tri(u, v, (0.26, 0.70), (0.42, 0.70), (0.22, 0.85)):
        for dx in (0.30, 0.44, 0.58):
            if (u - dx) ** 2 + (v - 0.56) ** 2 <= 0.042 ** 2:
                return INK
        return WHITE
    # A gap around the front bubble so the back one reads as behind it.
    if rrect(u, v, 0.15, 0.35, 0.73, 0.77, 0.13):
        return None
    if rrect(u, v, 0.34, 0.18, 0.84, 0.52, 0.10) or tri(u, v, (0.66, 0.48), (0.80, 0.48), (0.84, 0.62)):
        return GREY
    return None

def render(size, full, scale=1.0, ss=3):
    rows = []
    for py in range(size):
        row = bytearray([0])
        for px in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(ss):
                for sx in range(ss):
                    c = ((px + (sx + 0.5) / ss) / size, (py + (sy + 0.5) / ss) / size)
                    u = 0.5 + (c[0] - 0.5) / scale; v = 0.5 + (c[1] - 0.5) / scale
                    col = glyph(u, v)
                    if col is None and full and rrect(c[0], c[1], 0, 0, 1, 1, 0.22):
                        col = INK
                    if col is not None:
                        acc[0] += col[0]; acc[1] += col[1]; acc[2] += col[2]; acc[3] += 255
            n = ss * ss
            a = acc[3] // n
            if a:
                k = acc[3] / 255
                row += bytes([int(acc[0] / k), int(acc[1] / k), int(acc[2] / k), a])
            else:
                row += b"\0\0\0\0"
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")

def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data)

root = os.path.join(os.path.dirname(__file__), "..")
res = os.path.join(root, "android/app/src/main/res")
for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    write(f"{res}/mipmap-{name}/ic_launcher.png", render(px, True))
    # Adaptive icon foreground: 108dp canvas, content inside the 66dp safe zone.
    write(f"{res}/mipmap-{name}/ic_launcher_foreground.png", render(px * 9 // 4, False, scale=0.86))
write(f"{res}/mipmap-anydpi-v26/ic_launcher.xml".replace("ic_launcher.xml", "ic_launcher.xml"), b"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""")
write(f"{res}/values/ic_launcher_background.xml", b"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#09090B</color>
</resources>
""")
web = os.path.join(root, "web")
write(f"{web}/icons/Icon-192.png", render(192, True))
write(f"{web}/icons/Icon-512.png", render(512, True, ss=2))
write(f"{web}/icons/Icon-maskable-192.png", render(192, True, scale=0.8))
write(f"{web}/icons/Icon-maskable-512.png", render(512, True, scale=0.8, ss=2))
write(f"{web}/favicon.png", render(32, True, ss=4))
write(os.path.join(root, "docs/store/icon-512.png"), render(512, True, ss=2))
print("icons written")
