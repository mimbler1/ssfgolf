"""Turn picked generations into finished stage decor sprites (art/worlds/<theme>/hand/decor/).

usage:
  tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/beach/decor.picks.json [--only name]

A picks file is a list of
  {"out": "palm_a", "src": "art/worlds/beach/picks/beach_palm_3805.png",
   "crop": [x0, y0, x1, y1],      # source px, optional
   "height": 96 | "px": 8,         # final art size (height keeps aspect) or source px per art px
   "colors": 32, "cut_bg": 40, "fringe": 175,
   "island": "largest" | "all",    # keep only the largest opaque island (drops stray bits)
   "unshadow": true,               # strip a flat drop shadow painted under the object
   "key": "red",                   # chroma-key a red background instead of the border flood
   "fringe_hue": true,             # strip red-tinted edge pixels (red generation background)
   "snowcap": true,                # pile snow on top
   "outline": true, "flip": false}

Everything is deterministic, so `hand/decor` can always be rebuilt from `picks/` + this file.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize as px  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def largest_island(img: Image.Image) -> Image.Image:
    a = np.asarray(img).copy()
    al = a[:, :, 3] > 0
    h, w = al.shape
    lab = np.zeros((h, w), int)
    best, best_n, cur = 0, 0, 0
    for y in range(h):
        for x in range(w):
            if al[y, x] and not lab[y, x]:
                cur += 1
                n = 0
                q = deque([(x, y)])
                lab[y, x] = cur
                while q:
                    cx, cy = q.popleft()
                    n += 1
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and al[ny, nx] and not lab[ny, nx]:
                                lab[ny, nx] = cur
                                q.append((nx, ny))
                if n > best_n:
                    best, best_n = cur, n
    a[lab != best, 3] = 0
    return Image.fromarray(a, "RGBA")


def unshadow(img: Image.Image, sat_max: int = 34) -> Image.Image:
    """A painted drop shadow is a flat, greyish colour band hugging the lower silhouette. Collect
    greyish colours on the lower outer edge, then peel them from the outside in."""
    a = np.asarray(img).copy()
    h, w, _ = a.shape
    al = a[:, :, 3] > 0
    rgb = a[:, :, :3].astype(int)
    sat = rgb.max(2) - rgb.min(2)
    lum = rgb.mean(2)
    edge = np.zeros_like(al)
    edge[1:, :] |= ~al[:-1, :]
    edge[:-1, :] |= ~al[1:, :]
    edge[:, 1:] |= ~al[:, :-1]
    edge[:, :-1] |= ~al[:, 1:]
    lower = np.zeros_like(al)
    lower[int(h * 0.45):, :] = True
    cand = al & edge & lower & (sat <= sat_max)
    if not cand.any():
        return img
    cols = {tuple(c) for c in rgb[cand]}
    # Shadows are mid-light; keep very dark colours (outline / crevices).
    cols = {c for c in cols if sum(c) / 3 > 70}
    in_set = np.zeros_like(al)
    for c in cols:
        in_set |= (rgb == np.array(c)).all(2)
    in_set &= al & lower
    q = deque(zip(*np.nonzero(in_set & edge)))
    while q:
        y, x = q.popleft()
        if not a[y, x, 3]:
            continue
        a[y, x, 3] = 0
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and a[yy, xx, 3] and in_set[yy, xx]:
                q.append((yy, xx))
    del lum
    return Image.fromarray(a, "RGBA")


def defringe_hue(img: Image.Image, passes: int = 2, margin: int = 40) -> Image.Image:
    """Strip edge pixels tinted by a coloured (red) generation background."""
    a = np.asarray(img).copy()
    for _ in range(passes):
        al = a[:, :, 3] > 0
        edge = np.zeros_like(al)
        edge[1:, :] |= ~al[:-1, :]
        edge[:-1, :] |= ~al[1:, :]
        edge[:, 1:] |= ~al[:, :-1]
        edge[:, :-1] |= ~al[:, 1:]
        rgb = a[:, :, :3].astype(int)
        red = (rgb[:, :, 0] > rgb[:, :, 1] + margin) & (rgb[:, :, 0] > rgb[:, :, 2] + margin)
        a[al & edge & red, 3] = 0
    return Image.fromarray(a, "RGBA")


def snowcap(img: Image.Image, depth: int = 2) -> Image.Image:
    """Pile snow on the top surface of a sprite (light from top-left)."""
    a = np.asarray(img).copy()
    h, w, _ = a.shape
    for x in range(w):
        ys = np.nonzero(a[:, x, 3])[0]
        if len(ys) == 0:
            continue
        for k in range(depth + (1 if x % 5 == 2 else 0)):
            y = ys[0] + k
            if y < h and a[y, x, 3]:
                a[y, x, :3] = (255, 255, 255) if k == 0 else (222, 232, 250)
    return Image.fromarray(a, "RGBA")


def make(p: dict) -> Image.Image:
    img = Image.open(ROOT / p["src"]).convert("RGB")
    if p.get("crop"):
        img = img.crop(tuple(p["crop"]))
    size = None
    if p.get("height"):
        size = (max(1, round(img.width * p["height"] / img.height)), int(p["height"]))
    small = px.snap(img, p.get("px", 8), size)
    small = px.quantise(small, int(p.get("colors", 32)), None)
    if p.get("key") == "red":
        # Chroma key: a red generation background that is not flat (snowfall, gradients).
        rgb = np.asarray(small).astype(int)
        red = (rgb[:, :, 0] > rgb[:, :, 1] + 45) & (rgb[:, :, 0] > rgb[:, :, 2] + 30)
        out = Image.fromarray(np.dstack([rgb.astype(np.uint8), (~red * 255).astype(np.uint8)]), "RGBA")
    else:
        out = px.defringe(px.cut_background(small, float(p.get("cut_bg", 40))), 2, int(p.get("fringe", 175)))
    out = px.despeckle(out)
    if p.get("island", "largest") == "largest":
        out = largest_island(out)
    if p.get("fringe_hue"):
        out = largest_island(px.despeckle(defringe_hue(out)))
    if p.get("unshadow"):
        out = unshadow(out, int(p.get("shadow_sat", 34)))
        out = largest_island(px.despeckle(out))
    if p.get("snowcap"):
        out = snowcap(out)
    if p.get("outline", True):
        out = px.outline(out)
    if out.getbbox():
        out = out.crop(out.getbbox())
    if p.get("flip"):
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("picks")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--preview")
    a = ap.parse_args()
    path = ROOT / a.picks if not Path(a.picks).is_absolute() else Path(a.picks)
    picks = json.loads(path.read_text(encoding="utf-8"))
    dst = path.parent / "hand" / "decor"
    dst.mkdir(parents=True, exist_ok=True)
    made = []
    for p in picks:
        if a.only and p["out"] not in a.only:
            continue
        img = make(p)
        img.save(dst / f"{p['out']}.png")
        made.append(img)
        print(f"  {p['out']:24s} {img.size}")
    if a.preview and made:
        k = 3
        W = sum(m.width * k + 10 for m in made) + 10
        H = max(m.height * k for m in made) + 20
        sheet = Image.new("RGBA", (W, H), (110, 130, 160, 255))
        x = 10
        for m in made:
            sheet.alpha_composite(m.resize((m.width * k, m.height * k), Image.NEAREST), (x, H - 10 - m.height * k))
            x += m.width * k + 10
        sheet.save(a.preview)


if __name__ == "__main__":
    main()
