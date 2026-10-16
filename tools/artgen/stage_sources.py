"""Write art/worlds/<theme>/SOURCES.md: where every committed pick came from (job, prompt, seed).

usage: tools/artgen/.venv/Scripts/python tools/artgen/stage_sources.py <theme|all>

Picks are named <job>_<seed>.png (raw generation), <job>_<seed>_x2.png / _x4.png (detail upscale
via `stage_gen.py up`, prompt recorded in jobs/stage_upscales.json), or copied from another theme
(meadow_*, beach_* inside another theme). Hand-drawn pieces come from stage_hand.py; decor sprites
are cut from picks by stage_pick.py using art/worlds/<theme>/decor.picks.json.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS = ROOT / "tools/artgen/jobs"


def all_jobs() -> dict:
    out = {}
    for f in sorted(JOBS.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(data, list):
            for j in data:
                if isinstance(j, dict) and "name" in j:
                    out.setdefault(j["name"], (f.name, j))
    return out


def upscales() -> dict:
    p = JOBS / "stage_upscales.json"
    return {u["out"]: u for u in json.loads(p.read_text(encoding="utf-8"))} if p.exists() else {}


def write(theme: str) -> None:
    d = ROOT / "art/worlds" / theme
    jobs, ups = all_jobs(), upscales()
    lines = [f"# {theme} stage art: sources", "",
             "Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl "
             "(LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in "
             "tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.",
             "", "Rebuild without the GPU:", "", "```",
             f"tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py {theme}",
             f"tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/{theme}/decor.picks.json",
             f"tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py {theme}", "```", "",
             "## Picks", "", "| file | job (file) | seed | size | prompt |", "|---|---|---|---|---|"]
    for f in sorted((d / "picks").glob("*.png")):
        stem = f.stem
        if stem in ups:
            u = ups[stem]
            lines.append(f"| {f.name} | detail upscale of `{u['src']}` | {u.get('seed', 7)} | x{u.get('factor', 2)} | "
                         f"img2img strength {u.get('strength', 0.4)}: {u['prompt']} |")
            continue
        m = re.match(r"(.+)_(\d+)$", stem)
        if stem.startswith("meadow_") or (m and m.group(1) not in jobs):
            lines.append(f"| {f.name} | copied from another theme's picks | | | see that theme's SOURCES / jobs |")
            continue
        job, seed = m.group(1), m.group(2)
        jf, j = jobs[job]
        extra = []
        if j.get("tile"):
            extra.append("seamless")
        if j.get("init"):
            extra.append(f"img2img from `{j['init']}` @ {j.get('strength')}")
        lines.append(f"| {f.name} | {job} ({jf}) | {seed} | {j['w']}x{j['h']} {' '.join(extra)} | "
                     f"{j['prompt']} ; style: {j.get('style', 'stage_gen default')} |")
    lines += ["", "## Processing", "",
              "- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.",
              "- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).",
              "- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the "
              "decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.",
              "- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.", ""]
    (d / "SOURCES.md").write_text("\n".join(lines), encoding="utf-8")
    print(d / "SOURCES.md")


if __name__ == "__main__":
    for t in (["beach", "sticky", "snow", "lab", "spin"] if sys.argv[1] == "all" else [sys.argv[1]]):
        write(t)
