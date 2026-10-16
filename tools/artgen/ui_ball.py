"""Golf ball sprite: a small pre-rendered sphere, snapped to a hand-tuned colour ramp.

At 18 art px a golf ball is a lit disc with a pattern of 1 px dimples. Generated art does not
survive a downscale that far, so the ball is pre-rendered the way pixel artists pre-render small
rotating props: a sphere with a fixed top-left light, a Fibonacci dimple pattern on its surface,
banded into a 5-tone hue-shifted ramp (no blending), with the shared ink outline. The spin strip
rotates only the dimple pattern (and the printed seam) about the screen axis while the lighting
stays put, which is what a rolling ball looks like from the side.

Used by build_ui.py; it can also be run on its own to write the three ball files.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

INK = (32, 20, 30)
# Ramp for the white ball, light to dark. Highlights lean warm, shadows lean cool/purple
# (ART_STYLE_GUIDE.md section 3).
RAMP_WHITE = [(255, 255, 250), (240, 238, 232), (214, 216, 228), (170, 174, 200), (118, 116, 152)]
# Neutral ramp for modulate tinting: mostly light so the chosen colour reads at full strength.
RAMP_TINT = [(255, 255, 255), (232, 232, 232), (200, 200, 200), (152, 152, 152), (104, 104, 104)]

SIZE = 18          # canvas, art px
RADIUS = 8.0       # sphere radius in art px (diameter 16 + 1 px outline each side)
FRAMES = 8         # spin frames over one full turn (45 degrees each)
SS = 6             # supersampling for dimple coverage
LIGHT = np.array([-0.55, -0.62, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def _fib_sphere(n: int) -> np.ndarray:
    i = np.arange(n) + 0.5
    phi = np.arccos(1 - 2 * i / n)
    th = math.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], -1)


DIMPLES = _fib_sphere(52)
SEAM = [(math.cos(t), math.sin(t), 0.0) for t in np.linspace(-0.5, 0.5, 5)]  # unused marker


def _tone(px_: float, py_: float) -> int:
    nz = math.sqrt(max(0.0, 1 - px_ * px_ - py_ * py_))
    lam = px_ * LIGHT[0] + py_ * LIGHT[1] + nz * LIGHT[2]
    v = lam
    # specular: a small hot spot near the top-left
    if math.hypot(px_ + 0.38, py_ + 0.42) < 0.24:
        return 0
    if v > 0.62:
        return 1
    if v > 0.18:
        return 2
    # reflected light: one band lighter on the extreme lower-right rim
    if v <= 0.18 and (px_ * 0.6 + py_ * 0.8) > 0.0 and px_ * px_ + py_ * py_ > 0.8 and v > -0.45:
        return 3 if v < -0.1 else 3
    if v > -0.25:
        return 3
    return 4


def render(angle_deg: float, ramp: list[tuple], seam: bool = True) -> Image.Image:
    """One frame. angle_deg turns the surface pattern clockwise on screen (y down)."""
    c = SIZE / 2
    tone = np.full((SIZE, SIZE), -1, int)
    for y in range(SIZE):
        for x in range(SIZE):
            px_, py_ = (x + 0.5 - c) / RADIUS, (y + 0.5 - c) / RADIUS
            if px_ * px_ + py_ * py_ <= 1.0:
                tone[y, x] = _tone(px_, py_)
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    # Dimples: each visible dimple centre darkens exactly one pixel (one step), skipping the
    # foreshortened limb and the specular spot, so the pattern stays a clean dot grid.
    for d in DIMPLES:
        x3, y3, z3 = d
        if z3 < 0.36:
            continue
        rx, ry = x3 * ca - y3 * sa, x3 * sa + y3 * ca
        ix, iy = int(math.floor(c + rx * RADIUS)), int(math.floor(c + ry * RADIUS))
        if 0 <= ix < SIZE and 0 <= iy < SIZE and tone[iy, ix] >= 1:
            tone[iy, ix] = min(4, tone[iy, ix] + 1)
    if seam:
        # printed seam: short dark arc that makes the rotation readable at a glance
        for t in np.linspace(-0.42, 0.42, 9):
            ang = -2.3 + t + a
            rr = 0.62
            ix, iy = int(math.floor(c + math.cos(ang) * rr * RADIUS)), int(math.floor(c + math.sin(ang) * rr * RADIUS))
            if tone[iy, ix] >= 0:
                tone[iy, ix] = 4 if tone[iy, ix] >= 2 else 3
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    for y in range(SIZE):
        for x in range(SIZE):
            if tone[y, x] >= 0:
                out[y, x] = (*ramp[tone[y, x]], 255)
    return _outline(Image.fromarray(out, "RGBA"))


def _outline(img: Image.Image) -> Image.Image:
    a = np.asarray(img).copy()
    al = a[:, :, 3] > 0
    g = np.zeros_like(al)
    g[1:] |= al[:-1]
    g[:-1] |= al[1:]
    g[:, 1:] |= al[:, :-1]
    g[:, :-1] |= al[:, 1:]
    a[g & ~al] = (*INK, 255)
    return Image.fromarray(a, "RGBA")


def strip(ramp: list[tuple]) -> Image.Image:
    s = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for i in range(FRAMES):
        s.alpha_composite(render(i * 360 / FRAMES, ramp), (i * SIZE, 0))
    return s


def build(dst) -> None:
    from pathlib import Path
    dst = Path(dst)
    dst.mkdir(parents=True, exist_ok=True)
    render(0, RAMP_WHITE).save(dst / "ball.png")
    strip(RAMP_WHITE).save(dst / "ball_spin.png")
    render(0, RAMP_TINT).save(dst / "ball_tint.png")
    strip(RAMP_TINT).save(dst / "ball_tint_spin.png")


if __name__ == "__main__":
    import sys
    build(sys.argv[1] if len(sys.argv) > 1 else "client/assets/ui/ball")
