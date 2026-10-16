"""Run the detail upscales listed in tools/artgen/jobs/stage_upscales.json (one pipeline load).

usage: tools/artgen/.venv/Scripts/python tools/artgen/stage_upscale.py [--only out ...] [--offload model|seq|none]

Each entry: {"out": "beach_sky_3101_x4", "theme": "beach", "src": "art/worlds/beach/picks/beach_sky_3101.png",
             "prompt": "...", "strength": 0.4, "factor": 4, "seed": 7}
factor 4 = two 2x passes of upscale.py (2x resize + overlapping img2img tiles), the same recipe as the
meadow sky (meadow_sky_103_x4b). The result is written to art/worlds/<theme>/picks/<out>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stage_gen as SG  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--offload", default="model", choices=["model", "seq", "none"])
    a = ap.parse_args()
    SG.MODE = a.offload
    import upscale as U
    U.gen = SG.G
    specs = json.loads((ROOT / "tools/artgen/jobs/stage_upscales.json").read_text(encoding="utf-8"))
    tmp = ROOT / "tools/artgen/out/_upscale"
    tmp.mkdir(parents=True, exist_ok=True)
    for s in specs:
        if a.only and s["out"] not in a.only:
            continue
        dst = ROOT / "art/worlds" / s["theme"] / "picks" / f"{s['out']}.png"
        cur = str(ROOT / s["src"])
        passes = {2: 1, 4: 2}[int(s.get("factor", 4))]
        for i in range(passes):
            nxt = str(tmp / f"{s['out']}_p{i}.png")
            sys.argv = ["upscale.py", cur, nxt, "--prompt", s["prompt"], "--strength", str(s.get("strength", 0.4)),
                        "--seed", str(s.get("seed", 7))]
            U.main()
            cur = nxt
        Path(dst).write_bytes(Path(cur).read_bytes())
        print("->", dst, flush=True)


if __name__ == "__main__":
    main()
