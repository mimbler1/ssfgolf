"""Cut a generated prop sheet into individual sprites (one per connected opaque island).

usage: python tools/artgen/extract_sprites.py sheet.png out_dir --px 8 [--cut-bg 60] [--min 6] [--colors 48]
Writes out_dir/<n>_<w>x<h>.png plus out_dir/_index.png (numbered contact sheet) for picking.
"""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import pixelize as px


def islands(alpha: np.ndarray) -> list[tuple[int, int, int, int]]:
    h, w = alpha.shape
    seen = np.zeros_like(alpha, bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if alpha[y, x] and not seen[y, x]:
                q = deque([(x, y)])
                seen[y, x] = True
                x0 = x1 = x
                y0 = y1 = y
                while q:
                    cx, cy = q.popleft()
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                q.append((nx, ny))
                boxes.append((x0, y0, x1 + 1, y1 + 1))
    return boxes


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--px", type=int, default=8)
    ap.add_argument("--cut-bg", type=float, default=60)
    ap.add_argument("--min", type=int, default=6)
    ap.add_argument("--colors", type=int, default=48)
    ap.add_argument("--fringe", type=int, default=175, help="edge pixels brighter than this and greyish are removed")
    ap.add_argument("--fringe-passes", type=int, default=2)
    a = ap.parse_args()
    img = Image.open(a.src).convert("RGB")
    small = px.quantise(px.snap(img, a.px, None), a.colors, None)
    cut = px.despeckle(px.defringe(px.cut_background(small, a.cut_bg), a.fringe_passes, a.fringe))
    arr = np.asarray(cut)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    tiles = []
    for i, (x0, y0, x1, y1) in enumerate(islands(arr[:, :, 3] > 0)):
        if x1 - x0 < a.min or y1 - y0 < a.min:
            continue
        spr = cut.crop((x0, y0, x1, y1))
        spr.save(out / f"{i:03d}_{x1 - x0}x{y1 - y0}.png")
        tiles.append((i, spr))
    # numbered index at 4x for review
    k = 4
    W = 1200
    x = y = rowh = 0
    sheet = Image.new("RGBA", (W, 4000), (40, 44, 56, 255))
    d = ImageDraw.Draw(sheet)
    for i, s in tiles:
        b = s.resize((s.width * k, s.height * k), Image.NEAREST)
        if x + b.width + 8 > W:
            x, y, rowh = 0, y + rowh + 20, 0
        sheet.alpha_composite(b, (x, y + 14))
        d.text((x, y), str(i), fill=(255, 255, 0, 255))
        x += b.width + 8
        rowh = max(rowh, b.height + 14)
    sheet.crop((0, 0, W, y + rowh + 20)).save(out / "_index.png")
    print(len(tiles), "sprites ->", out)


if __name__ == "__main__":
    main()
