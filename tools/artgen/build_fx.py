"""Build the gameplay effect flipbooks (client/assets/effects/*.png + effects.json).

Effects are animated pixel art: hand-picked generated shapes (stars, flame) and pixel-drawn
puffs/droplets, moved, scaled and dissolved frame by frame with an ordered dither, so every frame
stays on the pixel grid (no blur, no partial alpha). Sources: art/effects/picks.

usage: tools/artgen/.venv/Scripts/python tools/artgen/build_fx.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

import pixelize as px

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art/effects/picks"
DST = ROOT / "client/assets/effects"
INK = (32, 20, 30, 255)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def dissolve(img: Image.Image, amount: float) -> Image.Image:
    """Ordered-dither fade: removes `amount` (0..1) of the opaque pixels in a stable pattern."""
    a = np.asarray(img).copy()
    h, w = a.shape[:2]
    mask = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] < amount
    a[mask, 3] = 0
    return Image.fromarray(a, "RGBA")


def scaled(img: Image.Image, k: float) -> Image.Image:
    w, h = max(1, round(img.width * k)), max(1, round(img.height * k))
    return img.resize((w, h), Image.NEAREST)


def paste_center(canvas: Image.Image, img: Image.Image, cx: float, cy: float) -> None:
    canvas.alpha_composite(img, (round(cx - img.width / 2), round(cy - img.height / 2)))


def disc(r: int, cols: list[tuple], ink: bool = True) -> Image.Image:
    """Pixel puff: light top-left, mid body, shadow rim, optional ink outline."""
    s = r * 2 + 3
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    c = s / 2 - 0.5
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - c, y - c)
            if d <= r:
                lit = math.hypot(x - (c - r * 0.35), y - (c - r * 0.35))
                im.putpixel((x, y), cols[0] if lit < r * 0.45 else cols[1] if d < r - 1.2 else cols[2])
    return px.outline(im, INK[:3]) if ink else im


def sheet(frames: list[Image.Image]) -> Image.Image:
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w + (w - f.width) // 2, (h - f.height) // 2))
    return out


def star_shape(r: float, points: int = 4, inner: float = 0.38, cols=None, rot: float = 0.0) -> Image.Image:
    """Pixel star burst: white core, yellow body, orange tips, ink outline (no anti-aliasing)."""
    from PIL import ImageDraw
    cols = cols or [(255, 255, 255, 255), (255, 228, 92, 255), (255, 150, 40, 255)]
    s = int(r * 2 + 4)
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = s / 2
    for k, col in [(1.0, cols[2]), (0.72, cols[1]), (0.38, cols[0])]:
        pts = []
        for i in range(points * 2):
            a = rot + i * math.pi / points - math.pi / 2
            rr = r * k * (1.0 if i % 2 == 0 else inner)
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        d.polygon(pts, fill=col)
    return px.outline(im, INK[:3])


def impact() -> Image.Image:
    star = star_shape(14, 4, 0.3)
    frames = []
    for k, fade in [(0.45, 0), (0.85, 0), (1.05, 0.15), (1.15, 0.45), (1.2, 0.7), (1.25, 0.88)]:
        f = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        paste_center(f, dissolve(scaled(star, k), fade), 20, 20)
        frames.append(f)
    return sheet(frames)


def sparkle() -> Image.Image:
    star = star_shape(12, 5, 0.45, rot=0.0)
    small = star_shape(4, 4, 0.35)
    frames = []
    for i in range(8):
        t = i / 7
        f = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        paste_center(f, dissolve(scaled(star, 0.5 + 0.5 * math.sin(min(t * 2.2, 1) * math.pi / 2)), max(0, t - 0.4) * 1.6), 32, 32)
        for j in range(6):
            a = j / 6 * math.tau + 0.3
            r = 6 + t * 24
            paste_center(f, dissolve(small, max(0, t - 0.55) * 2.2), 32 + math.cos(a) * r, 32 + math.sin(a) * r)
        frames.append(f)
    return sheet(frames)


def dust() -> Image.Image:
    cols = [(246, 232, 204, 255), (214, 190, 150, 255), (160, 132, 96, 255)]
    puffs = [(-7, 0, 4), (0, -3, 5), (7, 0, 4), (-3, 2, 3), (4, 2, 3)]
    frames = []
    for i in range(6):
        t = i / 5
        f = Image.new("RGBA", (40, 24), (0, 0, 0, 0))
        for (x, y, r) in puffs:
            rr = max(1, round(r * (0.6 + t * 0.7)))
            paste_center(f, dissolve(disc(rr, cols), max(0, t - 0.3) * 1.3), 20 + x * (1 + t * 0.8), 14 + y - t * 4)
        frames.append(f)
    return sheet(frames)


def splash() -> Image.Image:
    cols = [(255, 255, 255, 255), (170, 226, 255, 255), (64, 150, 214, 255)]
    rng = np.random.default_rng(3)
    drops = [(rng.uniform(-1, 1), rng.uniform(0.6, 1.0), rng.integers(1, 3)) for _ in range(14)]
    frames = []
    for i in range(8):
        t = i / 7
        f = Image.new("RGBA", (56, 48), (0, 0, 0, 0))
        # crown: rising then collapsing water sheet
        hgt = math.sin(min(t * 1.6, 1) * math.pi) * 18
        for x in range(-10, 11):
            col_h = int(hgt * (1 - abs(x) / 12) * (0.8 + 0.2 * math.cos(x)))
            for y in range(col_h):
                c = cols[0] if y > col_h - 3 else cols[1] if abs(x) < 7 else cols[2]
                if t > 0.6 and (x + y + i) % 3 == 0:
                    continue
                f.putpixel((28 + x, 44 - y), c)
        for (dx, sp, r) in drops:
            x = 28 + dx * 22 * t
            y = 42 - sp * 34 * t + 40 * t * t
            if y < 47:
                paste_center(f, disc(int(r), cols, ink=False), x, y)
        frames.append(px.outline(dissolve(f, max(0, t - 0.75) * 3), INK[:3]))
    return sheet(frames)


def flame_shape(w: int, h: int, seed: int) -> Image.Image:
    """Teardrop flame: ramped white->yellow->orange->red, flickering edge, ink outline."""
    rng = np.random.default_rng(seed)
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    ramp = [(255, 250, 220, 255), (255, 214, 72, 255), (255, 138, 36, 255), (214, 52, 40, 255)]
    for y in range(h):
        v = y / (h - 1)                      # 0 top (tip) .. 1 base
        half = (w / 2) * math.sin(min(v * 1.25, 1) * math.pi / 2) * (1 - max(0, v - 0.85) * 2)
        half += rng.uniform(-0.8, 0.8)
        for x in range(w):
            dx = abs(x - (w - 1) / 2)
            if dx <= half:
                k = dx / max(half, 0.5)
                band = 0 if (k < 0.3 and v > 0.45) else 1 if k < 0.55 else 2 if k < 0.85 else 3
                im.putpixel((x + 1, y + 1), ramp[band])
    return px.outline(im, INK[:3])


def flame() -> Image.Image:
    fl = flame_shape(14, 24, 5)
    frames = []
    for i, (k, sq, fade) in enumerate([(0.6, 1.0, 0), (0.9, 1.1, 0), (1.0, 0.9, 0.1), (0.95, 1.15, 0.3), (0.8, 1.0, 0.55), (0.6, 1.1, 0.8)]):
        img = fl.resize((max(1, round(fl.width * k)), max(1, round(fl.height * k * sq))), Image.NEAREST)
        f = Image.new("RGBA", (40, 48), (0, 0, 0, 0))
        paste_center(f, dissolve(img, fade), 20, 30 - i)
        frames.append(f)
    return sheet(frames)


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    lib = {}
    for name, fn, fps, additive, oy in [("impact", impact, 24, True, 0), ("sparkle", sparkle, 16, True, 0),
                                       ("dust", dust, 16, False, -6), ("splash", splash, 16, False, -18),
                                       ("flame", flame, 18, True, -8)]:
        s = fn()
        s.save(DST / f"{name}.png")
        n = s.width // (s.width // len([0 for _ in range(1)]) if False else 1)
        frames = {"impact": 6, "sparkle": 8, "dust": 6, "splash": 8, "flame": 6}[name]
        lib[name] = {"sheet": f"{name}.png", "frames": frames, "fps": fps, "additive": additive, "scale": 2, "offset_y": oy}
        print(f"  {name}.png {s.size} {frames} frames")
    (DST / "effects.json").write_text(json.dumps(lib, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
