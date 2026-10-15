"""Detail upscale for wide pixel-art backdrops: 2x resize, then re-render overlapping tiles with
img2img so the LoRA draws its 8px pixel grid at twice the scene density.

usage: tools/artgen/.venv/Scripts/python tools/artgen/upscale.py in.png out.png --prompt "..." [--strength 0.4]
"""
from __future__ import annotations

import argparse

import numpy as np
import torch
from PIL import Image

import generate as gen

TILE_W, TILE_H, OVER = 1536, 768, 256


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--strength", type=float, default=0.4)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    src = Image.open(a.src).convert("RGB")
    big = src.resize((src.width * 2, src.height * 2), Image.LANCZOS)
    W, H = big.size
    acc = np.zeros((H, W, 3), np.float32)
    wsum = np.zeros((H, W, 1), np.float32)
    p = gen.img2img()
    gen.set_tiling(gen.pipe(), False)
    gen.pipe().set_adapters(["pixel"], adapter_weights=[1.0])
    xs = list(range(0, max(W - TILE_W, 0) + 1, TILE_W - OVER))
    if xs[-1] + TILE_W < W:
        xs.append(W - TILE_W)
    ys = list(range(0, max(H - TILE_H, 0) + 1, TILE_H - OVER))
    if ys[-1] + TILE_H < H:
        ys.append(H - TILE_H)
    # feathered weights so overlapping tiles blend before the final palette snap
    wx = np.minimum(np.arange(TILE_W) + 1, np.arange(TILE_W)[::-1] + 1).clip(max=OVER) / OVER
    wy = np.minimum(np.arange(TILE_H) + 1, np.arange(TILE_H)[::-1] + 1).clip(max=OVER) / OVER
    wt = (wy[:, None] * wx[None, :])[:, :, None].astype(np.float32)
    for y in ys:
        for x in xs:
            tile = big.crop((x, y, x + TILE_W, y + TILE_H))
            g = torch.Generator("cuda").manual_seed(a.seed)
            out = p(prompt=f"{a.prompt}, {gen.STYLE}", negative_prompt=gen.NEGATIVE, image=tile,
                    strength=a.strength, num_inference_steps=30, guidance_scale=6.0, generator=g).images[0]
            acc[y:y + TILE_H, x:x + TILE_W] += np.asarray(out, np.float32) * wt
            wsum[y:y + TILE_H, x:x + TILE_W] += wt
            print(f"tile {x},{y}", flush=True)
    Image.fromarray((acc / np.maximum(wsum, 1e-6)).clip(0, 255).astype(np.uint8)).save(a.dst)
    print(a.dst, (W, H))


if __name__ == "__main__":
    main()
