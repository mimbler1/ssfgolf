"""v4 golfer pose guides: a shaded, outlined pixel mannequin per keyframe at full frame size.

The guide is what the generator paints over (tools/artgen/g4_gen.py). Unlike the v3 flat guides
it is drawn at the final art resolution (96 x 128 frame, body about 84 px tall) with cel-shaded
volumes, so the paint-over keeps the pose, the club and the body-part layout exactly and the
model spends its effort on detail, shading and faces.

Coordinates: art px relative to the pivot (ground point between the feet), +x = facing side,
y up = negative. Frame pivot is (48, 124) like every sprite character (docs/SPRITE_PIPELINE.md).
"""
from __future__ import annotations

import colorsys
import math
from typing import Callable

import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 96, 128
PIV = (48, 124)
SS = 4                     # supersampling for shape coverage
GEN_SCALE = 8              # generator px per art px
OUTLINE = (32, 20, 30)
LIGHT = np.array([-0.62, -0.78])   # towards the light (top-left), screen coords (y down)

# Fine sample grid in art-px frame coordinates.
_fy, _fx = np.mgrid[0:H * SS, 0:W * SS]
FX = (_fx + 0.5) / SS
FY = (_fy + 0.5) / SS


def A(p) -> np.ndarray:
    """Pose point (relative to pivot) -> absolute frame coords."""
    return np.array([PIV[0] + p[0], PIV[1] + p[1]], float)


# ---------------------------------------------------------------- shapes (fine-grid masks)

def capsule(a, b, r0: float, r1: float | None = None) -> np.ndarray:
    a, b = A(a), A(b)
    r1 = r0 if r1 is None else r1
    d = b - a
    L2 = max(float(d @ d), 1e-6)
    t = np.clip(((FX - a[0]) * d[0] + (FY - a[1]) * d[1]) / L2, 0, 1)
    px, py = a[0] + t * d[0], a[1] + t * d[1]
    return np.hypot(FX - px, FY - py) <= r0 + (r1 - r0) * t


def chain(pts, radii) -> np.ndarray:
    m = np.zeros(FX.shape, bool)
    for i in range(len(pts) - 1):
        m |= capsule(pts[i], pts[i + 1], radii[i], radii[i + 1])
    return m


def ellipse(c, rx: float, ry: float, ang: float = 0.0) -> np.ndarray:
    c = A(c)
    ca, sa = math.cos(ang), math.sin(ang)
    x, y = FX - c[0], FY - c[1]
    u, v = x * ca + y * sa, -x * sa + y * ca
    return (u / rx) ** 2 + (v / ry) ** 2 <= 1.0


def poly(pts) -> np.ndarray:
    """Even-odd point-in-polygon on the fine grid."""
    P = [A(p) for p in pts]
    inside = np.zeros(FX.shape, bool)
    n = len(P)
    for i in range(n):
        (x1, y1), (x2, y2) = P[i], P[(i + 1) % n]
        if y1 == y2:
            continue
        cond = ((y1 > FY) != (y2 > FY))
        xint = (x2 - x1) * (FY - y1) / (y2 - y1) + x1
        inside ^= cond & (FX < xint)
    return inside


def to_art(m: np.ndarray) -> np.ndarray:
    return m.reshape(H, SS, W, SS).mean((1, 3)) >= 0.5


# ---------------------------------------------------------------- colour ramps

def ramp(hex_or_rgb, n: int = 5) -> list[tuple[int, int, int]]:
    """Hue-shifted ramp [deep, shadow, base, light, highlight]: shadows lean purple-blue,
    highlights lean warm (ART_STYLE_GUIDE.md section 3)."""
    if isinstance(hex_or_rgb, str):
        h = hex_or_rgb.lstrip("#")
        rgb = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    else:
        rgb = hex_or_rgb
    hh, ss, vv = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))

    def shift(h, target, amt):
        d = ((target - h + 0.5) % 1.0) - 0.5
        return (h + d * amt) % 1.0

    def mk(h, s, v):
        r, g, b = colorsys.hsv_to_rgb(h, min(max(s, 0), 1), min(max(v, 0), 1))
        return (round(r * 255), round(g * 255), round(b * 255))
    cool, warm = 0.72, 0.14
    grey = ss < 0.12
    return [
        mk(shift(hh, cool, 0.0 if grey else 0.22), ss + (0.10 if not grey else 0.08), vv * 0.50),
        mk(shift(hh, cool, 0.0 if grey else 0.11), ss + (0.06 if not grey else 0.05), vv * 0.72),
        mk(hh, ss, vv),
        mk(shift(hh, warm, 0.0 if grey else 0.08), ss * 0.88, vv * 1.10 + 0.04),
        mk(shift(hh, warm, 0.0 if grey else 0.16), ss * 0.62, vv * 1.18 + 0.10),
    ]


# ---------------------------------------------------------------- render

class Part:
    def __init__(self, name: str, mask: np.ndarray, color, shade: bool = True, line: bool = True):
        self.name, self.mask, self.color, self.shade, self.line = name, mask, color, shade, line


def render(parts: list[Part], dots: list[tuple] = ()) -> tuple[Image.Image, np.ndarray]:
    """Composite parts back to front with pillow shading and selective outlines.
    Returns (RGBA art-px image, part-index map, -1 = empty)."""
    img = np.zeros((H, W, 4), np.uint8)
    idx = -np.ones((H, W), int)
    tone = np.zeros((H, W), int)
    ramps = []
    for i, p in enumerate(parts):
        m = to_art(p.mask)
        if not m.any():
            ramps.append(None)
            continue
        rp = ramp(p.color) if p.shade else [p.color if not isinstance(p.color, str) else ramp(p.color)[2]] * 5
        ramps.append(rp)
        if p.shade:
            blur = ndimage.gaussian_filter(m.astype(float), 1.6)
            gy, gx = np.gradient(blur)
            nx, ny = -gx, -gy
            nn = np.hypot(nx, ny) + 1e-6
            dist = ndimage.distance_transform_edt(m)
            lit = (nx * LIGHT[0] + ny * LIGHT[1]) / nn * np.exp(-(dist - 1) / 3.2)
            t = np.full(m.shape, 2)
            t[lit > 0.30] = 3
            t[lit > 0.62] = 4
            t[lit < -0.25] = 1
            t[lit < -0.62] = 0
        else:
            t = np.full(m.shape, 2)
        idx[m] = i
        tone[m] = t[m]
    for i, rp in enumerate(ramps):
        if rp is None:
            continue
        sel = idx == i
        for k in range(5):
            img[sel & (tone == k)] = (*rp[k], 255)
    # selective interior lines: a front part's pixels bordering a part drawn behind it
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.roll(np.roll(idx, dy, 0), dx, 1)
        edge = (idx >= 0) & (nb >= 0) & (nb < idx)
        for i, rp in enumerate(ramps):
            if rp is None or not parts[i].line:
                continue
            img[edge & (idx == i)] = (*rp[0], 255)
    for (x, y, c) in dots:
        X, Y = int(PIV[0] + x), int(PIV[1] + y)
        if 0 <= X < W and 0 <= Y < H:
            img[Y, X] = (*c, 255)
    # silhouette outline ring
    al = img[:, :, 3] > 0
    grow = ndimage.binary_dilation(al, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool))
    img[grow & ~al] = (*OUTLINE, 255)
    return Image.fromarray(img, "RGBA"), idx


def upscale(img: Image.Image, bg=(236, 236, 240)) -> Image.Image:
    out = Image.new("RGBA", img.size, (*bg, 255))
    out.alpha_composite(img)
    return out.convert("RGB").resize((img.width * GEN_SCALE, img.height * GEN_SCALE), Image.NEAREST)


def club_point(hd, ang_deg: float, length: float) -> tuple[float, float]:
    a = math.radians(ang_deg)
    return (hd[0] + length * math.cos(a), hd[1] + length * math.sin(a))


def rot(p, c, ang_deg: float):
    """Rotate pose point p about c (screen coords, degrees clockwise)."""
    a = math.radians(ang_deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def head_local(pose: dict, x: float, y: float, scale: float = 1.0):
    """Point in the head's frame (x forward, y down, head radius units) -> pose coords."""
    hx, hy = pose["head"]
    t = math.radians(pose.get("tilt", 0.0))
    return (hx + (x * math.cos(t) - y * math.sin(t)) * scale, hy + (x * math.sin(t) + y * math.cos(t)) * scale)


Feature = Callable[[dict, dict], list]
