"""v4 sprite golfer build: committed art-px frames -> game strips + character.json.

  python tools/artgen/g4_build.py process <id>      # out/g4_<id>/<pose>_<pick>.png -> art/characters/<id>/v4/<pose>.png
  python tools/artgen/g4_build.py build <id>        # art/characters/<id>/v4/*.png -> client/assets/characters/<id>/

art/characters/<id>/v4/picks.json records the generation seed/strength per pose (rebuild source).
The committed frames hold the painted body without the club. The build adds:
  * the authored club along each pose's exact grip -> head line (hands stay on top of the grip),
  * the idle loop, derived from the address frame by moving the head/torso layers 0-1 px
    (breathing with overlapping action; legs and club head stay planted, nothing flickers),
  * per-frame anchors (club_grip, club_head, head_top), pivot (48, 124) and timings.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import g4_poses as poses  # noqa: E402
import g4_px as px  # noqa: E402
import g4_rig as rig  # noqa: E402
from g4_chars import SPECS, bg_of  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "out"
ART_SCALE = 2.0
GOLFER_SCALE = 1.3
CLUB_PARTS = {"shaft", "clubhead", "grip"}
HEAD_PARTS = {"head", "hair", "cap", "brim", "eye_white", "pupil", "brow", "mouth", "ear", "hat", "beard", "band", "star", "teeth",
              "horn", "visor", "helmet", "antenna", "glasses", "plume", "hood", "face"}
LEG_PARTS = {"thigh", "shin", "knee", "shoe", "pelvis", "tail", "foot", "tyre", "hub", "robe", "trim", "peg"}

SWING_MS = [70, 60, 60, 90, 40, 50, 90, 520]
IDLE = [  # (torso dy, head dy, ms): exhale/inhale with the head settling a beat later
    (0, 0, 240), (0, 1, 160), (1, 1, 220), (1, 1, 200), (1, 1, 160), (0, 1, 180), (0, 0, 200)]
VICTORY = ["vic_0", "vic_1", "vic_2", "vic_3", "vic_2", "vic_1"]
VICTORY_MS = [220, 110, 150, 130, 150, 110]


def spec(cid):
    return SPECS[cid]


def pose_of(cid, name):
    from g4_chars import pose_for
    return pose_for(cid, name)


def guide(cid, name, club: bool = True):
    s = spec(cid)
    p = pose_of(cid, name)
    p["no_club"] = not club
    parts = s["build"](s, p)
    img, idx = rig.render(parts)
    return img, idx, [p.name for p in parts]


def part_mask(idx, names, want) -> np.ndarray:
    m = np.zeros(idx.shape, bool)
    for i, n in enumerate(names):
        if n in want:
            m |= idx == i
    return m


def nearest_part(idx: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Guide part index for every pixel (pixels outside the guide take the nearest part)."""
    _, (iy, ix) = ndimage.distance_transform_edt(idx < 0, return_indices=True)
    return idx[iy, ix]


def strip_club(rgba: np.ndarray, idx: np.ndarray, names: list[str]) -> np.ndarray:
    """Remove the generator's own club (it gets replaced by the authored one)."""
    club = part_mask(idx, names, CLUB_PARTS)
    body = (idx >= 0) & ~club
    zone = ndimage.binary_dilation(club, px.K4, iterations=2) & ~ndimage.binary_dilation(body, px.K4, iterations=0)
    out = rgba.copy()
    out[zone] = 0
    al = out[:, :, 3] > 0
    # drop the old outline ring pixels now floating, and tiny leftovers
    dark = out[:, :, :3].astype(int).sum(-1) < 120
    lbl, n = ndimage.label(al, px.K4)
    if n > 1:
        sizes = ndimage.sum(al, lbl, range(1, n + 1))
        main = int(np.argmax(sizes)) + 1
        for j in range(1, n + 1):
            if j != main and (sizes[j - 1] < 12 or dark[lbl == j].mean() > 0.6):
                out[lbl == j] = 0
    # strip outline-only fringes left at the cut (dark pixels with <=1 opaque non-dark neighbour)
    al = out[:, :, 3] > 0
    dark = (out[:, :, :3].astype(int).sum(-1) < 120) & al
    nb = ndimage.convolve(al.astype(int), px.K4.astype(int), mode="constant") - al
    out[al & (nb <= 1) & dark] = 0
    return px.outline_img(out)


SHAFT_LIGHT, SHAFT_DARK = (226, 232, 242, 255), (112, 120, 146, 255)
GRIP_DARK, GRIP_LIGHT = (50, 40, 64, 255), (92, 80, 112, 255)


def club_img(grip, head) -> tuple[np.ndarray, np.ndarray]:
    """Authored club along grip -> head (frame coords): 2 px shaft (light core + shaded side),
    wrapped grip, and an outlined, 3-tone iron blade. Returns (rgba, core mask)."""
    g = np.array(grip, float) + 0.5
    h = np.array(head, float) + 0.5
    d = h - g
    L = float(np.hypot(*d))
    u = d / max(L, 1e-6)
    side = np.array([-u[1], u[0]])
    if side[1] < 0 or (abs(side[1]) < 1e-6 and side[0] < 0):
        side = -side                       # shaded side faces down / away from the light
    out = np.zeros((rig.H, rig.W, 4), np.uint8)

    def put(x, y, c, only_empty=False):
        x, y = int(np.floor(x)), int(np.floor(y))
        if 0 <= x < rig.W and 0 <= y < rig.H and (not only_empty or out[y, x, 3] == 0):
            out[y, x] = c
    n = int(np.ceil(L * 2))
    for i in range(n + 1):
        q = g + d * i / n
        in_grip = i / n * L < 8.5
        put(*q, GRIP_LIGHT if in_grip else SHAFT_LIGHT)
    for i in range(n + 1):
        q = g + d * i / n + side * 0.9
        in_grip = i / n * L < 8.5
        put(*q, GRIP_DARK if in_grip else SHAFT_DARK, only_empty=True)
    # blade: lies along the shaft rotated back by the address lie angle (63 deg)
    a = np.radians(-63.0)
    b = np.array([u[0] * np.cos(a) - u[1] * np.sin(a), u[0] * np.sin(a) + u[1] * np.cos(a)])
    nb = np.array([-b[1], b[0]])
    if nb @ u < 0:
        nb = -nb                           # blade thickness grows back up the shaft side
    hp = (h[0] - rig.PIV[0] - 0.5, h[1] - rig.PIV[1] - 0.5)
    P = lambda s, t: (hp[0] + b[0] * s - nb[0] * t, hp[1] + b[1] * s - nb[1] * t)
    blade = [P(-2.6, -0.3), P(3.6, -0.3), P(4.3, 1.4), P(3.0, 2.9), P(-2.6, 3.0)]
    bimg, bidx = rig.render([rig.Part("blade", rig.poly(blade), "#c3ccdb")])
    ba = np.asarray(bimg)
    sel = ba[:, :, 3] > 0
    out[sel] = ba[sel]
    return out, out[:, :, 3] > 0


def hand_mask(rgba, grip, s, r: float = 7.0):
    from g4_rig import ramp
    col = s["c"].get("glove", s["c"].get("hand", s["c"]["skin"]))
    rp = np.array(ramp(col)[0:5], float)
    lab = px.to_lab(rgba[:, :, :3])
    ref = px.to_lab(rp.astype(np.uint8))
    d = np.sqrt(((lab[:, :, None, :] - ref[None, None]) ** 2).sum(-1)).min(-1)
    yy, xx = np.mgrid[0:rig.H, 0:rig.W]
    m = (np.hypot(xx - grip[0], yy - grip[1]) <= r) & (d < s.get("hand_tol", 14.0) + 4) & (rgba[:, :, 3] > 0)
    # include the outline pixels hugging the hand so the shaft tucks under it
    return ndimage.binary_dilation(m, px.K4) & (rgba[:, :, 3] > 0)


def find_hands(rgba: np.ndarray, grip, s: dict, r: float = 7.0):
    """Centre of the painted hands near the planned grip (the paint-over can move them 1-5 px).
    Hands are found by the glove / hand colour of the spec."""
    from g4_rig import ramp
    col = s["c"].get("glove", s["c"].get("hand", s["c"]["skin"]))
    rp = np.array(ramp(col)[1:5], float)
    lab = px.to_lab(rgba[:, :, :3])
    ref = px.to_lab(rp.astype(np.uint8))
    d = np.sqrt(((lab[:, :, None, :] - ref[None, None]) ** 2).sum(-1)).min(-1)
    yy, xx = np.mgrid[0:rig.H, 0:rig.W]
    near = np.hypot(xx - grip[0], yy - grip[1]) <= r
    m = near & (d < s.get("hand_tol", 14.0)) & (rgba[:, :, 3] > 0)
    if m.sum() < 4:
        return None
    lbl, n = ndimage.label(m, np.ones((3, 3), bool))
    best = max(range(1, n + 1), key=lambda j: (lbl == j).sum())
    ys, xs = np.nonzero(lbl == best)
    return [int(round(xs.mean())), int(round(ys.mean()))]


def compose_club(body: np.ndarray, club: np.ndarray, behind: bool, hand: np.ndarray) -> np.ndarray:
    out = body.copy()
    cal = club[:, :, 3] > 0
    bal = body[:, :, 3] > 0
    if behind:
        sel = cal & ~bal
    else:
        sel = cal & (~hand | ~bal)
        # the blade's outline ring never overwrites body pixels
        ring = cal & (club[:, :, :3].astype(int).sum(-1) < 100)
        sel &= ~(ring & bal)
    out[sel] = club[sel]
    return out


def head_top(rgba: np.ndarray, layer: np.ndarray) -> list[int]:
    m = layer & (rgba[:, :, 3] > 0)
    ys, xs = np.nonzero(m)
    if not len(ys):
        return [rig.PIV[0], 20]
    y = int(ys.min())
    return [int(round(xs[ys <= y + 1].mean())), y]


def layers(cid, name, rgba):
    _, idx, names = guide(cid, name)
    near = nearest_part(idx, rgba[:, :, 3] > 0)
    head = part_mask(near, names, HEAD_PARTS)
    legs = part_mask(near, names, LEG_PARTS)
    club = part_mask(near, names, CLUB_PARTS)
    torso = ~head & ~legs & ~club
    hand = ndimage.binary_dilation(part_mask(idx, names, {"hand"}), px.K4, iterations=1)
    return head, torso, legs, hand


def shift(rgba, mask, dy):
    m = np.zeros(rgba.shape, np.uint8)
    m[mask] = rgba[mask]
    return np.roll(m, dy, 0) if dy else m


def over(a, b):
    out = a.copy()
    s = b[:, :, 3] > 0
    out[s] = b[s]
    return out


def to_frame_coords(p):
    return [int(round(rig.PIV[0] + p[0])), int(round(rig.PIV[1] + p[1]))]


def fix_eye(rgba: np.ndarray, cid: str, name: str) -> np.ndarray:
    """Authored eye: a crisp 2 x 3 eye (white + pupil + glint) at the guide's eye position, so
    the face reads in every frame even where the paint-over smudged it under a cap brim."""
    from g4_chars import head_local
    s = spec(cid)
    if s.get("no_face") or not s.get("eye_fix", True):
        return rgba
    p = pose_of(cid, name)
    hr = s.get("prop", {}).get("head", (10.0, 10.5))[0] * float(s.get("size", 1.0))
    ex, ey = s.get("eye", (0.45, -0.05))
    c = head_local(p, ex * hr + 0.7, ey * hr + 0.3)
    x, y = int(round(rig.PIV[0] + c[0])), int(round(rig.PIV[1] + c[1]))
    out = rgba.copy()
    blk = out[y - 2:y + 3, x - 2:x + 3]
    if blk.shape[:2] != (5, 5) or (blk[:, :, 3] == 0).sum() > 3:
        return rgba
    pupil = np.array([*px.hexrgb(s["c"].get("eye", "#2a2238")), 255], np.uint8)
    white = np.array([248, 248, 255, 255], np.uint8)
    pw, ph = s.get("eye_px", (1, 3))
    for dy in range(-1, ph - 1):
        for dx in range(pw):
            out[y + dy, x + dx] = pupil
        if s.get("eye_white", True) and dy < ph - 2:
            out[y + dy, x - 1] = white
    if pw == 1:
        out[y - 1, x] = np.array([96, 88, 120, 255], np.uint8)   # lid shade on the pupil top
    else:
        out[y, x] = white                                           # glint
    return out


def fix_spots(rgba: np.ndarray, cid: str, name: str) -> np.ndarray:
    """Authored colour spots at head-local anchors (spec "spots": [((x, y), radius, hex, hr)]),
    e.g. Bolt's antenna light, so small signature details keep one colour in every frame."""
    from g4_chars import head_local
    s = spec(cid)
    if not s.get("spots"):
        return rgba
    p = pose_of(cid, name)
    out = rgba.copy()
    yy, xx = np.mgrid[0:rig.H, 0:rig.W]
    for (lx, ly), r, col, hr in s["spots"]:
        c = head_local(p, lx * hr, ly * hr)
        cx, cy = rig.PIV[0] + c[0], rig.PIV[1] + c[1]
        m = (np.hypot(xx + 0.5 - cx, yy + 0.5 - cy) <= r) & (rgba[:, :, 3] > 0) & (rgba[:, :, :3].astype(int).sum(-1) > 100)
        base = np.array(px.hexrgb(col), float)
        out[m, :3] = base.astype(np.uint8)
        hi = m & (yy + 0.5 < cy) & (xx + 0.5 < cx)
        out[hi, :3] = np.minimum(base * 1.25 + 30, 255).astype(np.uint8)
    return out


# ---------------------------------------------------------------- commands

def raw_path(cid: str, file: str) -> Path:
    """Committed raw pick (art/characters/<id>/v4/raw/, 256-colour PNG) or the local generation."""
    a = ROOT / f"art/characters/{cid}/v4/raw" / file
    return a if a.exists() else OUT / f"g4_{cid}" / file


def archive(cid: str) -> None:
    """Copy the picked raw generations (and the portrait pick) into art/ as 256-colour PNGs so
    `process` is reproducible without the GPU or tools/artgen/out."""
    d = ROOT / f"art/characters/{cid}/v4"
    picks = json.loads((d / "picks.json").read_text(encoding="utf-8"))
    files = [pk["file"] for pk in picks["frames"].values()]
    pj = d / "portrait.json"
    if pj.exists():
        files.append(json.loads(pj.read_text(encoding="utf-8"))["candidate"])
    (d / "raw").mkdir(exist_ok=True)
    for f in files:
        src = OUT / f"g4_{cid}" / f
        if not src.exists():
            continue
        im = Image.open(src).convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        im.save(d / "raw" / f, optimize=True)
    print(cid, len(files), "raw picks archived")


def process(cid: str) -> None:
    picks = json.loads((ROOT / f"art/characters/{cid}/v4/picks.json").read_text(encoding="utf-8"))
    gens, gds = {}, {}
    for name, pk in picks["frames"].items():
        gens[name] = Image.open(raw_path(cid, pk["file"])).convert("RGB")
        gds[name] = guide(cid, name, club=False)
    allpx = np.concatenate([px.fg_pixels(gens[n], px.guide_alpha(gds[n][0]), 9) for n in gens])
    pal = px.kmeans_palette(allpx, int(picks.get("colors", 40)))
    dst = ROOT / f"art/characters/{cid}/v4"
    for name in gens:
        img, idx, names = gds[name]
        rgba = px.process(gens[name], img, pal, bg=bg_of(cid))
        rgba = fix_eye(rgba, cid, name)
        rgba = fix_spots(rgba, cid, name)
        Image.fromarray(rgba, "RGBA").save(dst / f"{name}.png")
        print(cid, name)


def build(cid: str) -> None:
    s = spec(cid)
    src = ROOT / f"art/characters/{cid}/v4"
    dst = ROOT / f"client/assets/characters/{cid}"
    dst.mkdir(parents=True, exist_ok=True)
    pivot = [rig.PIV[0], rig.PIV[1]]

    def finish(name, rgba, p, dy_hands=0):
        _, idx, names = guide(cid, name)
        hd = (p["grip"][0], p["grip"][1] + dy_hands)
        grip, head = to_frame_coords(hd), to_frame_coords(p["ch"])
        found = find_hands(rgba, grip, s)
        if found is not None:
            if head[1] >= rig.PIV[1] - 7:      # club head on the ground: keep it, re-aim the shaft
                grip = found
            else:                              # club in the air: carry the whole club with the hands
                head = [head[0] + found[0] - grip[0], head[1] + found[1] - grip[1]]
                grip = found
        club, _ = club_img(grip, head)
        hl, _, _, _ = layers(cid, name, rgba)
        hand = hand_mask(rgba, grip, s)
        out = compose_club(rgba, club, bool(p["club_behind"]), hand)
        al = out[:, :, 3] > 0
        rows = np.where(al.any(1))[0]
        assert rows[-1] == rig.PIV[1] - 1, f"{cid}/{name}: feet not on the pivot row ({rows[-1]})"
        return out, {"club_grip": grip, "club_head": head, "head_top": head_top(out, hl)}

    anims = {}
    # swing
    frames, sheet = [], []
    for i, name in enumerate(poses.SWING):
        rgba = np.asarray(Image.open(src / f"{name}.png").convert("RGBA"))
        out, anc = finish(name, rgba, pose_of(cid, name))
        sheet.append(out)
        frames.append({"name": name, "ms": SWING_MS[i], "anchors": anc})
    anims["swing"] = (frames, sheet, False, poses.CONTACT)
    # idle (derived from the address frame)
    base = np.asarray(Image.open(src / "address.png").convert("RGBA"))
    hl, tl, ll, hand = layers(cid, "address", base)
    p = pose_of(cid, "address")
    frames, sheet = [], []
    for i, (dt, dh, ms) in enumerate(IDLE):
        img = over(over(shift(base, ll, 0), shift(base, tl, dt)), shift(base, hl, dh))
        img = px.outline_img(img)
        out, anc = finish("address", img, p, dt)
        sheet.append(out)
        frames.append({"name": f"idle_{i}", "ms": ms, "anchors": anc})
    anims["idle"] = (frames, sheet, True, None)
    # victory (optional)
    if all((src / f"{n}.png").exists() for n in set(VICTORY)):
        frames, sheet = [], []
        for i, name in enumerate(VICTORY):
            rgba = np.asarray(Image.open(src / f"{name}.png").convert("RGBA"))
            out, anc = finish(name, rgba, pose_of(cid, name))
            sheet.append(out)
            frames.append({"name": name, "ms": VICTORY_MS[i], "anchors": anc})
        anims["victory"] = (frames, sheet, True, None)
    meta_anims = {}
    for an, (frames, sheet, loop, contact) in anims.items():
        strip = np.zeros((rig.H, rig.W * len(sheet), 4), np.uint8)
        for i, f in enumerate(sheet):
            strip[:, i * rig.W:(i + 1) * rig.W] = f
            frames[i]["rect"] = [i * rig.W, 0, rig.W, rig.H]
        Image.fromarray(strip, "RGBA").save(dst / f"{an}.png")
        meta_anims[an] = {"sheet": f"{an}.png", "loop": loop, "frames": frames, "target_frames": len(frames),
                          "contact_frame": contact}
    addr = pose_of(cid, "address")
    meta = {
        "format": 1, "id": cid, "name": s["name"],
        "frame_size": [rig.W, rig.H], "pivot": pivot,
        "rig_units_per_px": ART_SCALE / GOLFER_SCALE,
        # ball centre just in front of the blade face at address (blade front = head + 4.3, ball r = 3.5)
        "ball_offset": round((addr["ch"][0] + 8.0) * ART_SCALE / GOLFER_SCALE, 1),
        "anims": meta_anims, "palette": {}, "regions": {}, "recolor_regions": [], "variants": {},
        "equipment_slots": {}, "surfaces": {},
        "source": {"generator": "tools/artgen v4 (shaded pose guide -> SDXL + pixel-art-xl paint-over -> g4_px clean-up)",
                   "frames": f"art/characters/{cid}/v4/", "picks": f"art/characters/{cid}/v4/picks.json"},
    }
    if (dst / "portrait.png").exists():
        meta["portrait"] = "portrait.png"
    (dst / "character.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(cid, {k: len(v["frames"]) for k, v in meta_anims.items()})


def preview(cid: str, suffix: str, out: str, k: int = 3) -> None:
    """Process one seed's candidates (files <pose>_<suffix>.png) into a review strip without
    touching art/: rows = swing, victory + stand."""
    names = poses.SWING + poses.VICTORY + ["stand"]
    gens, gds = {}, {}
    for n in names:
        f = OUT / f"g4_{cid}" / f"{n}_{suffix}.png"
        if f.exists():
            gens[n] = Image.open(f).convert("RGB")
            gds[n] = guide(cid, n, club=False)
    allpx = np.concatenate([px.fg_pixels(gens[n], px.guide_alpha(gds[n][0]), 9) for n in gens])
    pal = px.kmeans_palette(allpx, 40)
    rows = [poses.SWING, poses.VICTORY + ["stand"]]
    sheet = Image.new("RGBA", (rig.W * 8, rig.H * 2), (110, 160, 112, 255))
    for r, row in enumerate(rows):
        for i, n in enumerate(row):
            if n in gens:
                fr = Image.fromarray(px.process(gens[n], gds[n][0], pal, bg=bg_of(cid)), "RGBA")
                sheet.alpha_composite(fr, (i * rig.W, r * rig.H))
    sheet.resize((sheet.width * k, sheet.height * k), Image.NEAREST).save(out)
    print(out)


def pick(cid: str, suffix: str, overrides: list[str]) -> None:
    """Write art/characters/<id>/v4/picks.json choosing <pose>_<suffix>.png for every pose
    (overrides: pose=suffix for single frames taken from another candidate)."""
    names = poses.SWING + poses.VICTORY + ["stand"]
    ov = dict(o.split("=", 1) for o in overrides)
    frames = {}
    for n in names:
        suf = ov.get(n, suffix)
        f = OUT / f"g4_{cid}" / f"{n}_{suf}.png"
        if not f.exists():
            continue
        tag, st, seed = suf.split("_")
        frames[n] = {"file": f.name, "seed": int(seed), "strength": int(st[1:]) / 100, "tag": tag}
    d = ROOT / f"art/characters/{cid}/v4"
    d.mkdir(parents=True, exist_ok=True)
    from g4_gen import full_prompt
    meta = {"colors": int(spec(cid).get("colors", 40)), "prompt": full_prompt(cid), "frames": frames}
    (d / "picks.json").write_text(json.dumps(meta, indent=1) + chr(10), encoding="utf-8")
    print(cid, len(frames), "frames picked")


if __name__ == "__main__":
    cmd, cid = sys.argv[1], sys.argv[2]
    if cmd == "preview":
        preview(cid, sys.argv[3], sys.argv[4])
    elif cmd == "pick":
        pick(cid, sys.argv[3], sys.argv[4:])
    else:
        {"process": process, "build": build, "archive": archive}[cmd](cid)
