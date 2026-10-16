"""Generate the full v4 frame set for several characters in one GPU session.
usage: python tools/artgen/g4_queue.py <seed> <id> [<id> ...] [--strength 0.6] [--tag b] [--poses all]"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import g4_gen as G  # noqa: E402
import g4_poses  # noqa: E402
import g4_rig as rig  # noqa: E402
from g4_chars import SPECS, bg_of  # noqa: E402
from g4_guide import frame  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("seed", type=int)
ap.add_argument("ids", nargs="+")
ap.add_argument("--strength", type=float, default=0.6)
ap.add_argument("--tag", default="b")
ap.add_argument("--poses", nargs="+", default=["all"])
a = ap.parse_args()
names = []
for x in a.poses:
    names += (g4_poses.SWING + g4_poses.VICTORY + ["stand"]) if x == "all" else [x]
for cid in a.ids:
    out = G.HERE / "out" / f"g4_{cid}"
    out.mkdir(parents=True, exist_ok=True)
    for pose in names:
        fn = out / f"{pose}_{a.tag}_s{round(a.strength * 100)}_{a.seed}.png"
        if fn.exists():
            continue
        init = rig.upscale(frame(cid, pose, club=False), bg=bg_of(cid))
        img = G.paint(init, G.full_prompt(cid, SPECS[cid].get("pose_prompt", {}).get(pose, ""), pose), a.seed, a.strength)
        img.save(fn)
        print(cid, fn.name, flush=True)
