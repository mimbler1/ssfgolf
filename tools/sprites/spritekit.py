"""Sprite source format and rendering helpers.

A character lives in art/characters/<id>/:
  palette.txt          key -> RGBA, plus the recolour region each key belongs to
  src/<anim>_<NN>.txt  one frame: FRAME_H rows of FRAME_W palette keys ('.' = transparent)
  character.src.json   animation timing, pivots, club anchors, customisation regions

Every pixel in a frame is placed by hand in the grid; this module only reads, validates and
renders those grids. It never generates artwork.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

TRANSPARENT = "."


@dataclass
class Palette:
    colors: dict[str, tuple[int, int, int, int]]
    regions: dict[str, str]   # key -> region name (skin, hair, jacket...)
    roles: dict[str, str]     # key -> light / mid / shadow / deep / ink

    @staticmethod
    def load(path: Path) -> "Palette":
        colors, regions, roles = {}, {}, {}
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            key, hexc, region, role = line.split()
            if len(key) != 1 or key == TRANSPARENT or key in colors:
                raise ValueError(f"{path}: bad or duplicate key {key!r}")
            colors[key] = tuple(int(hexc[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
            regions[key] = region
            roles[key] = role
        return Palette(colors, regions, roles)


def read_grid(path: Path) -> list[str]:
    rows = [r.rstrip("\n") for r in path.read_text(encoding="utf-8").splitlines()]
    return [r for r in rows if not r.startswith(";")]


def write_grid(path: Path, rows: list[str]) -> None:
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def grid_errors(rows: list[str], pal: Palette, w: int, h: int) -> list[str]:
    errs = []
    if len(rows) != h:
        errs.append(f"{len(rows)} rows, expected {h}")
    for y, r in enumerate(rows):
        if len(r) != w:
            errs.append(f"row {y}: {len(r)} columns, expected {w}")
        bad = {c for c in r if c != TRANSPARENT and c not in pal.colors}
        if bad:
            errs.append(f"row {y}: unknown keys {sorted(bad)}")
    return errs


def render(rows: list[str], pal: Palette, recolor: dict[str, tuple] | None = None) -> Image.Image:
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != TRANSPARENT:
                px[x, y] = (recolor or {}).get(c, pal.colors[c])
    return img


def opaque_bbox(rows: list[str]) -> tuple[int, int, int, int] | None:
    """(x0, y0, x1, y1) inclusive bounds of non-transparent pixels."""
    pts = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c != TRANSPARENT]
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def stamp(canvas: list[list[str]], part: list[str], ox: int, oy: int) -> None:
    """Composite a hand-drawn part grid onto a canvas ('.' leaves what is below)."""
    for y, r in enumerate(part):
        for x, c in enumerate(r):
            if c != TRANSPARENT and 0 <= oy + y < len(canvas) and 0 <= ox + x < len(canvas[0]):
                canvas[oy + y][ox + x] = c


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))
