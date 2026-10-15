"""Pose-guide sheets for golfer animation (paint-over workflow).

Draws a colour-blocked mannequin for every keyframe on a fixed grid. The generator then repaints
the whole sheet as one character in one pass (identity stays consistent across cells), and
cut_frames() slices the result back into frames using the same grid, so every frame's pivot and
club anchors are known exactly instead of guessed.

usage:
  python tools/artgen/pose_sheet.py guide <char> out.png        # write the 8x-scaled guide
  python tools/artgen/pose_sheet.py cut <char> painted.png outdir # slice a painted sheet to frames

Coordinates are art px, origin = ground point between the feet, +x = target side, y up negative.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL_W, CELL_H = 48, 64
COLS = 4
FEET = (22, 60)            # pivot inside a cell
SCALE = 8                  # generator pixels per art pixel

# Keyframes: joints in art px. hip/neck/head; knees+ankles back/front; elbow, hands, club head.
# The swing is a pendulum in the screen plane (side-view golf): back = -x, target = +x.
POSES: dict[str, dict] = {
    # idle: address stance, breathing (torso/head drift 1px, hands settle)
    "idle_0": dict(hip=(-5, -26), neck=(4, -42), head=(8, -48), kb=(-4, -13), kf=(3, -13), ab=(-7, 0), af=(7, 0), el=(7, -32), hd=(9, -23), ch=(25, -1)),
    "idle_1": dict(hip=(-5, -26), neck=(4, -41), head=(8, -47), kb=(-4, -13), kf=(3, -13), ab=(-7, 0), af=(7, 0), el=(7, -31), hd=(9, -22), ch=(25, -1)),
    "idle_2": dict(hip=(-5, -25), neck=(4, -41), head=(8, -47), kb=(-4, -12), kf=(3, -12), ab=(-7, 0), af=(7, 0), el=(7, -31), hd=(9, -22), ch=(25, -1)),
    "idle_3": dict(hip=(-5, -26), neck=(4, -42), head=(9, -48), kb=(-4, -13), kf=(3, -13), ab=(-7, 0), af=(7, 0), el=(7, -32), hd=(9, -23), ch=(25, -1)),
    # swing
    "address":  dict(hip=(-5, -26), neck=(4, -42), head=(8, -48), kb=(-4, -13), kf=(3, -13), ab=(-7, 0), af=(7, 0), el=(7, -32), hd=(9, -23), ch=(25, -1)),
    "takeaway": dict(hip=(-5, -26), neck=(3, -42), head=(7, -48), kb=(-4, -13), kf=(4, -13), ab=(-7, 0), af=(7, 0), el=(3, -32), hd=(1, -26), ch=(-15, -12)),
    "halfback": dict(hip=(-6, -26), neck=(2, -42), head=(6, -48), kb=(-5, -13), kf=(4, -12), ab=(-7, 0), af=(7, 0), el=(-1, -35), hd=(-6, -33), ch=(-10, -53)),
    "top":      dict(hip=(-6, -27), neck=(1, -43), head=(6, -49), kb=(-5, -14), kf=(5, -12), ab=(-7, 0), af=(7, 0), el=(-2, -42), hd=(-5, -47), ch=(13, -55)),
    "down":     dict(hip=(-4, -26), neck=(3, -42), head=(7, -48), kb=(-3, -13), kf=(4, -13), ab=(-7, 0), af=(7, 0), el=(1, -36), hd=(-2, -34), ch=(-20, -42)),
    "impact":   dict(hip=(-2, -26), neck=(5, -42), head=(8, -48), kb=(-2, -13), kf=(4, -14), ab=(-7, 0), af=(7, 0), el=(8, -31), hd=(10, -22), ch=(25, -1)),
    "follow":   dict(hip=(0, -27), neck=(5, -43), head=(9, -49), kb=(-2, -12), kf=(5, -14), ab=(-6, -1), af=(7, 0), el=(12, -35), hd=(15, -37), ch=(24, -55)),
    "finish":   dict(hip=(1, -28), neck=(4, -45), head=(7, -51), kb=(-1, -12), kf=(5, -14), ab=(-4, -2), af=(7, 0), el=(8, -46), hd=(2, -52), ch=(-15, -50)),
}
ORDER = list(POSES)

CHARS = {
    # body: torso width, leg width, head radius; extra silhouette features per design
    "rex":   dict(skin=(240, 190, 150), top=(226, 118, 48), legs=(46, 92, 70), shoe=(120, 60, 34), head_top=(226, 118, 48), hair=(214, 90, 30), club=(200, 206, 216),
                  torso=9, leg=5, head=6, cap_brim=True),
    "mira":  dict(skin=(240, 196, 160), top=(246, 204, 58), legs=(240, 196, 160), shoe=(240, 240, 244), head_top=(244, 244, 248), hair=(130, 70, 170), club=(200, 206, 216),
                  torso=7, leg=3, head=6, skirt=(36, 44, 92), ponytail=True, cap_brim=True),
    "bjorn": dict(skin=(232, 176, 140), top=(70, 120, 64), legs=(110, 78, 50), shoe=(80, 50, 30), head_top=(160, 168, 180), hair=(200, 80, 40), club=(200, 206, 216),
                  torso=13, leg=6, head=7, beard=(200, 80, 40), horns=(240, 232, 210), vest=(130, 92, 60)),
}


def cell_origin(i: int) -> tuple[int, int]:
    return (i % COLS) * CELL_W + FEET[0], (i // COLS) * CELL_H + FEET[1]


def guide(char: str, out: Path) -> None:
    c = CHARS[char]
    rows = (len(ORDER) + COLS - 1) // COLS
    img = Image.new("RGB", (COLS * CELL_W, rows * CELL_H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(ORDER):
        ox, oy = cell_origin(i)
        p = {k: (ox + v[0], oy + v[1]) for k, v in POSES[name].items()}
        shoulder = (p["neck"][0] - 1, p["neck"][1] + 2)
        # club first (behind), then legs, torso, arm, head
        d.line([p["hd"], p["ch"]], fill=c["club"], width=1)
        d.rectangle([p["ch"][0] - 2, p["ch"][1] - 1, p["ch"][0] + 2, p["ch"][1] + 1], fill=(150, 156, 170))
        hx, hy = p["head"]
        hr = c["head"]
        if c.get("ponytail"):
            d.line([(hx - hr, hy - 2), (hx - hr - 4, hy + 4), (hx - hr - 3, hy + 10)], fill=c["hair"], width=3)
        for k, a in (("kb", "ab"), ("kf", "af")):
            d.line([p["hip"], p[k], p[a]], fill=c["legs"], width=c["leg"], joint="curve")
            d.rectangle([p[a][0] - 2, p[a][1] - 3, p[a][0] + 4, p[a][1]], fill=c["shoe"])
        d.line([p["hip"], p["neck"]], fill=c["top"], width=c["torso"])
        if c.get("vest"):
            mid = ((p["hip"][0] + p["neck"][0]) // 2, (p["hip"][1] + p["neck"][1]) // 2)
            d.line([mid, p["neck"]], fill=c["vest"], width=c["torso"] + 2)
        if c.get("skirt"):
            hx0, hy0 = p["hip"]
            d.polygon([(hx0 - 5, hy0 - 4), (hx0 + 5, hy0 - 4), (hx0 + 8, hy0 + 7), (hx0 - 8, hy0 + 7)], fill=c["skirt"])
        d.line([shoulder, p["el"]], fill=c["top"], width=4 if c["torso"] < 12 else 5)
        d.line([p["el"], p["hd"]], fill=c["skin"], width=3)
        d.ellipse([p["hd"][0] - 2, p["hd"][1] - 2, p["hd"][0] + 2, p["hd"][1] + 2], fill=(250, 250, 250))
        d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=c["skin"])
        d.chord([hx - hr - 1, hy - hr - 2, hx + hr + 1, hy + hr - 2], 180, 360, fill=c["head_top"])
        if c.get("cap_brim"):
            d.line([(hx + 2, hy - 2), (hx + hr + 4, hy - 2)], fill=c["head_top"], width=2)
        if c.get("horns"):
            d.polygon([(hx - hr + 1, hy - hr + 2), (hx - hr - 3, hy - hr - 5), (hx - hr + 3, hy - hr)], fill=c["horns"])
            d.polygon([(hx + hr - 1, hy - hr + 2), (hx + hr + 3, hy - hr - 5), (hx + hr - 3, hy - hr)], fill=c["horns"])
        if c.get("beard"):
            d.polygon([(hx - 2, hy + 1), (hx + hr + 1, hy + 1), (hx + hr - 1, hy + hr + 5), (hx + 1, hy + hr + 3)], fill=c["beard"])
        d.rectangle([hx - hr - 1, hy - 3, hx - hr + 3, hy + 3], fill=c["hair"])
        d.point((hx + 3, hy - 1), fill=(30, 30, 40))
    img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST).save(out)
    print(out, img.size)


def cut(char: str, painted: Path, outdir: Path) -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import pixelize as px
    img = Image.open(painted).convert("RGB")
    small = px.quantise(px.snap(img, SCALE, None), 40, None)
    cutout = px.despeckle(px.defringe(px.cut_background(small, 30), 2, 200))
    outdir.mkdir(parents=True, exist_ok=True)
    meta = {}
    for i, name in enumerate(ORDER):
        x0, y0 = (i % COLS) * CELL_W, (i // COLS) * CELL_H
        fr = cutout.crop((x0, y0, x0 + CELL_W, y0 + CELL_H))
        fr.save(outdir / f"{name}.png")
        pose = POSES[name]
        meta[name] = {"pivot": list(FEET), "grip": [FEET[0] + pose["hd"][0], FEET[1] + pose["hd"][1]],
                      "club_head": [FEET[0] + pose["ch"][0], FEET[1] + pose["ch"][1]]}
    (outdir / "frames.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print(outdir, len(ORDER), "frames")


if __name__ == "__main__":
    cmd, char = sys.argv[1], sys.argv[2]
    if cmd == "guide":
        guide(char, Path(sys.argv[3]))
    else:
        cut(char, Path(sys.argv[3]), Path(sys.argv[4]))
