"""UI art candidates (ability icons, HUD frames, podium) on the local GPU.

usage:
  tools/artgen/.venv/Scripts/python tools/artgen/gen_ui.py jobs/ui_icons.json [--only name ...] [--n 4]
                                                          [--seeds 1 2 3] [--offload]

Same job format as generate.py (it reuses generate.run), plus:
  --seeds    override the job's seeds (quick re-rolls without editing the json)
  --offload  model CPU offload: keeps peak VRAM low when another pipeline shares the GPU (slower)

Raw output: tools/artgen/out/<job name>/<seed>.png (git-ignored). Picks are cleaned by
tools/artgen/build_ui.py from copies committed under art/ui/.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import torch  # noqa: E402
import generate as G  # noqa: E402
from diffusers import AutoencoderKL, StableDiffusionXLPipeline  # noqa: E402


# Keep prompt + style under CLIP's 77 tokens (the tail is silently truncated).
STYLES = {
    "@ICON": "pixel art game power-up icon, single centered object, thick dark outline, cel shading, "
             "lit from top left, vibrant colors, crisp pixels, plain black background",
    "@ICON_W": "pixel art game power-up icon, single centered object, thick dark outline, cel shading, "
               "lit from top left, vibrant colors, crisp pixels, simple white background",
    "@UI": "pixel art arcade game interface element, crisp pixels, dark outline, cel shading, lit from top left, detailed",
    "@PROP": "pixel art, 2d side view game asset, crisp pixels, dark outlines, cel shading, lit from top left, detailed",
}
NEG_ICON = ("multiple objects, scene, landscape, ground, floor, drop shadow, patterned background, textured background, "
            "grid, text, letters, numbers, cropped, cut off")


def offload_pipe():
    """One img2img-capable pipeline with sequential CPU offload: well under 2 GB of VRAM, for
    when another pipeline already fills the GPU. Slow, but it never stalls on memory. Text-only
    jobs run through it too (an img2img pipeline cannot do txt2img, so those need no --offload)."""
    if G._img2img is None:
        from diffusers import StableDiffusionXLImg2ImgPipeline
        vae = AutoencoderKL.from_pretrained("madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16)
        p = StableDiffusionXLImg2ImgPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0", vae=vae, torch_dtype=torch.float16,
            variant="fp16", use_safetensors=True)
        p.load_lora_weights("nerijs/pixel-art-xl", weight_name="pixel-art-xl.safetensors", adapter_name="pixel")
        p.enable_sequential_cpu_offload()
        G._img2img = p
        G._pipe = p
    return G._img2img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("jobs")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--n", type=int)
    ap.add_argument("--seeds", type=int, nargs="*")
    ap.add_argument("--offload", action="store_true")
    a = ap.parse_args()
    if a.offload:
        G.pipe = offload_pipe
        G.img2img = offload_pipe
    path = Path(a.jobs)
    if not path.exists():
        path = Path(__file__).resolve().parent / a.jobs
    jobs = json.loads(path.read_text(encoding="utf-8"))
    for job in jobs:
        if a.only and job["name"] not in a.only:
            continue
        if a.seeds:
            job = {**job, "seeds": a.seeds}
        if job.get("style") in STYLES:
            if job["style"].startswith("@ICON"):
                job = {**job, "negative": ", ".join(x for x in (job.get("negative"), NEG_ICON) if x)}
            job = {**job, "style": STYLES[job["style"]]}
        G.run(job, a.n)


if __name__ == "__main__":
    main()
