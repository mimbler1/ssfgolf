"""Render v4 guide frames: python tools/artgen/g4_guide.py <char> <out.png> [pose ...] [--gen]
Without --gen writes a 4x review strip; with --gen writes one 8x generator init per pose."""
from __future__ import annotations
import sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
import g4_rig as rig
import g4_poses as poses
from g4_chars import SPECS


def frame(cid: str, pose, club: bool = True) -> Image.Image:
    s = SPECS[cid]
    from g4_chars import pose_for
    p = dict(pose_for(cid, pose) if isinstance(pose, str) else pose)
    p["no_club"] = not club
    img, _ = rig.render(s["build"](s, p))
    return img


def strip(cid: str, names: list[str], k: int = 4, bg=(120, 170, 120)) -> Image.Image:
    out = Image.new("RGBA", (rig.W * len(names), rig.H), (*bg, 255))
    for i, n in enumerate(names):
        out.alpha_composite(frame(cid, n), (i * rig.W, 0))
    return out.resize((out.width * k, out.height * k), Image.NEAREST)


if __name__ == "__main__":
    cid, out = sys.argv[1], sys.argv[2]
    names = [a for a in sys.argv[3:] if not a.startswith("--")] or poses.SWING
    strip(cid, names).save(out)
    print(out)
