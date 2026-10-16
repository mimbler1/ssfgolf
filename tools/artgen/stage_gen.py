"""Stage-art generation on a shared GPU (job files tools/artgen/jobs/stage_*.json).

usage:
  tools/artgen/.venv/Scripts/python tools/artgen/stage_gen.py gen jobs/stage_beach.json [--only a b] [--seeds 1 2]
                                                              [--n 2] [--offload model|seq|none]
  tools/artgen/.venv/Scripts/python tools/artgen/stage_gen.py up in.png out.png --prompt "..." [--strength 0.4]
                                                              [--offload model|seq|none]

Same job format as generate.py ({"name","prompt","w","h","seeds","tile","init","strength",...}), plus
"style": a short style suffix instead of generate.STYLE (CLIP reads only 77 tokens, so stage prompts
use a compact suffix and keep the subject first).

--offload model (default) moves each sub-model to the GPU only while it runs, so the stage track can
share the card with the character pipeline. "seq" is the low-VRAM fallback (much slower).
`up` is tools/artgen/upscale.py (2x detail re-render in overlapping img2img tiles) on this loader.

Raw output: tools/artgen/out/<job name>/<seed>.png (git-ignored). Picks are copied into
art/worlds/<theme>/picks and built by build_stage.py.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as G  # noqa: E402  (sets HF_HOME before torch/diffusers load)
import torch  # noqa: E402
from diffusers import AutoencoderKL, StableDiffusionXLImg2ImgPipeline, StableDiffusionXLPipeline  # noqa: E402

STAGE_STYLE = "pixel art, crisp pixels, clean dark outlines, cel shading, vibrant, detailed 2d game art"
MODE = "model"


def _offload(p) -> None:
    if MODE == "model":
        p.enable_model_cpu_offload()
    elif MODE == "seq":
        p.enable_sequential_cpu_offload()
    else:
        p.to("cuda")


def pipe() -> StableDiffusionXLPipeline:
    if G._pipe is None:
        vae = AutoencoderKL.from_pretrained("madebyollin/sdxl-vae-fp16-fix", torch_dtype=torch.float16)
        p = StableDiffusionXLPipeline.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0", vae=vae, torch_dtype=torch.float16,
            variant="fp16", use_safetensors=True)
        p.load_lora_weights("nerijs/pixel-art-xl", weight_name="pixel-art-xl.safetensors", adapter_name="pixel")
        _offload(p)
        G._pipe = p
    return G._pipe


def img2img() -> StableDiffusionXLImg2ImgPipeline:
    if G._img2img is None:
        G._img2img = StableDiffusionXLImg2ImgPipeline(**pipe().components)
        if MODE != "none":
            _offload(G._img2img)
    return G._img2img


# generate.run builds its torch.Generator on "cuda"; that works under offload too.
G.pipe = pipe
G.img2img = img2img


def cmd_gen(a) -> None:
    path = Path(a.jobs)
    if not path.exists():
        path = Path(__file__).resolve().parent / a.jobs
    jobs = json.loads(path.read_text(encoding="utf-8"))
    for job in jobs:
        if a.only and job["name"] not in a.only:
            continue
        if a.seeds:
            job = {**job, "seeds": a.seeds}
        job = {**job, "style": job.get("style", STAGE_STYLE)}
        G.run(job, a.n)


def cmd_up(a) -> None:
    import upscale as U
    sys.argv = ["upscale.py", a.src, a.dst, "--prompt", a.prompt, "--strength", str(a.strength), "--seed", str(a.seed)]
    U.gen = G
    U.main()


def main() -> None:
    global MODE
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("jobs")
    g.add_argument("--only", nargs="*")
    g.add_argument("--n", type=int)
    g.add_argument("--seeds", type=int, nargs="*")
    u = sub.add_parser("up")
    u.add_argument("src")
    u.add_argument("dst")
    u.add_argument("--prompt", required=True)
    u.add_argument("--strength", type=float, default=0.4)
    u.add_argument("--seed", type=int, default=7)
    for s in (g, u):
        s.add_argument("--offload", default="model", choices=["model", "seq", "none"])
    a = ap.parse_args()
    MODE = a.offload
    cmd_gen(a) if a.cmd == "gen" else cmd_up(a)


if __name__ == "__main__":
    main()
