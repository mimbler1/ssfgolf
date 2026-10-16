"""Build the UI pixel art (client/assets/ui/**) from the committed picks in art/ui/. No GPU needed.

usage: tools/artgen/.venv/Scripts/python tools/artgen/build_ui.py [icons|ball|hud|podium|sheet ...]

Sources
  art/ui/icons/<id>.png        chosen raw SDXL generations (1024 px, subject on flat black), one per ability
  art/ui/hud/*.png             chosen raw generations for the HUD frames
  art/ui/studio/podium_raw.png chosen raw generation for the Golfer Studio podium
  art/ui/picks.json            how each pick is cut: crop box, colour count, background tolerance

Every pick goes through the same clean-up so the set stays consistent:
  background flood-cut -> square crop on the subject -> per-block colour mode at the target size
  (k-means palette in Lab, no blending) -> orphan clean-up -> 1 px ink outline (#20141e).
The golf ball is pre-rendered (tools/artgen/ui_ball.py), see docs/UI_ART.md.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ui_ball  # noqa: E402

ROOT = HERE.parents[1]
SRC = ROOT / "art/ui"
DST = ROOT / "client/assets/ui"
INK = (32, 20, 30)
K4 = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)
ICON = 48            # icon canvas, art px
ABILITIES = ["standard", "nitro", "sticky", "grenade", "heavy", "air_brake", "anti_grav", "free_shot",
             "ice", "laser", "magnet", "mulligan", "shield", "super", "zig_zag"]


# ---------------------------------------------------------------- colour helpers
def to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype(float) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def kmeans_palette(rgb: np.ndarray, k: int, iters: int = 14, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    if len(rgb) > 20000:
        rgb = rgb[rng.choice(len(rgb), 20000, replace=False)]
    lab = to_lab(rgb)
    cent = [lab[rng.integers(len(lab))]]
    for _ in range(1, k):
        d = np.min(((lab[:, None] - np.array(cent)[None]) ** 2).sum(-1), 1)
        if d.sum() <= 0:
            break
        cent.append(lab[rng.choice(len(lab), p=d / d.sum())])
    cent = np.array(cent)
    for _ in range(iters):
        lbl = ((lab[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
        for j in range(len(cent)):
            if (lbl == j).any():
                cent[j] = lab[lbl == j].mean(0)
    lbl = ((lab[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
    return np.array([np.median(rgb[lbl == j], 0) for j in range(len(cent)) if (lbl == j).any()]).round().astype(np.uint8)


def nearest(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    a = to_lab(rgb.reshape(-1, 3))
    b = to_lab(pal)
    out = np.empty(len(a), int)
    for i in range(0, len(a), 65536):
        out[i:i + 65536] = ((a[i:i + 65536, None] - b[None]) ** 2).sum(-1).argmin(1)
    return out.reshape(rgb.shape[:-1])


def punch(rgb: np.ndarray, sat: float = 1.15, contrast: float = 1.08, gamma: float = 1.0) -> np.ndarray:
    """Slight saturation/contrast lift before quantising: downscaling greys colours out.
    gamma < 1 brightens the mid-tones (dark subjects such as the iron kettlebell)."""
    f = rgb.astype(float)
    if gamma != 1.0:
        f = 255.0 * (f / 255.0) ** gamma
    g = f.mean(-1, keepdims=True)
    f = g + (f - g) * sat
    f = 128 + (f - 128) * contrast
    return np.clip(f, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- pixel clean-up
def background_mask(rgb: np.ndarray, bg: str, tol: float, erode: int = 10) -> np.ndarray:
    """Pixels of the flat generator background connected to the image border."""
    f = rgb.astype(float)
    if bg == "black":
        near = f.max(-1) <= tol
    elif bg == "white":
        near = f.min(-1) >= 255 - tol
    else:  # sample the corners
        ref = np.median(np.concatenate([f[:8, :8].reshape(-1, 3), f[-8:, -8:].reshape(-1, 3)]), 0)
        near = np.abs(f - ref).sum(-1) <= tol
    # Seeds: the border plus any broad patch of background (enclosed gaps such as the inside of a
    # ring or a crosshair). Thin dark lines vanish under the erosion, so they only go if they touch
    # real background (they are re-drawn as the ink outline afterwards anyway).
    seed = np.zeros_like(near)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    seed = (seed & near) | ndimage.binary_erosion(near, K4, iterations=erode)
    return ndimage.binary_propagation(seed, structure=K4, mask=near)


def keep_main(fg: np.ndarray, min_frac: float = 0.02, min_px: int = 30) -> np.ndarray:
    lbl, n = ndimage.label(fg, K4)
    if n <= 1:
        return fg
    sizes = ndimage.sum(fg, lbl, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = sizes >= max(sizes.max() * min_frac, min_px)
    return keep[lbl]


def block_snap(rgb: np.ndarray, fg: np.ndarray, size: tuple[int, int], pal: np.ndarray, cover: float = 0.5,
               sub: int = 8) -> tuple[np.ndarray, np.ndarray]:
    """Resample the subject to `size` art px: per-block mode of palette indices over foreground
    pixels (no averaging, so no in-between colours), alpha = block coverage >= cover."""
    w, h = size
    big = Image.fromarray(rgb).resize((w * sub, h * sub), Image.LANCZOS)
    m = Image.fromarray((fg * 255).astype(np.uint8)).resize((w * sub, h * sub), Image.BILINEAR)
    a = np.asarray(big)
    mk = np.asarray(m) > 127
    idx = nearest(a, pal)
    blocks = idx.reshape(h, sub, w, sub).transpose(0, 2, 1, 3).reshape(h, w, sub * sub)
    mb = mk.reshape(h, sub, w, sub).transpose(0, 2, 1, 3).reshape(h, w, sub * sub)
    alpha = mb.mean(-1) >= cover
    cnt = np.zeros((h, w, len(pal)), int)
    for j in range(len(pal)):
        cnt[..., j] = ((blocks == j) & mb).sum(-1)
    return cnt.argmax(-1), alpha


def clean_orphans(idx: np.ndarray, fg: np.ndarray, passes: int = 2) -> np.ndarray:
    idx = idx.copy()
    H, W = idx.shape
    for _ in range(passes):
        changed = 0
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if not fg[y, x]:
                    continue
                nb = [idx[y + dy, x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if fg[y + dy, x + dx]]
                if len(nb) >= 3 and idx[y, x] not in nb:
                    vals, cnts = np.unique(nb, return_counts=True)
                    if cnts.max() >= 2:
                        idx[y, x] = vals[cnts.argmax()]
                        changed += 1
        if not changed:
            break
    return idx


def tidy_alpha(fg: np.ndarray) -> np.ndarray:
    """Fill pinholes, drop single-pixel spurs and specks."""
    n = ndimage.convolve(fg.astype(int), K4.astype(int), mode="constant") - fg
    fg = fg | (n >= 3)
    n = ndimage.convolve(fg.astype(int), K4.astype(int), mode="constant") - fg
    fg = fg & (n >= 2)
    return keep_main(fg, 0.0, 3)


def ink_outline(rgba: np.ndarray, dark: float = 58.0) -> np.ndarray:
    """1 px ink ring outside the silhouette; edge pixels that are already near-black become ink
    so the line weight stays exactly 1 px."""
    a = rgba.copy()
    al = a[:, :, 3] > 0
    ring = ndimage.binary_dilation(al, K4) & ~al
    edge = al & ndimage.binary_dilation(~al, K4)
    lum = a[:, :, :3].astype(float).mean(-1)
    a[edge & (lum < dark)] = (*INK, 255)
    a[ring] = (*INK, 255)
    # interior near-black pixels snap to ink too (one consistent line colour)
    a[al & (lum < 34)] = (*INK, 255)
    return a


def cut_subject(raw: Image.Image, spec: dict) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.asarray(raw.convert("RGB"))
    if spec.get("crop"):
        x0, y0, x1, y1 = spec["crop"]
        rgb = rgb[y0:y1, x0:x1]
    bgm = background_mask(rgb, spec.get("bg", "black"), spec.get("tol", 40), spec.get("erode", 10))
    fg = keep_main(~bgm, spec.get("min_frac", 0.004), 400)
    fg = ndimage.binary_fill_holes(fg) if spec.get("fill_holes", False) else fg
    for (x0, y0, x1, y1) in spec.get("erase", []):
        fg[y0:y1, x0:x1] = False
    return rgb, fg


def pixelate(rgb: np.ndarray, fg: np.ndarray, size: tuple[int, int], colors: int, punch_k=(1.15, 1.08), orphans: int = 2,
             cover: float = 0.5) -> np.ndarray:
    rgb = punch(rgb, *punch_k)
    pal = kmeans_palette(rgb[fg], colors)
    idx, alpha = block_snap(rgb, fg, size, pal, cover)
    alpha = tidy_alpha(alpha)
    idx = clean_orphans(idx, alpha, orphans) if orphans else idx
    out = np.zeros((size[1], size[0], 4), np.uint8)
    out[alpha, :3] = pal[idx[alpha]]
    out[alpha, 3] = 255
    return out


# ---------------------------------------------------------------- icons
def icon(raw: Image.Image, spec: dict) -> Image.Image:
    rgb, fg = cut_subject(raw, spec)
    ys, xs = np.where(fg)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    inner = ICON - 2 - 2 * spec.get("margin", 0)
    # square crop centred on the subject; pad with background
    cx, cy = (x0 + x1) / 2 + spec.get("dx", 0), (y0 + y1) / 2 + spec.get("dy", 0)
    s = int(side * 1.0) + 2
    X0, Y0 = int(round(cx - s / 2)), int(round(cy - s / 2))
    pad = s
    rgbp = np.pad(rgb, ((pad, pad), (pad, pad), (0, 0)))
    fgp = np.pad(fg, pad)
    crop_rgb = rgbp[Y0 + pad:Y0 + pad + s, X0 + pad:X0 + pad + s]
    crop_fg = fgp[Y0 + pad:Y0 + pad + s, X0 + pad:X0 + pad + s]
    art = pixelate(crop_rgb, crop_fg, (inner, inner), spec.get("colors", 16), tuple(spec.get("punch", (1.15, 1.08))),
                   spec.get("orphans", 0), spec.get("cover", 0.5))
    canvas = np.zeros((ICON, ICON, 4), np.uint8)
    o = (ICON - inner) // 2
    canvas[o:o + inner, o:o + inner] = art
    return Image.fromarray(ink_outline(canvas), "RGBA")


def build_icons(picks: dict, only: list[str] | None = None) -> None:
    dst = DST / "abilities"
    dst.mkdir(parents=True, exist_ok=True)
    for aid in ABILITIES:
        if only and aid not in only:
            continue
        src = SRC / "icons" / f"{aid}.png"
        if not src.exists():
            print(f"  missing pick: {src.relative_to(ROOT)}")
            continue
        img = icon(Image.open(src), picks.get("icons", {}).get(aid, {}))
        img.save(dst / f"{aid}.png")
        print(f"  abilities/{aid}.png {img.size}")


def contact_sheet(out: Path, colors: dict | None = None) -> None:
    """All icons at 1x and 3x on the dark HUD colour and on a light card colour."""
    files = [(a, DST / "abilities" / f"{a}.png") for a in ABILITIES]
    files = [(a, f) for a, f in files if f.exists()]
    n = len(files)
    cell3 = ICON * 3 + 12
    W = max(n * (ICON + 8) + 16, 5 * cell3 + 16)
    rows3 = (n + 4) // 5
    H = 16 + (ICON + 8) * 2 + 16 + rows3 * (cell3 + 14) + 8
    sheet = Image.new("RGBA", (W, H), (24, 22, 34, 255))
    d = ImageDraw.Draw(sheet)
    d.rectangle((0, 16 + ICON + 8, W, 16 + (ICON + 8) * 2), fill=(196, 200, 214, 255))
    for i, (a, f) in enumerate(files):
        im = Image.open(f).convert("RGBA")
        sheet.alpha_composite(im, (8 + i * (ICON + 8), 12))
        sheet.alpha_composite(im, (8 + i * (ICON + 8), 16 + ICON + 12))
        r, c = divmod(i, 5)
        x, y = 8 + c * cell3, 16 + (ICON + 8) * 2 + 16 + r * (cell3 + 14)
        if colors and a in colors:
            hexc = colors[a].lstrip("#")
            d.rectangle((x, y, x + ICON * 3 + 4, y + 3), fill=tuple(int(hexc[k:k + 2], 16) for k in (0, 2, 4)) + (255,))
        sheet.alpha_composite(im.resize((ICON * 3, ICON * 3), Image.NEAREST), (x + 2, y + 6))
        d.text((x + 2, y + ICON * 3 + 6), a, fill=(230, 230, 240, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"  {out.relative_to(ROOT)} {sheet.size}")


def ability_colors() -> dict:
    try:
        d = json.loads((ROOT / "client/data/balance.json").read_text(encoding="utf-8"))
        return {a["id"]: a.get("color", "#ffffff") for a in d.get("abilities", [])}
    except Exception:  # noqa: BLE001
        return {}


# ---------------------------------------------------------------- ball
def build_ball() -> None:
    ui_ball.build(DST / "ball")
    print("  ball/ball.png ball_spin.png ball_tint.png ball_tint_spin.png")


# ---------------------------------------------------------------- HUD frames + podium
# 9-slice patch margins (left, top, right, bottom) in art px, documented in docs/UI_ART.md.
NINE = {
    # the panel is meant to stretch horizontally; its slanted stripes span the height, so the
    # vertical stretch band is a single row (24) and the panel should keep its native height
    "panel": (36, 24, 24, 23),
    "portrait_frame": (16, 16, 16, 16),
    "ability_card": (12, 12, 12, 12),
    "ability_card_selected": (12, 12, 12, 12),
}


def snap8(raw: Image.Image, scale: int, colors: int, pal: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray]:
    """Paint-over of an 8x guide -> art grid: per-block colour mode (palette indices)."""
    a = np.asarray(raw.convert("RGB"))
    h, w = a.shape[0] // scale, a.shape[1] // scale
    a = a[: h * scale, : w * scale]
    if pal is None:
        pal = kmeans_palette(punch(a.reshape(-1, 3), 1.08, 1.04), colors)
    idx = nearest(punch(a, 1.08, 1.04), pal)
    blocks = idx.reshape(h, scale, w, scale)[:, 1:-1, :, 1:-1].transpose(0, 2, 1, 3).reshape(h, w, -1)
    cnt = np.zeros((h, w, len(pal)), int)
    for j in range(len(pal)):
        cnt[..., j] = (blocks == j).sum(-1)
    return cnt.argmax(-1), pal


def guide_mask(guide: Image.Image, scale: int, bg: tuple, tol: int = 10) -> np.ndarray:
    g = np.asarray(guide.convert("RGB"))[scale // 2::scale, scale // 2::scale].astype(int)
    return np.abs(g - np.array(bg)).sum(-1) > tol


def nine_slice_uniform(rgba: np.ndarray, margins: tuple, center: bool = True) -> np.ndarray:
    """Make the stretchable bands of a 9-slice texture uniform along their stretch axis, so
    Godot's NinePatchRect (STRETCH mode) never smears detail. Corners are kept as painted."""
    a = rgba.copy()
    h, w = a.shape[:2]
    l, t, r, b = margins
    mx = l + (w - l - r) // 2
    my = t + (h - t - b) // 2
    a[:t, l:w - r] = a[:t, mx:mx + 1]
    a[h - b:, l:w - r] = a[h - b:, mx:mx + 1]
    a[t:h - b, :l] = a[my:my + 1, :l]
    a[t:h - b, w - r:] = a[my:my + 1, w - r:]
    if center:
        a[t:h - b, l:w - r] = a[t:h - b, mx:mx + 1]
    return a


def edge_ink(rgba: np.ndarray) -> np.ndarray:
    a = rgba.copy()
    al = a[:, :, 3] > 0
    edge = al & ndimage.binary_dilation(~al, K4, border_value=1)
    a[edge] = (*INK, 255)
    return a


def build_hud(picks: dict) -> None:
    sys.path.insert(0, str(HERE))
    import ui_guides as UG
    dst = DST / "hud"
    dst.mkdir(parents=True, exist_ok=True)
    sheets = {}

    def load(sheet: str, src_name: str) -> np.ndarray | None:
        key = (sheet, src_name)
        if key in sheets:
            return sheets[key]
        src = SRC / "hud" / f"{src_name}.png"
        if not src.exists():
            print(f"  missing pick: {src.relative_to(ROOT)}")
            return None
        spec = picks.get("hud", {}).get(src_name, {})
        idx, pal = snap8(Image.open(src), UG.HUD_SCALE, spec.get("colors", 24))
        mask = guide_mask(Image.open(SRC / "guides" / f"{sheet}.png"), UG.HUD_SCALE, UG.BG)
        rgba = np.zeros((*idx.shape, 4), np.uint8)
        rgba[..., :3] = pal[idx]
        rgba[..., 3] = mask * 255
        sheets[key] = clean_rgba(rgba)
        return sheets[key]

    # picks.json "hud_parts" may take a part from another painted sheet of the same layout
    # (e.g. {"energy_cell_full": "hud_kit_b"}); default is the sheet named like the guide.
    parts = picks.get("hud_parts", {})
    for name, (sheet, (x, y, w, h)) in UG.HUD_BOXES.items():
        img = load(sheet, parts.get(name, sheet))
        if img is None:
            continue
        part = img[y:y + h, x:x + w].copy()
        if name in NINE:
            part = nine_slice_uniform(part, NINE[name])
        part = edge_ink(part)
        Image.fromarray(part, "RGBA").save(dst / f"{name}.png")
        print(f"  hud/{name}.png {w}x{h}" + (f" 9-slice {NINE[name]}" if name in NINE else ""))


def clean_rgba(rgba: np.ndarray) -> np.ndarray:
    """Orphan clean-up on an RGBA image (colour keys instead of palette indices)."""
    al = rgba[..., 3] > 0
    key = (rgba[..., 0].astype(np.int64) << 16) | (rgba[..., 1].astype(np.int64) << 8) | rgba[..., 2]
    uniq, inv = np.unique(key, return_inverse=True)
    inv = inv.reshape(key.shape)
    inv = clean_orphans(inv, al)
    cols = np.stack([(uniq >> 16) & 255, (uniq >> 8) & 255, uniq & 255], -1).astype(np.uint8)
    out = rgba.copy()
    out[..., :3] = cols[inv]
    return out


def build_podium(picks: dict) -> None:
    src = SRC / "studio" / "podium_raw.png"
    if not src.exists():
        print(f"  missing pick: {src.relative_to(ROOT)}")
        return
    spec = picks.get("podium", {})
    raw = Image.open(src)
    idx, pal = snap8(raw, 8, spec.get("colors", 28))
    gmask = guide_mask(Image.open(SRC / "guides" / "podium.png"), 8, (236, 236, 240), 24)
    rgb = pal[idx]
    # painted pixels that are clearly not the white background, near the guide silhouette (grass
    # tufts and flowers may poke out a little)
    paint = np.abs(rgb.astype(int) - 238).sum(-1) > spec.get("tol", 60)
    alpha = gmask | (paint & ndimage.binary_dilation(gmask, K4, iterations=2))
    # defringe: pale, unsaturated pixels on the silhouette edge are leftover white background
    f = rgb.astype(int)
    pale = (f.min(-1) > 196) & ((f.max(-1) - f.min(-1)) < 40)
    for _ in range(3):
        edge = alpha & ndimage.binary_dilation(~alpha, K4, border_value=1)
        alpha = alpha & ~(edge & pale)
    alpha = tidy_alpha(alpha)
    rgba = np.zeros((*idx.shape, 4), np.uint8)
    rgba[..., :3] = rgb
    rgba[..., 3] = alpha * 255
    rgba = clean_rgba(rgba)
    ys, xs = np.where(alpha)
    rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    pad = np.zeros((rgba.shape[0] + 2, rgba.shape[1] + 2, 4), np.uint8)
    pad[1:-1, 1:-1] = rgba
    out = ink_outline(pad)
    (DST / "studio").mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(DST / "studio" / "podium.png")
    print(f"  studio/podium.png {out.shape[1]}x{out.shape[0]}")


def main() -> None:
    what = sys.argv[1:] or ["icons", "ball", "hud", "podium", "sheet"]
    picks_path = SRC / "picks.json"
    picks = json.loads(picks_path.read_text(encoding="utf-8")) if picks_path.exists() else {}
    if "icons" in what:
        build_icons(picks)
    if "ball" in what:
        build_ball()
    if "hud" in what:
        build_hud(picks)
    if "podium" in what:
        build_podium(picks)
    if "sheet" in what:
        contact_sheet(SRC / "review/abilities_sheet.png", ability_colors())


if __name__ == "__main__":
    main()
