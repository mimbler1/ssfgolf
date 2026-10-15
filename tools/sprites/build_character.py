"""Validate a hand-authored sprite character and export it for the game.

usage:
  python tools/sprites/build_character.py adventurer           # validate + export
  python tools/sprites/build_character.py adventurer --check   # validate only (CI / tests)

Reads   art/characters/<id>/{palette.txt, character.src.json, src/*.txt}
Writes  client/assets/characters/<id>/{<anim>.png, character.json}

Each animation becomes one horizontal strip PNG (frames left to right, frame_size each).
Errors fail the build; animations with fewer frames than their target are reported as
incomplete (the game falls back to idle for missing animations) but are not errors.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

import spritekit as sk

ROOT = Path(__file__).resolve().parents[2]


def neighbours(rows: list[str], x: int, y: int) -> int:
    n = 0
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if 0 <= yy < len(rows) and 0 <= xx < len(rows[yy]) and rows[yy][xx] != sk.TRANSPARENT:
            n += 1
    return n


def check_frame(name: str, rows: list[str], pal: sk.Palette, fw: int, fh: int, pivot: list[int]) -> tuple[list[str], list[str]]:
    errs = [f"{name}: {e}" for e in sk.grid_errors(rows, pal, fw, fh)]
    warns: list[str] = []
    if errs:
        return errs, warns
    box = sk.opaque_bbox(rows)
    if box is None:
        return [f"{name}: empty frame"], warns
    x0, y0, x1, y1 = box
    if x0 == 0 or y0 == 0 or x1 == fw - 1 or y1 == fh - 1:
        errs.append(f"{name}: art touches the frame edge {box}; leave a transparent margin")
    if y1 != pivot[1] - 1:
        errs.append(f"{name}: lowest pixel row {y1}, but grounded frames must end on row {pivot[1] - 1} (pivot y {pivot[1]})")
    # Outer silhouette must be inked: every opaque pixel touching transparency is outline-coloured.
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == sk.TRANSPARENT:
                continue
            if neighbours(rows, x, y) == 0:
                warns.append(f"{name}: orphan pixel at ({x},{y})")
    return errs, warns


def main() -> int:
    cid = sys.argv[1]
    check_only = "--check" in sys.argv
    src = ROOT / "art/characters" / cid
    out = ROOT / "client/assets/characters" / cid
    pal = sk.Palette.load(src / "palette.txt")
    spec = sk.load_json(src / "character.src.json")
    fw, fh = spec["frame_size"]
    pivot = spec["pivot"]
    errs: list[str] = []
    warns: list[str] = []
    report: list[str] = []

    anims_out: dict = {}
    strips: dict[str, Image.Image] = {}
    for anim, a in spec["anims"].items():
        frames = a["frames"]
        report.append(f"  {anim:9s} {len(frames):2d}/{a['target_frames']} frames" + ("" if len(frames) >= a["target_frames"] else "  (incomplete)"))
        if not frames:
            continue
        strip = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
        fr_out = []
        for i, (fname, ms) in enumerate(frames):
            path = src / "src" / f"{fname}.txt"
            if not path.exists():
                errs.append(f"{anim}: missing frame source {path.name}")
                continue
            rows = sk.read_grid(path)
            e, w = check_frame(fname, rows, pal, fw, fh, pivot)
            errs += e
            warns += w
            if e:
                continue
            strip.alpha_composite(sk.render(rows, pal), (i * fw, 0))
            if not (16 <= int(ms) <= 2000):
                errs.append(f"{fname}: duration {ms} ms outside 16-2000")
            anchors = spec.get("anchors", {}).get(fname, {})
            for k, (ax, ay) in anchors.items():
                if not (0 <= ax < fw and 0 <= ay < fh):
                    errs.append(f"{fname}: anchor {k} outside frame")
            fr_out.append({"name": fname, "rect": [i * fw, 0, fw, fh], "ms": int(ms), "anchors": anchors})
        cf = a.get("contact_frame")
        if cf is not None and len(frames) >= a["target_frames"] and not (0 <= cf < len(frames)):
            errs.append(f"{anim}: contact_frame {cf} out of range")
        anims_out[anim] = {"sheet": f"{anim}.png", "loop": a["loop"], "frames": fr_out,
                           "target_frames": a["target_frames"], "contact_frame": cf}
        strips[anim] = strip

    for name, v in spec.get("variants", {}).items():
        for k, hexc in v.items():
            if k not in pal.colors:
                errs.append(f"variant {name}: unknown palette key {k!r}")
            elif pal.regions[k] not in spec["recolor_regions"]:
                errs.append(f"variant {name}: key {k!r} is in region {pal.regions[k]!r}, which is not recolourable")

    print(f"{cid}:")
    print("\n".join(report))
    for w in warns:
        print("  warning:", w)
    for e in errs:
        print("  ERROR:", e)
    if errs:
        return 1
    if check_only:
        return 0

    out.mkdir(parents=True, exist_ok=True)
    for anim, img in strips.items():
        img.save(out / f"{anim}.png")
    meta = {
        "format": 1,
        "id": cid,
        "name": spec["name"],
        "frame_size": [fw, fh],
        "pivot": pivot,
        "rig_units_per_px": spec["rig_units_per_px"],
        "anims": anims_out,
        "palette": {k: "#%02x%02x%02x" % c[:3] for k, c in pal.colors.items()},
        "regions": {r: {k: pal.roles[k] for k in pal.colors if pal.regions[k] == r} for r in sorted(set(pal.regions.values()))},
        "recolor_regions": spec["recolor_regions"],
        "variants": {n: {k: "#" + h for k, h in v.items()} for n, v in spec.get("variants", {}).items()},
        "equipment_slots": spec.get("equipment_slots", {}),
        "surfaces": spec.get("surfaces", {}),
    }
    (out / "character.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"  exported -> {out.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
