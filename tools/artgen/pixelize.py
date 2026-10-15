"""Turn a raw generation into clean game pixel art.

usage:
  python tools/artgen/pixelize.py in.png out.png --px 8 [--colors 32] [--cut-bg 40] [--crop x0 y0 x1 y1]
                                   [--size W H] [--palette pal.png] [--outline]

  --px N        source pixels per art pixel (the LoRA draws ~8px blocks at 1024 scale)
  --size W H    final art size instead of --px (box downscale to exactly W x H)
  --colors N    quantise to N colours (no dithering)
  --palette     quantise to the colours of an existing palette image instead (keeps a stage cohesive)
  --cut-bg T    make the flat background transparent: flood from the border, colour distance <= T
  --outline     add a 1px dark outline round the opaque silhouette (sprites)

Output is always exact: hard alpha (0 or 255), no partially transparent or blended pixels.
"""
from __future__ import annotations

import argparse
from collections import deque

import numpy as np
from PIL import Image


def snap(img: Image.Image, px: int | None, size: tuple[int, int] | None) -> Image.Image:
    if size:
        w, h = size
    else:
        w, h = img.width // px, img.height // px
    # Median-ish downscale: box average, then the quantiser pulls colours back onto clusters.
    return img.convert("RGB").resize((w, h), Image.BOX)


def quantise(img: Image.Image, colors: int, palette: str | None) -> Image.Image:
    if palette:
        pal_img = Image.open(palette).convert("RGB")
        cols = list(dict.fromkeys(pal_img.getdata()))[:256]
        p = Image.new("P", (1, 1))
        flat = [c for rgb in cols for c in rgb]
        p.putpalette(flat + flat[:3] * (256 - len(cols)))
        return img.quantize(palette=p, dither=Image.Dither.NONE).convert("RGB")
    return img.quantize(colors=colors, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert("RGB")


def cut_background(img: Image.Image, tol: float) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    h, w, _ = a.shape
    keep = np.ones((h, w), bool)
    seen = np.zeros((h, w), bool)
    q: deque = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        if seen[y, x]:
            continue
        seen[y, x] = True
        ref = a[y, x]
        keep[y, x] = False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < w and 0 <= yy < h and not seen[yy, xx] and np.abs(a[yy, xx] - ref).sum() <= tol:
                q.append((xx, yy))
    rgba = np.dstack([a.astype(np.uint8), (keep * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def cut_sky(img: Image.Image, border: int = 2, lum_min: float = 118) -> Image.Image:
    """Backdrop layers: per column, clear the generator's border rows, then bright sky / cloud /
    haze pixels from the top down until the first darker land pixel (forest, towers, roofs)."""
    a = np.asarray(img.convert("RGBA")).copy()
    h, w, _ = a.shape
    rgb = a[:, :, :3].astype(float)
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    skyish = (lum >= lum_min) & (sat < 110)
    depth = np.zeros(w, int)
    for x in range(w):
        y = 0
        while y < h and (y < border or skyish[y, x]):
            y += 1
        depth[x] = y
    # Thin slivers (<= 2 px wide) where the scan stopped early on haze: take the local median.
    pad = np.pad(depth, 2, mode="edge")
    med = np.array([int(np.median(pad[x:x + 5])) for x in range(w)])
    depth = np.maximum(depth, med)
    for x in range(w):
        a[:depth[x], x, 3] = 0
    return Image.fromarray(a, "RGBA")


def outline(img: Image.Image, color=(32, 20, 30)) -> Image.Image:
    a = np.asarray(img).copy()
    alpha = a[:, :, 3] > 0
    grow = np.zeros_like(alpha)
    grow[1:, :] |= alpha[:-1, :]
    grow[:-1, :] |= alpha[1:, :]
    grow[:, 1:] |= alpha[:, :-1]
    grow[:, :-1] |= alpha[:, 1:]
    ring = grow & ~alpha
    a[ring] = (*color, 255)
    return Image.fromarray(a, "RGBA")


def defringe(img: Image.Image, passes: int = 2, lum: int = 175) -> Image.Image:
    """Strip light, desaturated pixels on the silhouette edge (leftover background halo)."""
    a = np.asarray(img).copy()
    for _ in range(passes):
        al = a[:, :, 3] > 0
        edge = np.zeros_like(al)
        edge[1:, :] |= ~al[:-1, :]
        edge[:-1, :] |= ~al[1:, :]
        edge[:, 1:] |= ~al[:, :-1]
        edge[:, :-1] |= ~al[:, 1:]
        rgb = a[:, :, :3].astype(int)
        mx, mn = rgb.max(2), rgb.min(2)
        pale = (mx > lum) & ((mx - mn) < 0.22 * mx)
        a[al & edge & pale, 3] = 0
    return Image.fromarray(a, "RGBA")


def despeckle(img: Image.Image) -> Image.Image:
    """Remove isolated opaque pixels and fill single-pixel holes."""
    a = np.asarray(img).copy()
    al = a[:, :, 3] > 0
    n = np.zeros(al.shape, int)
    n[1:, :] += al[:-1, :]
    n[:-1, :] += al[1:, :]
    n[:, 1:] += al[:, :-1]
    n[:, :-1] += al[:, 1:]
    a[al & (n == 0), 3] = 0
    return Image.fromarray(a, "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--px", type=int)
    ap.add_argument("--size", type=int, nargs=2)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--palette")
    ap.add_argument("--cut-bg", type=float)
    ap.add_argument("--crop", type=int, nargs=4)
    ap.add_argument("--outline", action="store_true")
    a = ap.parse_args()
    img = Image.open(a.src).convert("RGB")
    if a.crop:
        img = img.crop(tuple(a.crop))
    small = quantise(snap(img, a.px, tuple(a.size) if a.size else None), a.colors, a.palette)
    out = cut_background(small, a.cut_bg) if a.cut_bg is not None else small.convert("RGBA")
    out = despeckle(out)
    if a.outline:
        out = outline(out)
    out.save(a.dst)
    print(a.dst, out.size)


if __name__ == "__main__":
    main()
