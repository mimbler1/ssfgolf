"""Hand-authored stage pieces, drawn pixel by pixel in code (no GPU): surface caps for gameplay
materials, flags and signs. Deterministic, so the outputs are reproducible from this file.

usage: tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py <theme|all> [--preview out.png]

Writes art/worlds/<theme>/hand/caps/*.png and art/worlds/<theme>/hand/decor/*.png, which
build_stage.py copies into client/assets/worlds/<theme>/ (see stage.src.json "copy").

Cap strip contract (WorldArt.cap_line): the strip tiles horizontally along the surface, row
`cap_base` sits on the surface line, rows above it overhang into the air, rows below cover the
top of the ground. Every cap is 128 px wide and seamless (all features wrap with x mod 128).
Ink is #20141e (ART_STYLE_GUIDE §3). Light from the top-left.
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
INK = (32, 20, 30, 255)
CLEAR = (0, 0, 0, 0)


def hx(s: str) -> tuple[int, int, int, int]:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


class Cv:
    """Tiny RGBA pixel canvas. wrap=True makes x wrap (seamless horizontal tiles)."""

    def __init__(self, w: int, h: int, wrap: bool = False):
        self.w, self.h, self.wrap = w, h, wrap
        self.a = np.zeros((h, w, 4), np.uint8)

    def put(self, x: int, y: int, c) -> None:
        if self.wrap:
            x %= self.w
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = c

    def get(self, x: int, y: int):
        if self.wrap:
            x %= self.w
        if 0 <= x < self.w and 0 <= y < self.h:
            return tuple(self.a[y, x])
        return CLEAR

    def opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] > 0

    def rect(self, x0: int, y0: int, x1: int, y1: int, c) -> None:
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, c)

    def hline(self, x0: int, x1: int, y: int, c) -> None:
        for x in range(x0, x1):
            self.put(x, y, c)

    def vline(self, x: int, y0: int, y1: int, c) -> None:
        for y in range(y0, y1):
            self.put(x, y, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(self, cx: float, cy: float, r: float, c) -> None:
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.put(x, y, c)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c) -> None:
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def outline(self, c=INK, diag: bool = False) -> None:
        """1px ink ring around the opaque silhouette (outside)."""
        al = self.a[:, :, 3] > 0
        grow = np.zeros_like(al)
        sh = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (1, -1), (-1, 1), (-1, -1)] if diag else [])
        for dx, dy in sh:
            if self.wrap:
                rolled = np.roll(al, dx, axis=1)
            else:
                rolled = np.zeros_like(al)
                if dx > 0:
                    rolled[:, dx:] = al[:, :-dx]
                elif dx < 0:
                    rolled[:, :dx] = al[:, -dx:]
                else:
                    rolled = al.copy()
            r2 = np.zeros_like(al)
            if dy > 0:
                r2[dy:, :] = rolled[:-dy, :]
            elif dy < 0:
                r2[:dy, :] = rolled[-dy:, :]
            else:
                r2 = rolled
            grow |= r2
        self.a[grow & ~al] = c

    def img(self) -> Image.Image:
        return Image.fromarray(self.a, "RGBA")

    def crop_opaque(self) -> Image.Image:
        im = self.img()
        bb = im.getbbox()
        return im.crop(bb) if bb else im


def ramp(*cols: str):
    return [hx(c) for c in cols]


def smooth_noise(n: int, rng: random.Random, octaves=((16, 1.0), (8, 0.5), (4, 0.25))) -> np.ndarray:
    """Periodic 1D value noise of length n in [-1, 1] (wraps seamlessly)."""
    out = np.zeros(n)
    for period, amp in octaves:
        k = max(1, n // period)
        pts = [rng.uniform(-1, 1) for _ in range(k)]
        for x in range(n):
            t = x / n * k
            i = int(t)
            f = t - i
            f = f * f * (3 - 2 * f)
            out[x] += amp * (pts[i % k] * (1 - f) + pts[(i + 1) % k] * f)
    m = np.abs(out).max() or 1
    return out / m


# ---------------------------------------------------------------------------
# Caps
# ---------------------------------------------------------------------------

def cap_goo(seed: int = 1, W: int = 128) -> tuple[Image.Image, int]:
    """Glossy purple goo: a thick bulging layer with drips, bubbles and specular streaks.
    Base row 5: the goo stands proud of the surface by 5 px."""
    rng = random.Random(seed)
    H, base = 22, 5
    c = Cv(W, H, wrap=True)
    deep, dark, mid, light, pale, spec = ramp("3b0f63", "6418a3", "9132e0", "b968ff", "e3b8ff", "fff4ff")
    top = smooth_noise(W, rng, ((32, 1.0), (16, 0.6), (8, 0.25)))
    thick = 6
    tops = [int(round(base - 3 - 2 * top[x])) for x in range(W)]  # 0..5 above surface
    # Drips: rounded tongues hanging below the layer.
    drips = []
    x = rng.randint(0, 8)
    while x < W:
        drips.append((x, rng.randint(3, 11), rng.choice([2, 3, 3, 4])))
        x += rng.randint(12, 26)
    bottom = [base + thick for _ in range(W)]
    for dx0, ln, wd in drips:
        for i in range(wd):
            xx = (dx0 + i) % W
            bottom[xx] = max(bottom[xx], base + thick + ln - (1 if i in (0, wd - 1) else 0))
    for xx in range(W):
        for y in range(tops[xx], bottom[xx]):
            c.put(xx, y, mid)
    # Drop bulbs at the drip ends.
    for dx0, ln, wd in drips:
        cx = dx0 + wd / 2
        c.disc(cx, base + thick + ln - 0.5, wd / 2 + 0.9, mid)
    # Shading: dark underside, deep at the very bottom of each column.
    for xx in range(W):
        col = [y for y in range(H) if c.opaque(xx, y)]
        if not col:
            continue
        y0, y1 = col[0], col[-1]
        for y in col:
            d = y1 - y
            if d == 0:
                c.put(xx, y, deep)
            elif d <= 2:
                c.put(xx, y, dark)
        c.put(xx, y0, light)
        if y0 + 1 <= y1 - 3:
            c.put(xx, y0 + 1, light if (xx + seed) % 7 else pale)
    # Glossy highlight band: long streaks just under the top.
    x = rng.randint(0, 6)
    while x < W + 8:
        ln = rng.randint(5, 13)
        for i in range(ln):
            xx = x + i
            y0 = tops[xx % W] + 2
            c.put(xx, y0, pale)
            if 1 < i < ln - 2 and rng.random() < 0.55:
                c.put(xx, y0 - 1, spec)
        x += ln + rng.randint(6, 14)
    # Bubbles (ring + glint) inside the layer.
    for _ in range(9):
        bx = rng.randint(0, W - 1)
        by = base + rng.randint(1, 3)
        r = rng.choice([1, 1, 2])
        if r == 1:
            c.put(bx, by, light)
            c.put(bx + 1, by, pale)
            c.put(bx, by + 1, dark)
            c.put(bx + 1, by + 1, light)
        else:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (1, -1), (-1, 1)]:
                c.put(bx + dx, by + dy, light if dy < 1 else dark)
            c.put(bx - 1, by - 1, spec)
            c.put(bx, by, mid)
    # Drip glints.
    for dx0, ln, wd in drips:
        c.put(dx0 + max(0, wd // 2 - 1), base + thick + ln - 1, pale)
    c.outline()
    return c.img(), base


def cap_ice(seed: int = 2, W: int = 128) -> tuple[Image.Image, int]:
    """Glassy ice sheet: hard bright rim, deep cyan body with diagonal glare bands and cracks,
    a jagged underside with small icicle teeth. Base row 2."""
    rng = random.Random(seed)
    H, base = 22, 2
    c = Cv(W, H, wrap=True)
    deep, dark, mid, light, pale, white = ramp("1d4f9e", "2f7fd0", "4fb8f0", "8fe3ff", "c8f6ff", "ffffff")
    body = 11
    for x in range(W):
        for y in range(base - 1, base + body):
            c.put(x, y, mid)
    # Underside teeth (icicles).
    x = rng.randint(0, 5)
    while x < W:
        ln = rng.choice([1, 2, 2, 3, 4, 6])
        wd = 2 if ln < 4 else 3
        for i in range(ln):
            w2 = max(1, wd - (i * wd) // max(ln, 1))
            for k in range(w2):
                c.put(x + k, base + body + i, mid if i < ln - 1 else light)
        x += rng.randint(4, 11)
    # Vertical ramp: rim light, body, darker toward the bottom.
    for x in range(W):
        c.put(x, base - 1, white)
        c.put(x, base, pale)
        c.put(x, base + 1, light)
        for y in range(base + 4, base + body):
            c.put(x, y, mid if y < base + 5 else dark)
        c.put(x, base + body - 1, deep)
    # Teeth shading.
    for x in range(W):
        for y in range(base + body, H):
            if c.opaque(x, y):
                c.put(x, y, dark if c.opaque(x, y + 1) else light)
    # Diagonal glare bands (the glassy read).
    x = rng.randint(0, 10)
    while x < W + 10:
        wd = rng.choice([2, 3, 5])
        for y in range(base + 1, base + body - 1):
            for k in range(wd):
                xx = x + k - (y - base)
                cur = c.get(xx, y)
                if cur[3]:
                    c.put(xx, y, white if wd == 2 or k in (0,) else pale)
        x += rng.randint(14, 26)
    # Cracks.
    for _ in range(4):
        cx = rng.randint(0, W - 1)
        cy = base + 2
        for _ in range(rng.randint(3, 6)):
            c.put(cx, cy, deep)
            cx += rng.choice([-1, 1])
            cy += 1
            if cy >= base + body - 1:
                break
    # Sparkle crosses on the rim.
    for _ in range(5):
        sx = rng.randint(0, W - 1)
        c.put(sx, base - 2, white)
        c.put(sx - 1, base - 1, white)
        c.put(sx + 1, base - 1, white)
    c.outline()
    return c.img(), base + 1


def cap_snow(seed: int = 3, W: int = 128) -> tuple[Image.Image, int]:
    """Soft matte snow: pillowy lumps standing above the surface, a thick white blanket and a
    lumpy, shaded lower edge. No glare (the opposite of ice). Base row 7."""
    rng = random.Random(seed)
    H, base = 24, 7
    c = Cv(W, H, wrap=True)
    shadow, cool, mid, light, white = ramp("6f7fb8", "a3b4e0", "cfdcf5", "eef4ff", "ffffff")
    top = smooth_noise(W, rng, ((32, 0.9), (16, 1.0), (8, 0.35)))
    tops = [int(round(base - 2.5 - 2.6 * top[x])) for x in range(W)]
    bot = smooth_noise(W, rng, ((16, 1.0), (8, 0.7), (4, 0.3)))
    bots = [int(round(base + 9 + 3.2 * bot[x])) for x in range(W)]
    for x in range(W):
        for y in range(tops[x], bots[x]):
            c.put(x, y, light)
    # Rounded clumps hanging under the blanket.
    for _ in range(10):
        cx = rng.uniform(0, W)
        c.ellipse(cx, base + 10 + rng.uniform(0, 2), rng.uniform(2.5, 5), rng.uniform(1.6, 2.6), light)
    for x in range(W):
        col = [y for y in range(H) if c.opaque(x, y)]
        y0, y1 = col[0], col[-1]
        for y in col:
            d_top = y - y0
            d_bot = y1 - y
            if d_top == 0:
                cc = white
            elif d_top <= 2:
                cc = white if (x + y) % 9 else light
            elif d_bot == 0:
                cc = shadow
            elif d_bot <= 2:
                cc = cool
            elif d_bot <= 4:
                cc = mid
            else:
                cc = light
            c.put(x, y, cc)
    # Lump shading: each top bump gets a cool shadow on its right flank (light from top-left).
    for x in range(W):
        if tops[(x + 1) % W] > tops[x]:  # descending to the right
            for y in range(tops[(x + 1) % W], tops[(x + 1) % W] + 2):
                if c.get(x + 1, y)[3]:
                    c.put(x + 1, y, mid)
    # Sparse sparkle glints (matte: few, single pixels, never streaks).
    for _ in range(6):
        sx = rng.randint(0, W - 1)
        c.put(sx, tops[sx] + rng.randint(2, 5), white)
    c.outline()
    return c.img(), base


def cap_planks(pal: list, seed: int = 4, W: int = 128, rot: bool = False) -> tuple[Image.Image, int]:
    """Wooden boardwalk top: one plank course with grain, seams, nails and a dark lip. pal = 5
    colours dark->light. rot=True adds moss and rot (sticky bog)."""
    rng = random.Random(seed)
    H = 12
    c = Cv(W, H, wrap=True)
    d2, d1, m, l1, l2 = pal
    for x in range(W):
        c.put(x, 0, INK)
        c.put(x, 1, l2)
        c.put(x, 2, l1)
        for y in range(3, 9):
            c.put(x, y, m)
        c.put(x, 9, d1)
        c.put(x, 10, d2)
        c.put(x, 11, INK)
    # Grain streaks.
    for _ in range(26):
        gx = rng.randint(0, W - 1)
        gy = rng.randint(3, 8)
        ln = rng.randint(4, 14)
        for i in range(ln):
            c.put(gx + i, gy, d1 if rng.random() < 0.85 else l1)
        if rng.random() < 0.4:
            c.put(gx + ln // 2, gy - 1, l1)
    # Knots.
    for _ in range(3):
        kx, ky = rng.randint(0, W - 1), rng.randint(4, 7)
        c.put(kx, ky, d2)
        c.put(kx + 1, ky, d1)
        c.put(kx - 1, ky, d1)
        c.put(kx, ky - 1, l1)
    # Plank seams + nails.
    x = 0
    while x < W:
        for y in range(1, 11):
            c.put(x, y, d2)
        c.put(x + 1, 1, l2)
        for y in range(2, 10):
            c.put(x + 1, y, l1 if y < 4 else m)
        for nx in (x + 3, x - 3):
            c.put(nx, 4, (190, 196, 210, 255))
            c.put(nx, 5, d2)
        x += rng.choice([32, 32, 32])
    if rot:
        moss_d, moss, moss_l = ramp("2f6b3a", "4f9a45", "8fd36a")
        n = smooth_noise(W, rng, ((16, 1.0), (8, 0.6)))
        for x in range(W):
            if n[x] > 0.25:
                c.put(x, 1, moss_l)
                c.put(x, 2, moss)
                if n[x] > 0.55:
                    c.put(x, 0, moss)
                    c.put(x, 3, moss_d)
    return c.img(), 0


def cap_belt(seed: int = 5, W: int = 128) -> tuple[Image.Image, int]:
    """Conveyor belt: dark rubber belt over steel rollers in a riveted side frame. Plain on
    purpose: ForceOverlay draws the moving chevrons on top. Base row 0."""
    rng = random.Random(seed)
    H = 16
    c = Cv(W, H, wrap=True)
    rub_d, rub, rub_l = ramp("1c1820", "2f2a36", "4a4454")
    st_d, st, st_m, st_l, st_w = ramp("2c3446", "4d5a73", "7886a3", "aab6cc", "e3e9f2")
    gold_d, gold = ramp("8a5a1c", "e0a73a")
    for x in range(W):
        c.put(x, 0, INK)
        c.put(x, 1, rub_l)
        c.put(x, 2, rub)
        c.put(x, 3, rub)
        c.put(x, 4, rub_d)
        c.put(x, 5, INK)
    # Belt tread ridges.
    for x in range(0, W, 8):
        c.put(x, 2, rub_d)
        c.put(x, 3, rub_d)
        c.put(x + 1, 2, rub_l)
    # Side frame.
    for x in range(W):
        c.put(x, 6, st_l)
        for y in range(7, 13):
            c.put(x, y, st)
        c.put(x, 13, st_d)
        c.put(x, 14, INK)
    # Rollers every 16 px: round hubs in the frame.
    for rx in range(8, W + 8, 16):
        c.disc(rx, 9.5, 3.2, st_d)
        c.disc(rx, 9.5, 2.4, st_m)
        c.put(rx - 1, 8, st_w)
        c.put(rx, 9, st_d)
        c.put(rx, 10, st_d)
        c.put(rx - 1, 9, st_d)
        c.put(rx - 1, 10, st_d)
    # Rivets + hazard tick between rollers.
    for rx in range(0, W, 16):
        c.put(rx, 8, st_w)
        c.put(rx, 9, st_d)
        c.put(rx, 11, gold)
        c.put(rx, 12, gold_d)
    return c.img(), 0


def cap_metal(seed: int = 6, W: int = 128) -> tuple[Image.Image, int]:
    """Lab floor plating: bright steel lip, diamond-plate tread, a cyan light seam and a
    yellow/black hazard band. Base row 0."""
    rng = random.Random(seed)
    H = 15
    c = Cv(W, H, wrap=True)
    st_d, st, st_m, st_l, st_w = ramp("232a3c", "3e4a63", "5d6c88", "8fa0bd", "d6e2f2")
    cy_d, cy, cy_l = ramp("1c7f9e", "3fd6ff", "c8fbff")
    yel, blk = hx("f2c230"), hx("2a2430")
    for x in range(W):
        c.put(x, 0, INK)
        c.put(x, 1, st_w)
        c.put(x, 2, st_l)
        for y in range(3, 7):
            c.put(x, y, st_m)
        c.put(x, 7, st)
    # Diamond tread: alternating raised ticks.
    for x in range(0, W, 4):
        for y in (3, 5):
            ox = x + (2 if y == 5 else 0)
            c.put(ox, y, st_l)
            c.put(ox + 1, y + 1, st)
    # Plate seams with screws.
    for sx in range(0, W, 32):
        for y in range(1, 8):
            c.put(sx, y, st_d)
        c.put(sx + 1, 2, st_w)
        for yy in (3, 6):
            c.put(sx + 3, yy, st_w)
            c.put(sx - 3, yy, st_w)
    # Cyan light seam.
    for x in range(W):
        c.put(x, 8, cy_d)
        c.put(x, 9, cy if (x // 4) % 6 else cy_l)
    # Hazard band.
    for x in range(W):
        for y in range(10, 13):
            c.put(x, y, yel if ((x + y) // 4) % 2 == 0 else blk)
        c.put(x, 13, st_d)
        c.put(x, 14, INK)
    return c.img(), 0


def cap_grass(pal: dict, seed: int = 7, W: int = 128, flowers: list | None = None, blades: str = "tuft") -> tuple[Image.Image, int]:
    """Grass lip: blades and tufts standing above the surface, a dense turf band, and a
    ragged dark fringe hanging over the soil. pal: dark, mid, light, hi, under (5 colours).
    blades: "tuft" (lawn), "dune" (tall thin dune grass), "moss" (low round moss)."""
    rng = random.Random(seed)
    H, base = 28, 11
    c = Cv(W, H, wrap=True)
    dark, mid, light, hi, under = pal["dark"], pal["mid"], pal["light"], pal["hi"], pal["under"]
    # Turf band.
    fr = smooth_noise(W, rng, ((16, 1.0), (8, 0.8), (4, 0.4)))
    for x in range(W):
        bottom = base + 5 + int(round(1.6 + 1.8 * fr[x]))
        for y in range(base - 1, bottom):
            c.put(x, y, mid)
        for y in range(bottom - 2, bottom):
            c.put(x, y, dark)
        c.put(x, bottom, under)
    # Hanging roots / fringe drips under the turf.
    for _ in range(14):
        x = rng.randint(0, W - 1)
        col = [y for y in range(H) if c.opaque(x, y)]
        yb = col[-1]
        ln = rng.randint(1, 4)
        for i in range(ln):
            c.put(x, yb + 1 + i, dark if i < ln - 1 else under)
    # Blades above the line.
    if blades in ("scallop", "dune_scallop"):
        # Rounded leafy clumps overlapping along the rim (the SSF2 grass-edge read), shaded per
        # clump: lit top-left, dark rim bottom-right. A few long blades poke out on dunes.
        x = rng.uniform(0, 3)
        clumps = []
        while x < W:
            r = rng.uniform(3.6, 6.2) if blades == "scallop" else rng.uniform(2.8, 4.6)
            cy = base + 1.0 - r * rng.uniform(0.45, 0.8)
            clumps.append((x, cy, r))
            x += r * rng.uniform(1.0, 1.45)
        # Back row first (darker), then the front row: overlaps leave dark crescents between clumps.
        order = sorted(range(len(clumps)), key=lambda i: clumps[i][1])
        for i in order:
            cx, cy, r = clumps[i]
            for dx in (-W, 0, W):
                c.ellipse(cx + dx, cy, r + 0.5, r * 0.85 + 0.5, dark)
                c.ellipse(cx + dx - 0.3, cy - 0.4, r - 0.3, r * 0.85 - 0.6, mid)
                c.ellipse(cx + dx - r * 0.3, cy - r * 0.35, r * 0.5, r * 0.36, light)
                c.put(int(cx + dx - r * 0.45), int(cy - r * 0.62), hi)
                c.put(int(cx + dx - r * 0.45) + 1, int(cy - r * 0.62), hi)
        if blades == "dune_scallop":
            for _ in range(int(W / 7)):
                bx = rng.randint(0, W - 1)
                ln = rng.randint(4, 8)
                lean = rng.choice([-1, 1])
                top = min(y for y in range(H) if c.opaque(bx, y))
                for i in range(ln):
                    c.put(bx + (lean * i) // 3, top - i, light if i < ln - 1 else hi)
    elif blades == "moss":
        x = 0
        while x < W:
            r = rng.uniform(2.0, 4.2)
            c.ellipse(x, base - 0.5, r + 1, r * 0.75, mid)
            x += int(r * 1.6) + rng.randint(0, 2)
    else:
        x = 0
        while x < W:
            if blades == "dune":
                # Fanned clumps of long blades with gaps of bare sand-turf between them.
                n = rng.choice([3, 4, 5])
                hgt = rng.choice([4, 6, 7, 8, 9])
                for b in range(n):
                    t = b / (n - 1) * 2 - 1
                    ln = max(2, int(hgt * (1 - 0.35 * abs(t))))
                    for i in range(ln):
                        xx = x + n // 2 + int(round(t * i * 0.45))
                        c.put(xx, base - 1 - i, mid)
                        if i < 2:
                            c.put(xx + 1, base - 1 - i, mid)
                x += n + rng.randint(3, 8)
            else:
                hgt = rng.choice([2, 3, 3, 4, 5, 6])
                wd = rng.choice([3, 4, 5])
                for k in range(wd):
                    hh = hgt - abs(k - wd // 2) * 2 + rng.randint(-1, 0)
                    for i in range(max(1, hh)):
                        c.put(x + k, base - 1 - i, mid)
                x += wd + rng.randint(-1, 2)
    # Shade: light from top-left. Top-most pixel of each column = hi/light, left edges light.
    for x in (range(W) if blades not in ("scallop", "dune_scallop") else []):
        col = [y for y in range(H) if c.opaque(x, y)]
        y0 = col[0]
        for y in col:
            if y >= base + 1:
                continue
            cur = c.get(x, y)
            if cur[:3] != mid[:3]:
                continue
            if y == y0:
                c.put(x, y, hi)
            elif y <= y0 + 1 or not c.opaque(x - 1, y):
                c.put(x, y, light)
            elif not c.opaque(x + 1, y):
                c.put(x, y, dark)
    # Turf texture: blade marks inside the band.
    for _ in range(120):
        x = rng.randint(0, W - 1)
        y = rng.randint(base, base + 4)
        if c.get(x, y)[:3] == mid[:3]:
            c.put(x, y, light if rng.random() < 0.45 else dark)
            if rng.random() < 0.5 and c.get(x, y + 1)[:3] == mid[:3]:
                c.put(x, y + 1, dark)
    for x in range(W):
        c.put(x, base - 1 if c.get(x, base - 1)[:3] == mid[:3] else base - 1, c.get(x, base - 1))
    # Flowers.
    for fc in (flowers or []):
        for _ in range(3):
            x = rng.randint(0, W - 1)
            col = [y for y in range(H) if c.opaque(x, y)]
            y0 = col[0]
            c.put(x, y0 - 1, dark)
            c.put(x, y0 - 2, fc)
            c.put(x - 1, y0 - 2, fc)
            c.put(x + 1, y0 - 2, fc)
            c.put(x, y0 - 3, fc)
            c.put(x, y0 - 2, hx("fff6c8"))
    c.outline()
    return c.img(), base


def cap_sand(pal: dict, seed: int = 8, W: int = 128, shells: bool = True) -> tuple[Image.Image, int]:
    """Soft sand: low rippled mounds above the line, speckled body, darker damp lower edge."""
    rng = random.Random(seed)
    H, base = 18, 4
    c = Cv(W, H, wrap=True)
    d2, d1, m, l1, l2 = pal["d2"], pal["d1"], pal["m"], pal["l1"], pal["l2"]
    top = smooth_noise(W, rng, ((32, 1.0), (16, 0.6), (8, 0.2)))
    bot = smooth_noise(W, rng, ((16, 1.0), (8, 0.6)))
    for x in range(W):
        t = int(round(base - 2 - 1.6 * top[x]))
        b = int(round(base + 9 + 1.6 * bot[x]))
        for y in range(t, b):
            c.put(x, y, m)
        c.put(x, t, l2)
        c.put(x, t + 1, l1)
        c.put(x, b - 1, d2)
        c.put(x, b - 2, d1)
    # Ripple marks: short light-over-dark dashes.
    for _ in range(26):
        x = rng.randint(0, W - 1)
        y = rng.randint(base, base + 5)
        ln = rng.randint(3, 6)
        for i in range(ln):
            if c.get(x + i, y)[:3] == m[:3]:
                c.put(x + i, y, l1)
            if c.get(x + i + 1, y + 1)[:3] == m[:3]:
                c.put(x + i + 1, y + 1, d1)
    # Speckles.
    for _ in range(90):
        x, y = rng.randint(0, W - 1), rng.randint(base, base + 9)
        if c.get(x, y)[:3] == m[:3]:
            c.put(x, y, rng.choice([d1, l1, l1]))
    if shells:
        for _ in range(3):
            x = rng.randint(0, W - 1)
            y = base + rng.randint(2, 6)
            sh, shd = ramp("fff1e6", "f08a8a")
            c.put(x, y, sh)
            c.put(x + 1, y, sh)
            c.put(x, y + 1, shd)
            c.put(x + 1, y + 1, sh)
    c.outline()
    return c.img(), base


# ---------------------------------------------------------------------------
# Decor
# ---------------------------------------------------------------------------

def flag_on_pole(cloth: list, h: int = 34, fw: int = 12, fh: int = 8, pole=("7a8296", "d7dce6"), knob="f2c230",
                 stripes: list | None = None, seed: int = 9, base: str | None = None, shape: str = "pennant") -> Image.Image:
    """A small pole with a cloth flag. cloth = [dark, mid, light]. shape: pennant | square | swallow."""
    rng = random.Random(seed)
    W, H = fw + 6, h + 4
    c = Cv(W, H)
    pd, pl = hx(pole[0]), hx(pole[1])
    px = 2
    for y in range(2, H):
        c.put(px, y, pl)
        c.put(px + 1, y, pd)
    c.put(px, 1, hx(knob))
    c.put(px + 1, 1, hx(knob))
    d, m, l = [hx(x) for x in cloth]
    for i in range(fw):
        x = px + 2 + i
        wave = int(round(math.sin(i / fw * math.pi * 1.6) * 1.2))
        if shape == "pennant":
            hh = max(1, int(round(fh * (1 - i / fw))))
            y0 = 3 + wave + (fh - hh) // 2
        else:
            hh = fh
            y0 = 3 + wave
        for y in range(y0, y0 + hh):
            if shape == "swallow" and i > fw * 0.65 and abs(y - (y0 + hh / 2 - 0.5)) < (i - fw * 0.65) * 0.9:
                continue
            col = m
            if stripes:
                col = hx(stripes[((y - y0) * len(stripes)) // hh])
            if y == y0:
                col = l if not stripes else col
            if y == y0 + hh - 1:
                col = d
            c.put(x, y, col)
        if i % 4 == 3:  # fold shadow
            for y in range(y0 + 1, y0 + hh - 1):
                cur = c.get(x, y)
                if cur[3]:
                    c.put(x, y, tuple(int(v * 0.8) for v in cur[:3]) + (255,))
    if base:
        b = hx(base)
        c.rect(px - 2, H - 2, px + 4, H, b)
    c.outline()
    return c.crop_opaque()


def tuft(pal: list, seed: int, w: int = 15, h: int = 14, blades: int = 9, seeds_heads: bool = False) -> Image.Image:
    """Clump of grass blades fanning out from one root. pal = dark, mid, light, hi."""
    rng = random.Random(seed)
    c = Cv(w + 4, h + 3)
    d, m, l, hi = pal
    cx = (w + 4) // 2
    base = h + 1
    for i in range(blades):
        t = (i / max(1, blades - 1)) * 2 - 1  # -1..1
        ln = int(h * (1 - 0.45 * abs(t)) * rng.uniform(0.75, 1.0))
        bend = rng.uniform(-0.6, 0.6)
        for k in range(ln):
            f = k / max(1, ln)
            x = cx + int(round(t * (w / 2) * f + bend * f * f * 3))
            y = base - k
            col = m if k < ln * 0.6 else l
            if k == ln - 1:
                col = hi
            c.put(x, y, col)
            if k < ln * 0.3:
                c.put(x + (1 if t >= 0 else -1), y, d)
        if seeds_heads and rng.random() < 0.4:
            x = cx + int(round(t * (w / 2) + bend * 3))
            c.put(x, base - ln - 1, hx("e8d08a"))
            c.put(x, base - ln - 2, hx("c9a860"))
    for x in range(cx - 3, cx + 4):
        c.put(x, base, d)
    c.outline()
    return c.crop_opaque()


def summit_flag(seed: int = 71) -> Image.Image:
    """Tall summit pole with a swallowtail banner, planted in a stone cairn capped with snow."""
    rng = random.Random(seed)
    flag = flag_on_pole(["a8203a", "e0405a", "ff9aa8"], h=64, fw=24, fh=15, shape="swallow",
                        pole=("6b4a2a", "c08552"), knob="f2c230", seed=seed)
    W, H = 34, flag.height + 10
    c = Cv(W, H)
    c.a[0:flag.height, 6:6 + flag.width] = np.asarray(flag)
    st = ramp("4a4e63", "6f7590", "9aa1b8", "c4cadb")
    sn = ramp("a3b4e0", "e6eeff", "ffffff")
    stones = [(9, H - 4, 7, 3.6), (17, H - 4, 6.5, 3.4), (13, H - 9, 6, 3.2), (24, H - 3, 4, 2.6), (5, H - 3, 4, 2.4)]
    for x, y, rx, ry in stones:
        c.ellipse(x, y, rx, ry, st[1])
        c.ellipse(x - 1, y - 1, rx - 1.5, ry - 1.2, st[2])
        c.put(int(x - rx / 2), int(y - ry / 2), st[3])
    for x in range(5, 22):
        y = H - 12 + int(abs(x - 13) / 3)
        c.put(x, y, sn[2])
        c.put(x, y + 1, sn[1])
    c.outline()
    return c.crop_opaque()


def arrow_sign(up: bool = True) -> Image.Image:
    """Glowing holographic gravity arrow on a short emitter post."""
    W, H = 24, 46
    c = Cv(W, H)
    cy_d, cy, cy_l, white = ramp("1a8fb5", "3fe0ff", "a8f7ff", "ffffff")
    st_d, st, st_l = ramp("2c3446", "5d6c88", "aab6cc")
    # Emitter base.
    c.rect(7, H - 6, 17, H, st)
    c.rect(7, H - 6, 17, H - 5, st_l)
    c.rect(9, H - 9, 15, H - 6, st_d)
    c.rect(10, H - 10, 14, H - 9, cy)
    # Arrow (drawn pointing up, flipped for down).
    a = Cv(W, 32)
    for y in range(12):
        half = y + 1
        for x in range(12 - half, 12 + half):
            a.put(x, y, cy)
    a.rect(7, 12, 17, 30, cy)
    a.outline(cy_d)
    # Inner highlight.
    for y in range(3, 11):
        a.put(12 - (y - 1) + 1, y, cy_l)
    for y in range(13, 29):
        a.put(8, y, cy_l)
    a.rect(11, 14, 13, 27, white)
    arr = a.a if up else a.a[::-1, :, :]
    c.a[2:34] = np.where(arr[:, :, 3:4] > 0, arr, c.a[2:34])
    # Projection beam.
    for y in range(34, H - 10):
        for x in (10, 13):
            c.put(x, y, cy_d)
    c.outline()
    return c.crop_opaque()


# ---------------------------------------------------------------------------

def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def build(theme: str) -> list[tuple[str, Image.Image, int]]:
    out: list[tuple[str, Image.Image, int]] = []
    if theme == "beach":
        g, gb = cap_grass({"dark": hx("4f8a2c"), "mid": hx("86c043"), "light": hx("b5e06a"), "hi": hx("e6f7a4"),
                           "under": hx("6b4a2a")}, seed=11, blades="dune_scallop")
        out.append(("caps/grass", g, gb))
        s, sb = cap_sand({"d2": hx("b8804a"), "d1": hx("dba667"), "m": hx("f0cd8e"), "l1": hx("f9e2b0"), "l2": hx("fff4d6")}, seed=12)
        out.append(("caps/sand", s, sb))
        w, wb = cap_planks(ramp("4a2a1e", "7a4a2e", "a8703f", "cf9a5f", "ecc28a"), seed=13)
        out.append(("caps/wood", w, wb))
        dune = [hx("4f7a2c"), hx("86b043"), hx("b9d870"), hx("eef2b0")]
        out.append(("decor/grass_tuft_a", tuft(dune, 61, 15, 14, 9, True), 0))
        out.append(("decor/grass_tuft_b", tuft(dune, 62, 21, 18, 13, True), 0))
        out.append(("decor/grass_tuft_c", tuft(dune, 63, 11, 11, 7, False), 0))
        out.append(("decor/flag_small_a", flag_on_pole(["a8203a", "e0405a", "ff8f9a"], stripes=None, seed=1), 0))
        out.append(("decor/flag_small_b", flag_on_pole(["1b5fa8", "3a8fe0", "8fd0ff"], shape="swallow", seed=2), 0))
    elif theme == "sticky":
        g, gb = cap_grass({"dark": hx("2c6b3c"), "mid": hx("4f9a48"), "light": hx("86cf5e"), "hi": hx("c8f08a"),
                           "under": hx("3a2438")}, seed=21, blades="scallop", flowers=[hx("ff8fe8"), hx("b8f0ff")])
        out.append(("caps/grass", g, gb))
        gg, ggb = cap_goo(seed=22)
        out.append(("caps/sticky", gg, ggb))
        w, wb = cap_planks(ramp("2e1e24", "4f3436", "6e4e46", "8f6c5a", "b08e72"), seed=23, rot=True)
        out.append(("caps/wood", w, wb))
    elif theme == "snow":
        s, sb = cap_snow(seed=31)
        out.append(("caps/snow", s, sb))
        i, ib = cap_ice(seed=32)
        out.append(("caps/ice", i, ib))
        out.append(("decor/flag_small_a", flag_on_pole(["a8203a", "e0405a", "ff8f9a"], seed=3), 0))
        out.append(("decor/summit_flag_a", summit_flag(), 0))
        out.append(("decor/flag_slalom_red", flag_on_pole(["a8203a", "e0405a", "ff8f9a"], h=40, fw=14, fh=11, shape="square",
                                                           pole=("8a5a1c", "e0a73a"), knob="ffffff", seed=4), 0))
        out.append(("decor/flag_slalom_blue", flag_on_pole(["1b4fa8", "3a7fe0", "8fc0ff"], h=40, fw=14, fh=11, shape="square",
                                                            pole=("8a5a1c", "e0a73a"), knob="ffffff", seed=5), 0))
    elif theme == "lab":
        m, mb = cap_metal(seed=41)
        out.append(("caps/rock", m, mb))
        out.append(("decor/arrow_up", arrow_sign(True), 0))
        out.append(("decor/arrow_down", arrow_sign(False), 0))
    elif theme == "spin":
        g, gb = cap_grass({"dark": hx("4a9a3a"), "mid": hx("82cf52"), "light": hx("b6ea78"), "hi": hx("f0f8b0"),
                           "under": hx("6e4430")}, seed=51, blades="scallop", flowers=[hx("ff6f8f"), hx("ffd84a"), hx("ffffff")])
        out.append(("caps/grass", g, gb))
        s, sb = cap_sand({"d2": hx("b07040"), "d1": hx("d49a5e"), "m": hx("eec08a"), "l1": hx("f8dcae"), "l2": hx("fff0d4")}, seed=52, shells=False)
        out.append(("caps/sand", s, sb))
        b, bb = cap_belt(seed=53)
        out.append(("caps/conveyor", b, bb))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("theme")
    ap.add_argument("--preview")
    a = ap.parse_args()
    themes = ["beach", "sticky", "snow", "lab", "spin"] if a.theme == "all" else [a.theme]
    pieces = []
    for t in themes:
        for name, img, base in build(t):
            save(img, ROOT / "art/worlds" / t / "hand" / f"{name}.png")
            print(f"  {t}/hand/{name}.png {img.size} base={base}")
            pieces.append((t, name, img))
    if a.preview:
        k = 4
        bg = (120, 140, 170, 255)
        rows = []
        for t, name, img in pieces:
            if name.startswith("caps/"):
                strip = Image.new("RGBA", (img.width * 2, img.height), (0, 0, 0, 0))
                strip.paste(img, (0, 0))
                strip.paste(img, (img.width, 0))
                img = strip
            rows.append(img.resize((img.width * k, img.height * k), Image.NEAREST))
        W = max(r.width for r in rows) + 16
        H = sum(r.height + 12 for r in rows) + 4
        sheet = Image.new("RGBA", (W, H), bg)
        y = 4
        for r in rows:
            sheet.alpha_composite(r, (8, y))
            y += r.height + 12
        sheet.save(a.preview)


if __name__ == "__main__":
    main()
