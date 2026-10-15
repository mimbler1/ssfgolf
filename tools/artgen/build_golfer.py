"""Build a playable sprite golfer from a painted pose sheet (see pose_sheet.py).

usage: python tools/artgen/build_golfer.py <id> "<Display Name>" <painted.png> [--variant name]

Writes client/assets/characters/<id>/{idle.png, swing.png, character.json}, the same format
tools/sprites/build_character.py produces, so SpriteCharacter loads both.
Each frame is grounded (lowest opaque row moved onto the pivot row) so feet never jitter.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize as px  # noqa: E402
import pose_sheet as ps  # noqa: E402

SHAFT = (206, 214, 226, 255)
SHAFT_DARK = (120, 130, 150, 255)
GRIP = (52, 44, 64, 255)
HEAD = [(232, 238, 246, 255), (150, 160, 178, 255), (96, 104, 124, 255)]


def draw_club(fr: Image.Image, grip: list[int], head: list[int]) -> Image.Image:
    """Crisp authored club along the frame's grip->head anchors, composited behind the body so
    the hands overlap the grip. Same geometry the pose guide used, so it matches the painting."""
    club = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    gx, gy = grip
    hx, hy = head
    n = max(abs(hx - gx), abs(hy - gy), 1)
    for t in range(n + 1):
        x = round(gx + (hx - gx) * t / n)
        y = round(gy + (hy - gy) * t / n)
        if 0 <= x < fr.width and 0 <= y < fr.height:
            club.putpixel((x, y), GRIP if t < n * 0.22 else SHAFT)
            if t >= n * 0.22 and 0 <= y + 1 < fr.height and club.getpixel((x, y + 1))[3] == 0:
                club.putpixel((x, y + 1), SHAFT_DARK)
    # iron head: 4x3 blade, toe pointing away from the shaft direction
    dx = 1 if hx >= gx else -1
    for yy in range(3):
        for xx in range(4):
            x, y = hx + dx * (xx - 1), hy - 1 + yy
            if 0 <= x < fr.width and 0 <= y < fr.height:
                club.putpixel((x, y), HEAD[0] if yy == 0 else HEAD[1] if yy == 1 else HEAD[2])
    club.alpha_composite(fr)
    return club

ROOT = Path(__file__).resolve().parents[2]
ART_SCALE = 2.0
GOLFER_SCALE = 1.3          # game_scene.GOLFER_SCALE: node scale applied to every golfer
ANIMS = {
    # name: (frames, ms per frame, loop)
    "idle": (["idle_0", "idle_1", "idle_2", "idle_3", "idle_2", "idle_1"], [260, 200, 260, 220, 200, 200], True),
    "swing": (["address", "takeaway", "halfback", "top", "down", "impact", "follow", "finish"],
              [60, 60, 60, 80, 40, 50, 90, 500], False),
}
CONTACT = 5   # "impact" frame index in swing


def grounded(img: Image.Image, pivot_y: int) -> Image.Image:
    box = img.getbbox()
    if box is None:
        return img
    dy = (pivot_y - 1) - (box[3] - 1)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, dy))
    return out


def main() -> int:
    cid, name, painted = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()
    work = ROOT / "tools/artgen/out" / f"frames_{cid}"
    if work.exists():
        shutil.rmtree(work)
    char = cid if cid in ps.CHARS else "rex"
    ps.cut(char, painted, work)
    meta_frames = json.loads((work / "frames.json").read_text(encoding="utf-8"))
    dst = ROOT / "client/assets/characters" / cid
    dst.mkdir(parents=True, exist_ok=True)
    pivot = [ps.FEET[0], ps.FEET[1] + 1]
    anims = {}
    for anim, (names, ms, loop) in ANIMS.items():
        strip = Image.new("RGBA", (ps.CELL_W * len(names), ps.CELL_H), (0, 0, 0, 0))
        frames = []
        for i, fn in enumerate(names):
            m = meta_frames[fn]
            raw = Image.open(work / f"{fn}.png").convert("RGBA")
            box = raw.getbbox()
            dy = (pivot[1] - 1) - (box[3] - 1) if box else 0
            fr = grounded(raw, pivot[1])
            g = [m["grip"][0], m["grip"][1] + dy]
            h = [m["club_head"][0], m["club_head"][1] + dy]
            fr = px.outline(draw_club(fr, g, h))
            fr = grounded(fr, pivot[1])
            m = {"grip": g, "club_head": h}
            strip.alpha_composite(fr, (i * ps.CELL_W, 0))
            frames.append({"name": fn, "rect": [i * ps.CELL_W, 0, ps.CELL_W, ps.CELL_H], "ms": ms[i],
                           "anchors": {"club_grip": m["grip"], "club_head": m["club_head"]}})
        strip.save(dst / f"{anim}.png")
        anims[anim] = {"sheet": f"{anim}.png", "loop": loop, "frames": frames, "target_frames": len(names),
                       "contact_frame": CONTACT if anim == "swing" else None}
    meta = {
        "format": 1, "id": cid, "name": name,
        "frame_size": [ps.CELL_W, ps.CELL_H], "pivot": pivot,
        "rig_units_per_px": ART_SCALE / GOLFER_SCALE,
        "anims": anims, "palette": {}, "regions": {}, "recolor_regions": [], "variants": {},
        "equipment_slots": {}, "surfaces": {},
        "source": {"generator": "tools/artgen (SDXL + pixel-art-xl LoRA), pose-guided paint-over",
                   "guide": f"art/characters/guides/{char}.png", "painted": str(painted.relative_to(ROOT)).replace("\\", "/")},
    }
    (dst / "character.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"{cid}: idle {len(ANIMS['idle'][0])} + swing {len(ANIMS['swing'][0])} frames -> {dst.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
