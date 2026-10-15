"""Local image generation for game art (SDXL + pixel-art LoRA, runs on the dev GPU).

usage:
  tools/artgen/.venv/Scripts/python tools/artgen/generate.py jobs/<file>.json [--only name] [--n 4]

A job file is a list of jobs:
  {"name": "meadow_far_mountains", "prompt": "...", "negative": "...", "w": 1536, "h": 640,
   "seeds": [11, 12], "steps": 30, "cfg": 6.0, "lora": 1.0}

Raw generations land in tools/artgen/out/<name>/<seed>.png (git-ignored). Nothing here is game
art yet: every pick goes through tools/artgen/pixelize.py (grid snap, palette, cleanup) and a
human/agent review before it is copied into art/.

Models (downloaded on first run into tools/artgen/models, licences checked for commercial use):
  stabilityai/stable-diffusion-xl-base-1.0   CreativeML Open RAIL++-M
  madebyollin/sdxl-vae-fp16-fix              MIT
  nerijs/pixel-art-xl                        CreativeML Open RAIL-M
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
os.environ.setdefault("HF_HOME", str(HERE / "models"))

import torch  # noqa: E402
from diffusers import AutoencoderKL, StableDiffusionXLImg2ImgPipeline, StableDiffusionXLPipeline  # noqa: E402

STYLE = ("pixel art, 2d side view game asset, crisp pixels, clean dark outlines, rich cel shading, "
         "vibrant saturated colors, detailed, professional sprite art, platform fighter stage art")
NEGATIVE = ("blurry, smooth gradient, 3d render, photo, realistic, jpeg artifacts, text, watermark, "
            "signature, logo, frame, border, ui, noise, low quality, muddy colors")

_pipe = None
_img2img = None


def pipe() -> StableDiffusionXLPipeline:
    global _pipe
    if _pipe is None:
        vae = AutoencoderKL.from_pretrained("madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16)
        _pipe = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0", vae=vae, torch_dtype=torch.float16,
            variant="fp16", use_safetensors=True).to("cuda")
        _pipe.load_lora_weights("nerijs/pixel-art-xl", weight_name="pixel-art-xl.safetensors", adapter_name="pixel")
    return _pipe


def img2img() -> StableDiffusionXLImg2ImgPipeline:
    global _img2img
    if _img2img is None:
        _img2img = StableDiffusionXLImg2ImgPipeline(**pipe().components)
    return _img2img


def set_tiling(p, on: bool) -> None:
    """Circular padding in every conv layer makes the output wrap seamlessly (terrain textures)."""
    for model in (p.unet, p.vae):
        for m in model.modules():
            if isinstance(m, torch.nn.Conv2d):
                m.padding_mode = "circular" if on else "zeros"


def run(job: dict, n: int | None) -> None:
    out = HERE / "out" / job["name"]
    out.mkdir(parents=True, exist_ok=True)
    p = pipe()
    set_tiling(p, bool(job.get("tile", False)))
    p.set_adapters(["pixel"], adapter_weights=[float(job.get("lora", 1.0))])
    seeds = job.get("seeds", [1, 2, 3, 4])[: n or None]
    prompt = f"{job['prompt']}, {job.get('style', STYLE)}"
    neg = f"{job.get('negative', '')}, {NEGATIVE}".strip(", ")
    for seed in seeds:
        g = torch.Generator("cuda").manual_seed(int(seed))
        kw = dict(prompt=prompt, negative_prompt=neg, num_inference_steps=int(job.get("steps", 30)),
                  guidance_scale=float(job.get("cfg", 6.0)), generator=g)
        if job.get("init"):
            from PIL import Image
            init = Image.open(HERE.parents[1] / job["init"]).convert("RGB").resize((job["w"], job["h"]))
            img = img2img()(image=init, strength=float(job.get("strength", 0.55)), **kw).images[0]
        else:
            img = p(width=int(job["w"]), height=int(job["h"]), **kw).images[0]
        img.save(out / f"{seed}.png")
        print(f"{job['name']}/{seed}.png", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("jobs")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--n", type=int)
    a = ap.parse_args()
    jobs = json.loads(Path(a.jobs).read_text(encoding="utf-8"))
    for job in jobs:
        if a.only and job["name"] not in a.only:
            continue
        run(job, a.n)


if __name__ == "__main__":
    main()
