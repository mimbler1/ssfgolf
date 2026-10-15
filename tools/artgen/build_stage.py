"""Build a world theme's game assets from picked generations + hand-made sources.

usage: python tools/artgen/build_stage.py meadow [--check]

art/worlds/<theme>/stage.src.json:
  "assets": processed pictures
     {"out": "backdrop/sky.png", "src": "picks/x.png", "crop": [x0,y0,x1,y1], "px": 8 | "size": [w,h],
      "colors": 32, "cut_bg": 40, "fringe": 175, "outline": false}
  "strips": material cap strips cut from a built tile
     {"out": "terrain/cap_rock.png", "from": "terrain/rock.png", "rows": [y0, y1], "ink_top": true}
  "copy":   final hand-made / hand-picked files copied verbatim {"out": "...", "src": "..."}
  "world":  the world.json written next to the assets (paths relative to the world folder)

Raw picks live in art/worlds/<theme>/picks (committed) so builds never need the GPU.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize as px  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
INK = (32, 20, 30, 255)


def build_one(src_dir: Path, a: dict) -> Image.Image:
    img = Image.open(src_dir / a["src"]).convert("RGB")
    if a.get("crop"):
        img = img.crop(tuple(a["crop"]))
    small = px.snap(img, a.get("px"), tuple(a["size"]) if a.get("size") else None)
    if a.get("contrast") or a.get("brightness"):
        from PIL import ImageEnhance
        small = ImageEnhance.Contrast(small).enhance(float(a.get("contrast", 1.0)))
        small = ImageEnhance.Brightness(small).enhance(float(a.get("brightness", 1.0)))
    small = px.quantise(small, int(a.get("colors", 32)), None)
    if a.get("cut_sky"):
        out = px.cut_sky(small)
    elif a.get("cut_bg") is not None:
        out = px.defringe(px.cut_background(small, float(a["cut_bg"])), 2, int(a.get("fringe", 175)))
    else:
        out = small.convert("RGBA")
    out = px.despeckle(out)
    if a.get("outline"):
        out = px.outline(out)
    return out


def strip(dst: Path, s: dict) -> Image.Image:
    tile = Image.open(dst / s["from"]).convert("RGBA")
    y0, y1 = s["rows"]
    out = tile.crop((0, y0, tile.width, y1))
    if s.get("ink_top"):
        top = int(s.get("pad_top", 0))
        canvas = Image.new("RGBA", (out.width, out.height + top + 1), (0, 0, 0, 0))
        canvas.paste(out, (0, top + 1))
        for x in range(out.width):
            canvas.putpixel((x, top), INK)
        out = canvas
    return out


def referenced(world: dict) -> list[str]:
    refs: list[str] = []

    def walk(v):
        if isinstance(v, str) and v.endswith(".png"):
            refs.append(v)
        elif isinstance(v, dict):
            for x in v.values():
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
    walk(world)
    return refs


def main() -> int:
    theme = sys.argv[1]
    check = "--check" in sys.argv
    src_dir = ROOT / "art/worlds" / theme
    spec = json.loads((src_dir / "stage.src.json").read_text(encoding="utf-8"))
    dst = ROOT / "client/assets/worlds" / theme
    errs: list[str] = []
    for a in spec.get("assets", []):
        if not (src_dir / a["src"]).exists():
            errs.append(f"missing source {a['src']}")
            continue
        img = build_one(src_dir, a)
        if not check:
            (dst / a["out"]).parent.mkdir(parents=True, exist_ok=True)
            img.save(dst / a["out"])
            print(f"  {a['out']:34s} {img.size}")
    for c in spec.get("copy", []):
        srcs = sorted(src_dir.glob(c["src"])) if "*" in c["src"] else [src_dir / c["src"]]
        for s in srcs:
            if not s.exists():
                errs.append(f"missing copy source {c['src']}")
                continue
            out = dst / c["out"].replace("*", s.stem)
            if not check:
                out.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(s, out)
    if not check:
        for s in spec.get("strips", []):
            img = strip(dst, s)
            img.save(dst / s["out"])
            print(f"  {s['out']:34s} {img.size}")
    world = spec["world"]
    # Expand decor globs into explicit variant lists.
    for kind, v in list(world.get("decor", {}).items()):
        if isinstance(v, str):
            world["decor"][kind] = sorted(str(p.relative_to(dst)).replace("\\", "/") for p in dst.glob(v))
    if not check:
        (dst / "world.json").write_text(json.dumps(world, indent=1) + "\n", encoding="utf-8")
    for r in referenced(world):
        if not check and not (dst / r).exists():
            errs.append(f"world.json references missing {r}")
    for e in errs:
        print("  ERROR:", e)
    print(f"{theme}: {'ok' if not errs else 'FAILED'}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
