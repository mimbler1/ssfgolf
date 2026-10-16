"""v4 portraits: 64 x 64 head-and-shoulders bust per sprite character (facing right).

  python tools/artgen/g4_portrait.py gen <id> --strengths 0.6 --seeds 1 2   # candidates (GPU)
  python tools/artgen/g4_portrait.py process <id> <candidate.png>           # -> art/characters/<id>/v4/portrait.png
  python tools/artgen/g4_portrait.py build <id>                             # -> client/assets/characters/<id>/portrait.png

The init is the character's own upright frame (vic_2, else address), cropped round the head and
enlarged to portrait scale, so the bust stays on model. The painted result is snapped to the
64 px grid, quantised to the character's frame palette (plus a few portrait-only shades) and
outlined like the sprites.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import g4_px as px  # noqa: E402
import g4_rig as rig  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SIZE = 64
GEN = 512
BG = (236, 236, 240)


def source_frame(cid: str) -> tuple[Image.Image, str]:
    d = ROOT / f"art/characters/{cid}/v4"
    for n in ("stand", "vic_2", "address"):
        if (d / f"{n}.png").exists():
            return Image.open(d / f"{n}.png").convert("RGBA"), n
    raise SystemExit(f"{cid}: no frames")


def init_image(cid: str, span: int = 36) -> tuple[Image.Image, np.ndarray]:
    """Crop span x span art px round the head top (bust: head + shoulders), scale to SIZE."""
    from g4_build import pose_of
    fr, name = source_frame(cid)
    p = pose_of(cid, name)
    a = np.asarray(fr)
    al = a[:, :, 3] > 0
    ys, xs = np.nonzero(al)
    top = ys.min()
    cx = int(rig.PIV[0] + (p["head"][0] + p["neck"][0]) / 2)
    x0 = cx - span // 2 + 2
    y0 = max(top - 3, 0)
    crop = fr.crop((x0, y0, x0 + span, y0 + span))
    big = crop.resize((SIZE, SIZE), Image.NEAREST)
    from g4_chars import bg_of
    bg = Image.new("RGBA", big.size, (*bg_of(cid), 255))
    bg.alpha_composite(big)
    mask = np.asarray(big)[:, :, 3] > 0
    return bg.convert("RGB").resize((GEN, GEN), Image.NEAREST), mask


def gen(cid: str, strengths, seeds, cfg: float = 6.0) -> None:
    import g4_gen as G
    from g4_chars import SPECS
    init, _ = init_image(cid)
    out = HERE / "out" / f"g4_{cid}"
    out.mkdir(parents=True, exist_ok=True)
    init.save(out / "portrait_init.png")
    s = SPECS[cid]
    prompt = (f"{G.STYLE}, portrait bust of a {s.get('portrait_prompt', s['prompt'])}, head and shoulders, "
              f"facing right, confident smile, character select portrait, {G.bg_word(cid)}")
    for st in strengths:
        for sd in seeds:
            img = G.paint(init, prompt, sd, st, cfg)
            fn = out / f"portrait_s{round(st * 100)}_{sd}.png"
            img.save(fn)
            print(fn.name, flush=True)


def process(cid: str, cand: Path) -> None:
    raw = ROOT / f"art/characters/{cid}/v4/raw" / Path(cand).name
    gen_img = Image.open(raw if raw.exists() else cand).convert("RGB")
    _, mask = init_image(cid)
    # palette: the character's frame colours + portrait-specific shades from the candidate
    d = ROOT / f"art/characters/{cid}/v4"
    frame_cols = []
    for f in d.glob("*.png"):
        if f.name.startswith("portrait") or f.stem == "stand":
            continue
        a = np.asarray(Image.open(f).convert("RGBA"))
        frame_cols.append(a[a[:, :, 3] > 0][:, :3])
    fc = np.unique(np.concatenate(frame_cols), axis=0)
    a = np.asarray(gen_img)
    sel = np.kron(ndimage.binary_erosion(mask, px.K4, iterations=2), np.ones((GEN // SIZE, GEN // SIZE), bool))
    extra = px.kmeans_palette(a[sel][::11], 16)
    pal = np.unique(np.concatenate([fc, extra]), axis=0)
    idx = px.snap(gen_img, pal, GEN // SIZE)
    # background: flood from the border through near-bg colours (no guide limit: the bust may grow)
    lab = px.to_lab(pal[idx])
    from g4_chars import bg_of
    near_bg = np.sqrt(((lab - px.to_lab(np.array([bg_of(cid)], np.uint8))[0]) ** 2).sum(-1)) <= 10
    border = np.zeros_like(near_bg)
    border[0, :] = border[:, 0] = border[:, -1] = border[-1, :] = True
    # the bust is cut at the bottom edge: never flood from the bottom row inside the body
    border[-1, :] &= near_bg[-1, :]
    bgm = ndimage.binary_propagation(border & near_bg, structure=px.K4, mask=near_bg)
    fg = ~bgm
    lbl, n = ndimage.label(fg, px.K4)
    if n > 1:
        sizes = ndimage.sum(fg, lbl, range(1, n + 1))
        fg = lbl == (int(np.argmax(sizes)) + 1)
    fg = px.fill_holes(fg)
    idx = px.clean(idx, fg)
    rgba = px.smooth(px.compose(idx, fg, pal))
    rgba = px.outline_img(rgba)
    # leave the bottom edge open (bust cut): no outline on the last row
    out = Image.fromarray(rgba, "RGBA")
    out.save(d / "portrait.png")
    (d / "portrait.json").write_text(json.dumps({"candidate": cand.name}, indent=1) + "\n", encoding="utf-8")
    print(d / "portrait.png")


def build(cid: str) -> None:
    src = ROOT / f"art/characters/{cid}/v4/portrait.png"
    dst = ROOT / f"client/assets/characters/{cid}"
    shutil.copy(src, dst / "portrait.png")
    meta_p = dst / "character.json"
    meta = json.loads(meta_p.read_text(encoding="utf-8"))
    meta["portrait"] = "portrait.png"
    meta_p.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(dst / "portrait.png")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd")
    ap.add_argument("id")
    ap.add_argument("cand", nargs="?")
    ap.add_argument("--strengths", type=float, nargs="+", default=[0.6])
    ap.add_argument("--seeds", type=int, nargs="+", default=[1])
    a = ap.parse_args()
    if a.cmd == "gen":
        for cid in a.id.split(","):
            gen(cid, a.strengths, a.seeds)
    elif a.cmd == "process":
        process(a.id, Path(a.cand))
    elif a.cmd == "reprocess":   # from the committed pick named in portrait.json
        name = json.loads((ROOT / f"art/characters/{a.id}/v4/portrait.json").read_text(encoding="utf-8"))["candidate"]
        process(a.id, Path(name))
    else:
        build(a.id)
