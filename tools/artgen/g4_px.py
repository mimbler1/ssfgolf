"""v4 clean-up: generator paint-over (8x) -> exact pixel-art frame.

1. grid snap by per-block colour mode (no blended edge colours, unlike a box average)
2. background cut constrained by the guide silhouette (drops ground shadows and strays)
3. palette lock: every frame of a character is quantised to that character's master palette
4. orphan clean-up, then a uniform 1 px dark silhouette outline
"""
from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

import g4_rig as rig

K4 = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)


def to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb.astype(float) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def nearest(rgb: np.ndarray, pal: np.ndarray) -> np.ndarray:
    """Index of the nearest palette colour (Lab) for every pixel of rgb (..., 3)."""
    a = to_lab(rgb.reshape(-1, 3))
    b = to_lab(pal)
    d = ((a[:, None, :] - b[None, :, :]) ** 2).sum(-1)
    return d.argmin(1).reshape(rgb.shape[:-1])


def kmeans_palette(rgb: np.ndarray, k: int, iters: int = 12, seed: int = 0) -> np.ndarray:
    """Palette of k colours for rgb pixels (N, 3), k-means in Lab, returned as RGB uint8."""
    rng = np.random.default_rng(seed)
    lab = to_lab(rgb)
    # init: k-means++
    cent = [lab[rng.integers(len(lab))]]
    for _ in range(1, k):
        d = np.min(((lab[:, None] - np.array(cent)[None]) ** 2).sum(-1), 1)
        cent.append(lab[rng.choice(len(lab), p=d / d.sum())])
    cent = np.array(cent)
    for _ in range(iters):
        lbl = ((lab[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
        for j in range(k):
            sel = lbl == j
            if sel.any():
                cent[j] = lab[sel].mean(0)
    lbl = ((lab[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
    out = []
    for j in range(k):
        sel = lbl == j
        if sel.any():
            out.append(np.median(rgb[sel], 0))
    return np.array(out).round().astype(np.uint8)


def snap(gen: Image.Image, pal: np.ndarray, scale: int = rig.GEN_SCALE) -> np.ndarray:
    """Per-block mode of palette indices -> (H, W) index map at art resolution."""
    a = np.asarray(gen.convert("RGB"))
    h, w = a.shape[0] // scale, a.shape[1] // scale
    idx = nearest(a[: h * scale, : w * scale], pal)
    blocks = idx.reshape(h, scale, w, scale).transpose(0, 2, 1, 3).reshape(h, w, scale * scale)
    # mode, ignoring a 1 px border of each block (generator edges drift a little)
    inner = idx.reshape(h, scale, w, scale)[:, 1:-1, :, 1:-1].transpose(0, 2, 1, 3).reshape(h, w, -1)
    n = len(pal)
    cnt = np.zeros((h, w, n), int)
    for j in range(n):
        cnt[..., j] = (inner == j).sum(-1) * 2 + (blocks == j).sum(-1)
    return cnt.argmax(-1)


def cut(idx: np.ndarray, pal: np.ndarray, guide_alpha: np.ndarray, bg_tol: float = 9.0, grow: int = 2,
        bg=(236, 236, 240), strict: np.ndarray | None = None) -> np.ndarray:
    """Foreground mask: inside the grown guide silhouette and not background-coloured
    pixels connected to the outside."""
    strict = guide_alpha if strict is None else strict
    lab = to_lab(pal[idx])
    bgl = to_lab(np.array([bg], np.uint8))[0]
    near_bg = np.sqrt(((lab - bgl) ** 2).sum(-1)) <= bg_tol
    zone = ndimage.binary_dilation(guide_alpha, K4, iterations=grow)
    fg = zone.copy()
    # flood background from outside the zone through near-bg pixels
    seed = ~zone
    bgmask = ndimage.binary_propagation(seed, structure=K4, mask=seed | near_bg)
    fg &= ~bgmask
    # background-coloured pockets outside the strict guide silhouette (gaps between legs/arms)
    fg &= ~(near_bg & ~strict)
    # keep the main connected body (+ anything touching it)
    lbl, n = ndimage.label(fg, K4)
    if n > 1:
        sizes = ndimage.sum(fg, lbl, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= 6
        fg = keep[lbl]
    return fg


def clean(idx: np.ndarray, fg: np.ndarray, passes: int = 2) -> np.ndarray:
    """Replace orphan pixels (no 4-neighbour of the same colour) with the neighbour majority."""
    idx = idx.copy()
    H, W = idx.shape
    for _ in range(passes):
        changed = 0
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if not fg[y, x]:
                    continue
                v = idx[y, x]
                nb = [idx[y + dy, x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if fg[y + dy, x + dx]]
                if len(nb) >= 3 and v not in nb:
                    vals, cnts = np.unique(nb, return_counts=True)
                    if cnts.max() >= 2:
                        idx[y, x] = vals[cnts.argmax()]
                        changed += 1
        if not changed:
            break
    return idx


def fill_holes(fg: np.ndarray) -> np.ndarray:
    """Fill 1 px pinholes in the silhouette."""
    n = ndimage.convolve(fg.astype(int), K4.astype(int), mode="constant") - fg
    return fg | (n >= 4)


def outline_img(rgba: np.ndarray, color=rig.OUTLINE, inner_dark: float = 70.0) -> np.ndarray:
    """1 px outline ring outside the silhouette. Silhouette-edge pixels that are already near
    black are folded into the outline colour so the line never doubles up."""
    a = rgba.copy()
    al = a[:, :, 3] > 0
    ring = ndimage.binary_dilation(al, K4) & ~al
    edge = al & ndimage.binary_dilation(~al, K4)
    lum = a[:, :, :3].astype(float).mean(-1)
    dark = edge & (lum < inner_dark)
    a[dark] = (*color, 255)
    # ring only where the silhouette edge is not already an outline pixel
    lit_edge = al & ~dark
    a[ring & ndimage.binary_dilation(lit_edge, K4)] = (*color, 255)
    return a


def compose(idx: np.ndarray, fg: np.ndarray, pal: np.ndarray) -> np.ndarray:
    out = np.zeros((*idx.shape, 4), np.uint8)
    out[fg, :3] = pal[idx[fg]]
    out[fg, 3] = 255
    return out


def ground(rgba: np.ndarray, pivot_y: int = rig.PIV[1]) -> tuple[np.ndarray, int]:
    al = rgba[:, :, 3] > 0
    rows = np.where(al.any(1))[0]
    if not len(rows):
        return rgba, 0
    dy = (pivot_y - 1) - rows[-1]
    return np.roll(rgba, dy, 0) if dy else rgba, dy


def guide_alpha(guide_rgba: Image.Image) -> np.ndarray:
    return np.asarray(guide_rgba)[:, :, 3] > 0


def fg_pixels(gen: Image.Image, galpha: np.ndarray, step: int = 5) -> np.ndarray:
    a = np.asarray(gen.convert("RGB"))
    zone = np.kron(ndimage.binary_erosion(galpha, K4, iterations=1), np.ones((rig.GEN_SCALE, rig.GEN_SCALE), bool))
    return a[zone][::step]


def drop_shadow(idx: np.ndarray, fg: np.ndarray, pal: np.ndarray, galpha: np.ndarray) -> np.ndarray:
    """Remove grey, low-saturation ground-shadow pixels below/around the feet outside the guide."""
    rgb = pal[idx].astype(float)
    sat = rgb.max(-1) - rgb.min(-1)
    rows = np.where(galpha.any(1))[0]
    bottom = rows[-1] if len(rows) else rig.H
    yy = np.arange(fg.shape[0])[:, None] + np.zeros(fg.shape, int)
    shadowish = (sat < 34) & (rgb.mean(-1) > 60) & (yy >= bottom - 4) & ~galpha
    out = fg & ~shadowish
    # a ground shadow spreads sideways past the shoes: drop anything in the bottom rows that is
    # more than 1 px outside the guide silhouette
    near = ndimage.binary_dilation(galpha, np.ones((1, 3), bool), iterations=1)
    out &= ~((yy >= bottom - 3) & ~near)
    # anything below the guide's lowest row is shadow
    out[bottom + 1:] = False
    return out


def process(gen: Image.Image, guide_rgba: Image.Image, pal: np.ndarray, bg=(236, 236, 240)) -> np.ndarray:
    g = guide_alpha(guide_rgba)
    ga = np.asarray(guide_rgba)
    strict = g & ~np.all(ga[:, :, :3] == np.array(rig.OUTLINE), -1)
    idx = snap(gen, pal)
    fg = cut(idx, pal, g, strict=strict, bg=bg)
    fg = drop_shadow(idx, fg, pal, g)
    fg = fill_holes(fg)
    idx = clean(idx, fg)
    rgba = outline_img(smooth(compose(idx, fg, pal)))
    rgba, _ = ground(rgba)
    return rgba


def smooth(rgba: np.ndarray, protect_lum=(55, 215)) -> np.ndarray:
    """Cluster clean-up: a pixel whose colour appears at most once in its 8-neighbourhood while
    one other colour holds >= 5 of the 8 takes that colour. Very dark (lines, pupils) and very
    bright (eye whites, specular) pixels are kept so faces survive."""
    a = rgba.copy()
    H, W = a.shape[:2]
    key = (a[:, :, 0].astype(np.int64) << 16) | (a[:, :, 1].astype(np.int64) << 8) | a[:, :, 2]
    key[a[:, :, 3] == 0] = -1
    lum = a[:, :, :3].astype(float).mean(-1)
    out = a.copy()
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            k = key[y, x]
            if k < 0 or lum[y, x] < protect_lum[0] or lum[y, x] > protect_lum[1]:
                continue
            nb = key[y - 1:y + 2, x - 1:x + 2].ravel()
            nb = np.delete(nb, 4)
            edge = (nb < 0).any()
            if (nb == k).sum() > (0 if edge else 1):
                continue
            nbo = nb[nb >= 0]
            if len(nbo) == 0:
                continue
            vals, cnt = np.unique(nbo, return_counts=True)
            j = cnt.argmax()
            if cnt[j] >= (3 if edge else 5):
                yy, xx = np.argwhere(key[y - 1:y + 2, x - 1:x + 2] == vals[j])[0]
                out[y, x] = a[y - 1 + yy, x - 1 + xx]
    return purge_flecks(out)


def purge_flecks(a: np.ndarray, max_size: int = 12, min_dist: float = 28.0) -> np.ndarray:
    """Small same-colour clusters (<= max_size px) that touch the transparent edge and differ
    from every surrounding colour by > min_dist (Lab) are generator flecks: recolour them with
    the most common surrounding colour. Dark clusters (outline, pupils) are kept."""
    out = a.copy()
    H, W = a.shape[:2]
    key = (a[:, :, 0].astype(np.int64) << 16) | (a[:, :, 1].astype(np.int64) << 8) | a[:, :, 2]
    key[a[:, :, 3] == 0] = -1
    lab = to_lab(a[:, :, :3])
    alpha = a[:, :, 3] > 0
    dark = a[:, :, :3].astype(float).mean(-1) < 58
    edge = alpha & ~dark & ndimage.binary_dilation(~alpha, np.ones((3, 3), bool), iterations=3)
    for k in np.unique(key[edge]):
        lbl, n = ndimage.label(key == k, np.ones((3, 3), bool))
        for j in range(1, n + 1):
            m = lbl == j
            if m.sum() > max_size or not (m & edge).any():
                continue
            if a[m][:, :3].astype(float).mean() < 55:
                continue
            ring = ndimage.binary_dilation(m, np.ones((3, 3), bool)) & ~m & alpha & ~dark
            if not ring.any():
                ring = ndimage.binary_dilation(m, np.ones((3, 3), bool)) & ~m & alpha
                if not ring.any():
                    continue
                v, c = np.unique(key[ring], return_counts=True)
                yy, xx = np.argwhere((key == v[c.argmax()]) & ring)[0]
                out[m] = a[yy, xx]
                continue
            d = np.sqrt(((lab[ring] - lab[m][0]) ** 2).sum(-1))
            if d.min() <= min_dist:
                continue
            v, c = np.unique(key[ring], return_counts=True)
            yy, xx = np.argwhere((key == v[c.argmax()]) & ring)[0]
            out[m] = a[yy, xx]
    return out


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
