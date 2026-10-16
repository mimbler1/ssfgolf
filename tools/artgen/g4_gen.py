"""v4 paint-over generation for one guide frame or a batch.

usage: python tools/artgen/g4_gen.py <char> <pose> --strengths 0.5 0.6 --seeds 1 2 [--tag t]
Writes tools/artgen/out/g4_<char>/<pose>_<tag>_s<strength>_<seed>.png (8x, 768x1024) and the init.
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import torch  # noqa: E402
import generate as G  # noqa: E402
import g4_rig as rig  # noqa: E402
from g4_chars import SPECS, bg_word  # noqa: E402
from g4_guide import frame  # noqa: E402  (pose names or dicts)

HERE = Path(__file__).resolve().parent
STYLE = "pixel art, 2d game sprite, crisp pixels, dark outline, rich cel shading, detailed"
NEG = ("blurry, smooth gradient, 3d render, photo, text, watermark, frame, border, noise, muddy colors, "
       "extra limbs, extra arms, multiple characters, cropped, shadow on ground, scenery, golf club, stick, bat, weapon")


def paint(init, prompt: str, seed: int, strength: float, cfg: float = 6.0, steps: int = 34, lora: float = 1.0):
    p = G.img2img()
    G.pipe().set_adapters(["pixel"], adapter_weights=[lora])
    g = torch.Generator("cuda").manual_seed(int(seed))
    return p(image=init, prompt=prompt, negative_prompt=NEG, strength=strength, guidance_scale=cfg,
             num_inference_steps=steps, generator=g).images[0]


def full_prompt(cid: str, extra: str = "", pose: str = "address") -> str:
    s = SPECS[cid]
    act = ("cheering with a big open smile, fist pump" if pose.startswith("vic") else
           "standing relaxed, confident smile" if pose == "stand" else "golf swing pose, hands clasped together")
    return f"{STYLE}, single {s['prompt']}, full body, side view facing right, {act}{extra}, {bg_word(cid)}"


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("char"); ap.add_argument("poses", nargs="+")
    ap.add_argument("--strengths", type=float, nargs="+", default=[0.6])
    ap.add_argument("--seeds", type=int, nargs="+", default=[1])
    ap.add_argument("--cfg", type=float, default=6.0)
    ap.add_argument("--lora", type=float, default=1.0)
    ap.add_argument("--tag", default="a")
    a = ap.parse_args()
    out = HERE / "out" / f"g4_{a.char}"
    out.mkdir(parents=True, exist_ok=True)
    import g4_poses
    plist = []
    for x in a.poses:
        plist += (g4_poses.SWING + g4_poses.VICTORY + ["stand"]) if x == "all" else [x]
    for pose in plist:
        from g4_chars import bg_of
        init = rig.upscale(frame(a.char, pose, club=False), bg=bg_of(a.char))
        init.save(out / f"{pose}_init.png")
        for st in a.strengths:
            for sd in a.seeds:
                img = paint(init, full_prompt(a.char, SPECS[a.char].get("pose_prompt", {}).get(pose, ""), pose), sd, st, a.cfg, lora=a.lora)
                fn = out / f"{pose}_{a.tag}_s{round(st*100)}_{sd}.png"
                img.save(fn)
                print(fn.name, flush=True)
