"""Composition guides for the ability icons (img2img inits, not game art).

Each guide is a 1024 px flat-shaded layout on black: it fixes the silhouette, the subject scale,
the accent colour (client/data/balance.json) and the top-left light, so the 15 paint-overs come
out as one consistent set. SDXL + pixel-art-xl then repaints the guide (gen_ui.py, jobs/ui_icons.json)
and build_ui.py cuts the chosen paint-over down to 48 art px.

usage: tools/artgen/.venv/Scripts/python tools/artgen/ui_guides.py   -> art/ui/guides/icon_<id>.png
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/ui/guides"
W = 1024
BG = (6, 6, 8)
INK = (28, 18, 28)
LW = 16  # guide outline width (about 0.75 art px after the cut to 48)


def hexc(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(c: tuple, k: float) -> tuple:
    """k > 0 lightens towards warm white, k < 0 darkens towards cool purple."""
    if k >= 0:
        t = (255, 250, 230)
        return tuple(int(c[i] + (t[i] - c[i]) * k) for i in range(3))
    t = (40, 26, 70)
    return tuple(int(c[i] + (t[i] - c[i]) * -k) for i in range(3))


class G:
    def __init__(self):
        self.im = Image.new("RGB", (W, W), BG)
        self.d = ImageDraw.Draw(self.im)

    def sphere(self, cx, cy, r, base, dimples=True, dim_k=-0.22):
        """Banded sphere lit from the top left, optional golf dimples."""
        self.d.ellipse((cx - r - LW, cy - r - LW, cx + r + LW, cy + r + LW), fill=INK)
        a = np.asarray(self.im).copy()
        yy, xx = np.mgrid[0:W, 0:W]
        nx, ny = (xx - cx) / r, (yy - cy) / r
        inside = nx * nx + ny * ny <= 1
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        lam = nx * -0.55 + ny * -0.62 + nz * 0.56
        bands = [(-0.2, -0.55), (0.15, -0.3), (0.55, 0.0), (0.85, 0.35), (9, 0.7)]
        col = np.zeros((W, W, 3))
        for th, k in reversed(bands):
            col[lam <= th] = shade(base, k)
        spec = np.hypot(nx + 0.38, ny + 0.42) < 0.2
        col[spec] = shade(base, 0.9)
        if dimples:
            pts = []
            n = 70
            for i in range(n):
                phi = math.acos(1 - 2 * (i + 0.5) / n)
                th = math.pi * (1 + 5 ** 0.5) * i
                p = (math.cos(th) * math.sin(phi), math.sin(th) * math.sin(phi), math.cos(phi))
                if p[2] > 0.25:
                    pts.append(p)
            for (px, py, pz) in pts:
                dx, dy = cx + px * r, cy + py * r
                rr = r * 0.075 * (0.4 + 0.6 * pz)
                m = np.hypot((xx - dx) / (rr * (0.5 + 0.5 * pz) + 1e-3), (yy - dy) / rr) <= 1
                m &= inside
                col[m] = np.array([shade(tuple(int(v) for v in c), dim_k) for c in [(128, 128, 128)]][0]) * 0 + \
                    col[m] * (1 + dim_k)
        a[inside] = col[inside].clip(0, 255).astype(np.uint8)
        self.im = Image.fromarray(a)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, fill, ink=True, w=LW):
        if ink:
            self.d.polygon(pts, fill=fill, outline=INK, width=w)
        else:
            self.d.polygon(pts, fill=fill)

    def ellipse(self, box, fill, ink=True, w=LW):
        self.d.ellipse(box, fill=fill, outline=INK if ink else None, width=w if ink else 0)

    def line(self, pts, fill, w):
        self.d.line(pts, fill=INK, width=w + LW * 2, joint="curve")
        self.d.line(pts, fill=fill, width=w, joint="curve")

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        self.im.save(OUT / f"icon_{name}.png")


WHITE = (236, 238, 246)


def standard():
    g = G()
    tee = hexc("#c98a4b")
    g.sphere(512, 400, 290, WHITE)
    g.poly([(400, 680), (624, 680), (560, 760), (540, 950), (484, 950), (464, 760)], tee)
    g.poly([(420, 690), (600, 690), (590, 705), (430, 705)], shade(tee, 0.45), ink=False)
    g.poly([(492, 770), (512, 770), (512, 930), (492, 930)], shade(tee, 0.35), ink=False)
    g.sphere(512, 400, 290, WHITE)
    g.save("standard")


def nitro():
    g = G()
    c = hexc("#ff7b2e")
    cx, cy, r = 650, 370, 240
    def drop(scale, col, ink):
        # teardrop from the ball centre out to the lower left
        tip = (cx - 640 * scale, cy + 640 * scale)
        pts = [tip]
        for a in np.radians(np.linspace(215, 415, 24)):
            pts.append((cx + math.cos(a) * r * 1.08 * scale, cy + math.sin(a) * r * 1.08 * scale))
        g.poly(pts, col, ink=ink)
    drop(1.25, shade(c, -0.3), True)
    drop(1.0, c, False)
    drop(0.7, hexc("#ffd23f"), False)
    drop(0.4, (255, 250, 220), False)
    for (x0, y0, x1, y1) in [(120, 260, 330, 150), (90, 430, 260, 330), (520, 930, 700, 830)]:
        g.line([(x0, y0), (x1, y1)], (255, 240, 210), 22)
    g.sphere(cx, cy, r, WHITE)
    g.save("nitro")


def sticky():
    g = G()
    c = hexc("#b65cff")
    g.sphere(512, 500, 300, WHITE)
    # goo cap with drips
    pts = [(230, 420), (300, 260), (420, 190), (600, 190), (730, 270), (800, 420), (790, 600), (750, 560),
           (730, 470), (690, 520), (680, 700), (630, 720), (610, 520), (560, 480), (520, 560), (500, 620),
           (460, 600), (440, 480), (360, 470), (330, 640), (280, 650), (270, 470)]
    g.poly(pts, c)
    g.poly([(320, 300), (420, 230), (560, 225), (480, 280), (380, 330)], shade(c, 0.55), ink=False)
    g.ellipse((620, 780, 690, 870), c)
    g.ellipse((290, 720, 340, 780), shade(c, -0.2))
    g.save("sticky")


def grenade():
    g = G()
    c = hexc("#56c271")
    g.sphere(500, 560, 300, c, dim_k=-0.25)
    steel = (150, 156, 172)
    g.poly([(400, 300), (600, 300), (600, 200), (400, 200)], steel)
    g.poly([(420, 210), (470, 210), (470, 290), (420, 290)], shade(steel, 0.5), ink=False)
    # lever
    g.poly([(590, 200), (780, 250), (830, 460), (760, 470), (720, 310), (590, 300)], shade(steel, -0.15))
    # pin ring
    g.d.ellipse((300 - LW, 90 - LW, 470 + LW, 260 + LW), outline=INK, width=60 + 2 * LW)
    g.d.ellipse((300, 90, 470, 260), outline=hexc("#f2c94c"), width=44)
    g.save("grenade")


def heavy():
    g = G()
    c = hexc("#7d8597")
    iron = shade(c, -0.35)
    # kettlebell handle
    g.d.ellipse((290 - LW, 90 - LW, 734 + LW, 560 + LW), outline=INK, width=110 + 2 * LW)
    g.d.ellipse((290, 90, 734, 560), outline=iron, width=110)
    g.d.arc((330, 130, 694, 520), 200, 300, fill=shade(c, 0.3), width=26)
    g.sphere(512, 620, 330, iron, dimples=False)
    # weight band with rivets
    g.poly([(200, 590), (824, 590), (824, 680), (200, 680)], shade(c, 0.05))
    for x in range(260, 800, 110):
        g.ellipse((x - 22, 613, x + 22, 657), shade(c, 0.6), w=8)
    g.save("heavy")


def air_brake():
    g = G()
    c = hexc("#4cc9f0")
    for x0 in (180, 512, 844):
        g.line([(x0, 420), (512, 700)], (226, 228, 240), 26)
    pts = [(140, 430)] + [(512 + math.cos(a) * 380, 430 - math.sin(a) * 330) for a in np.linspace(math.pi, 0, 24)] + [(884, 430)]
    pts += [(800, 400), (700, 440), (600, 400), (512, 440), (420, 400), (320, 440), (220, 400)]
    g.poly(pts, c)
    g.poly([(330, 150), (440, 115), (420, 300), (300, 360)], shade(c, 0.5), ink=False)
    g.poly([(600, 120), (700, 160), (760, 380), (640, 380)], shade(c, -0.3), ink=False)
    g.sphere(512, 790, 170, WHITE)
    g.save("air_brake")


def anti_grav():
    g = G()
    c = hexc("#7cf2c9")
    for i, (y, rx, ry) in enumerate([(890, 340, 80), (700, 250, 62)]):
        g.d.ellipse((512 - rx - LW, y - ry - LW, 512 + rx + LW, y + ry + LW), outline=INK, width=52 + 2 * LW)
        g.d.ellipse((512 - rx, y - ry, 512 + rx, y + ry), outline=shade(c, 0.15 * i), width=52)
        g.d.arc((512 - rx + 10, y - ry + 6, 512 + rx - 10, y + ry - 6), 190, 300, fill=shade(c, 0.6), width=16)
    for x in (140, 884):
        g.poly([(x, 300), (x - 110, 450), (x - 45, 450), (x - 45, 640), (x + 45, 640), (x + 45, 450), (x + 110, 450)], c)
        g.poly([(x, 330), (x - 70, 430), (x - 25, 430), (x - 25, 610), (x - 5, 610), (x - 5, 430)], shade(c, 0.55), ink=False)
    g.sphere(512, 330, 240, WHITE)
    g.save("anti_grav")


def free_shot():
    g = G()
    c = hexc("#ffe066")
    # tilted ticket with notches
    cx, cy, w, h, a = 512, 520, 820, 470, -0.32
    def rot(x, y):
        return (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))
    pts = []
    for (x, y) in [(-w / 2, -h / 2), (w / 2, -h / 2)]:
        pts.append(rot(x, y))
    for t in np.linspace(-math.pi / 2, math.pi / 2, 9):
        pts.append(rot(w / 2 - math.cos(t) * 60, math.sin(t) * 60))
    pts += [rot(w / 2, h / 2), rot(-w / 2, h / 2)]
    for t in np.linspace(math.pi / 2, -math.pi / 2, 9):
        pts.append(rot(-w / 2 + math.cos(t) * 60, math.sin(t) * 60))
    g.poly(pts, c)
    inner = [rot(-w / 2 + 90, -h / 2 + 50), rot(w / 2 - 90, -h / 2 + 50), rot(w / 2 - 90, h / 2 - 50), rot(-w / 2 + 90, h / 2 - 50)]
    g.poly(inner, shade(c, -0.15), w=10)
    star = []
    for i in range(10):
        r = 150 if i % 2 == 0 else 62
        t = -math.pi / 2 + i * math.pi / 5
        star.append(rot(math.cos(t) * r, math.sin(t) * r + 10))
    g.poly(star, (255, 252, 236))
    g.poly([rot(-w / 2 + 20, -h / 2 + 20), rot(w / 2 - 20, -h / 2 + 20), rot(w / 2 - 40, -h / 2 + 45), rot(-w / 2 + 40, -h / 2 + 45)],
           shade(c, 0.6), ink=False)
    g.save("free_shot")


def ice():
    g = G()
    c = hexc("#a5e8ff")
    # ball frozen inside a chunky faceted ice block, crystal shards on top, icicles below
    block = [(190, 330), (330, 210), (520, 250), (700, 190), (850, 330), (870, 640), (760, 820), (520, 860), (260, 800), (160, 620)]
    shards = [[(300, 300), (360, 60), (450, 260)], [(470, 260), (560, 20), (620, 240)], [(650, 230), (800, 110), (780, 300)]]
    for sh in shards:
        g.poly(sh, shade(c, -0.1))
        g.poly([sh[0], sh[1], ((sh[0][0] + sh[2][0]) / 2, (sh[0][1] + sh[2][1]) / 2 + 10)], shade(c, 0.5), ink=False)
    for (x, l) in [(320, 120), (450, 170), (600, 110), (720, 90)]:
        g.poly([(x - 40, 800), (x + 40, 800), (x, 820 + l)], shade(c, -0.15))
    g.poly(block, shade(c, -0.05))
    g.sphere(515, 540, 220, (214, 240, 252), dim_k=-0.15)
    # translucent ice over the ball: blend the block colour in
    lay = Image.new("RGB", (W, W), (0, 0, 0))
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).polygon([(p[0] + (512 - p[0]) * 0.06, p[1] + (520 - p[1]) * 0.06) for p in block], fill=110)
    ImageDraw.Draw(lay).rectangle((0, 0, W, W), fill=shade(c, 0.1))
    g.im = Image.composite(lay, g.im, m)
    g.d = ImageDraw.Draw(g.im)
    # facets and glints
    g.poly([(190, 330), (330, 210), (520, 250), (420, 340), (260, 380)], shade(c, 0.55), ink=False)
    g.poly([(850, 330), (870, 640), (760, 820), (720, 600)], shade(c, -0.3), ink=False)
    g.poly([(260, 420), (320, 380), (300, 520), (250, 560)], (255, 255, 255), ink=False)
    g.d.line([(190, 330), (330, 210), (520, 250), (700, 190), (850, 330), (870, 640), (760, 820), (520, 860), (260, 800), (160, 620), (190, 330)],
             fill=INK, width=LW)
    g.save("ice")


def laser():
    g = G()
    c = hexc("#ff3d6e")
    g.line([(60, 960), (512, 512)], (255, 160, 180), 26)
    g.sphere(512, 512, 200, WHITE)
    g.d.ellipse((512 - 400 - LW, 512 - 400 - LW, 512 + 400 + LW, 512 + 400 + LW), outline=INK, width=48 + 2 * LW)
    g.d.ellipse((512 - 400, 512 - 400, 512 + 400, 512 + 400), outline=c, width=48)
    for (x0, y0, x1, y1) in [(512, 40, 512, 270), (512, 754, 512, 984), (40, 512, 270, 512), (754, 512, 984, 512)]:
        g.line([(x0, y0), (x1, y1)], c, 40)
    g.ellipse((496, 496, 528, 528), c, w=6)
    g.save("laser")


def magnet():
    g = G()
    c = hexc("#e5383b")
    steel = (214, 220, 232)
    # horseshoe drawn opening downwards on its own layer, then tilted towards the ball
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx, cy, rm, th, leg = 512, 420, 230, 170, 230
    box = (cx - rm - th / 2, cy - rm - th / 2, cx + rm + th / 2, cy + rm + th / 2)
    boxo = (box[0] - LW, box[1] - LW, box[2] + LW, box[3] + LW)
    d.arc(boxo, 180, 360, fill=INK, width=th + 2 * LW)
    for x in (cx - rm, cx + rm):
        d.rectangle((x - th / 2 - LW, cy - 2, x + th / 2 + LW, cy + leg + 150 + LW), fill=INK)
    d.arc(box, 180, 360, fill=c, width=th)
    for x in (cx - rm, cx + rm):
        d.rectangle((x - th / 2, cy - 2, x + th / 2, cy + leg), fill=c)
        d.rectangle((x - th / 2, cy + leg + LW, x + th / 2, cy + leg + 150), fill=steel)
        d.rectangle((x - th / 2 + 20, cy + leg + LW + 10, x - th / 2 + 50, cy + leg + 140), fill=(255, 255, 255))
    d.arc((box[0] + 30, box[1] + 30, box[2] - 30, box[3] - 30), 200, 260, fill=shade(c, 0.55), width=34)
    lay = lay.rotate(38, resample=Image.BICUBIC, center=(512, 512), translate=(-110, -110))
    g.im.paste(lay, (0, 0), lay)
    g.d = ImageDraw.Draw(g.im)
    for k in range(2):
        r = 190 + k * 80
        g.d.arc((810 - r, 810 - r, 810 + r, 810 + r), 200, 250, fill=INK, width=40 + 2 * LW)
        g.d.arc((810 - r, 810 - r, 810 + r, 810 + r), 202, 248, fill=(255, 214, 222), width=40)
    g.sphere(810, 810, 150, WHITE)
    g.save("magnet")


def mulligan():
    g = G()
    c = hexc("#c9a227")
    g.sphere(512, 540, 230, WHITE)
    # circular arrow, counter-clockwise, gap at the top right
    r, w = 380, 80
    t0, t1 = math.radians(-40), math.radians(250)
    outer = [(512 + math.cos(t) * (r + w / 2), 540 - math.sin(t) * (r + w / 2)) for t in np.linspace(t0, t1, 50)]
    inner = [(512 + math.cos(t) * (r - w / 2), 540 - math.sin(t) * (r - w / 2)) for t in np.linspace(t1, t0, 50)]
    g.poly(outer + inner, c)
    # arrow head at t0 end pointing clockwise-down (rewind)
    tip = (512 + math.cos(t0 - 0.55) * r, 540 - math.sin(t0 - 0.55) * r)
    base_o = (512 + math.cos(t0) * (r + 170), 540 - math.sin(t0) * (r + 170))
    base_i = (512 + math.cos(t0) * (r - 170), 540 - math.sin(t0) * (r - 170))
    g.poly([base_o, tip, base_i], shade(c, 0.15))
    g.d.arc((512 - r, 540 - r, 512 + r, 540 + r), 120, 220, fill=shade(c, 0.6), width=20)
    g.save("mulligan")


def shield():
    g = G()
    c = hexc("#5aa9ff")
    rim = (200, 208, 224)
    pts = [(170, 140), (512, 60), (854, 140), (840, 520), (720, 780), (512, 960), (304, 780), (184, 520)]
    g.poly(pts, rim)
    ins = [(240, 200), (512, 135), (784, 200), (772, 510), (670, 730), (512, 875), (354, 730), (252, 510)]
    g.poly(ins, c, w=10)
    g.poly([(512, 135), (784, 200), (772, 510), (670, 730), (512, 875)], shade(c, -0.25), ink=False)
    g.sphere(512, 470, 170, WHITE)
    g.save("shield")


def super_():
    g = G()
    c = hexc("#ffd60a")
    burst = []
    for i in range(24):
        r = 490 if i % 2 == 0 else 330
        t = i * math.pi / 12 + 0.1
        burst.append((512 + math.cos(t) * r, 512 + math.sin(t) * r))
    g.poly(burst, shade(c, 0.35))
    burst2 = [(512 + (p[0] - 512) * 0.78, 512 + (p[1] - 512) * 0.78) for p in burst]
    g.poly(burst2, (255, 252, 220), ink=False)
    g.sphere(512, 512, 270, c, dim_k=-0.18)
    for (x, y, s) in [(170, 170, 60), (860, 230, 46), (820, 860, 56)]:
        st = [(x + math.cos(-math.pi / 2 + i * math.pi / 4) * (s if i % 2 == 0 else s * 0.35),
               y + math.sin(-math.pi / 2 + i * math.pi / 4) * (s if i % 2 == 0 else s * 0.35)) for i in range(8)]
        g.poly(st, (255, 255, 240), w=8)
    g.save("super")


def zig_zag():
    g = G()
    c = hexc("#c77dff")
    bolt = [(640, 30), (330, 470), (500, 470), (250, 990), (800, 380), (600, 380), (820, 30)]
    g.poly(bolt, c)
    g.poly([(650, 60), (790, 60), (590, 400), (380, 450)], shade(c, 0.5), ink=False)
    g.poly([(600, 400), (770, 400), (330, 900)], shade(c, -0.3), ink=False)
    g.sphere(270, 820, 175, WHITE)
    g.save("zig_zag")


ALL = {"standard": standard, "nitro": nitro, "sticky": sticky, "grenade": grenade, "heavy": heavy,
       "air_brake": air_brake, "anti_grav": anti_grav, "free_shot": free_shot, "ice": ice, "laser": laser,
       "magnet": magnet, "mulligan": mulligan, "shield": shield, "super": super_, "zig_zag": zig_zag}


# ---------------------------------------------------------------- HUD kit guides
# Drawn at art resolution, then upscaled 8x (the LoRA paints ~8 px blocks, so a paint-over of an
# 8x guide snaps back onto the art grid exactly). Geometry is final here: build_ui.py relies on
# these boxes for the 9-slice cuts.
HUD_SCALE = 8
HUD_BOXES = {
    # name: (sheet, (x, y, w, h)) in art px on that sheet
    "panel": ("hud_panel", (8, 8, 160, 48)),
    "portrait_frame": ("hud_kit", (6, 6, 64, 64)),
    "ability_card": ("hud_kit", (78, 6, 52, 60)),
    "ability_card_selected": ("hud_kit", (136, 6, 52, 60)),
    "energy_cell_empty": ("hud_kit", (8, 84, 14, 24)),
    "energy_cell_full": ("hud_kit", (28, 84, 14, 24)),
}
HUD_INK = (28, 18, 28)
BODY = [(46, 40, 74), (36, 31, 60), (27, 23, 46), (20, 17, 34)]          # dark purple-navy ramp
STEEL = [(232, 236, 248), (176, 184, 208), (120, 126, 158), (78, 80, 112)]
GOLD = [(255, 244, 176), (255, 214, 64), (222, 150, 30), (150, 86, 26)]
CYAN = [(220, 255, 255), (110, 230, 255), (40, 160, 230), (24, 90, 160)]


def _chamfer_poly(x, y, w, h, c_tl, c_br, c_tr=0, c_bl=0):
    return [(x + c_tl, y), (x + w - 1 - c_tr, y), (x + w - 1, y + c_tr), (x + w - 1, y + h - 1 - c_br),
            (x + w - 1 - c_br, y + h - 1), (x + c_bl, y + h - 1), (x, y + h - 1 - c_bl), (x, y + c_tl)]


def _bevel_frame(d, x, y, w, h, ch, rim, body, rim_w=3):
    """Ink outline, light rim top/left, mid rim bottom/right, inner ink line, body fill.
    Chamfered top-left and bottom-right corners (the slanted arcade look)."""
    d.polygon(_chamfer_poly(x, y, w, h, ch, ch), fill=HUD_INK)
    d.polygon(_chamfer_poly(x + 1, y + 1, w - 2, h - 2, ch - 1, ch - 1), fill=rim[2])
    # light rim along the top edge and the left edge (light from the top left)
    d.polygon([(x + ch, y + 1), (x + w - 2, y + 1), (x + w - 2 - 0, y + rim_w - 1), (x + ch + rim_w - 2, y + rim_w - 1),
               (x + rim_w - 1, y + ch + rim_w - 2), (x + rim_w - 1, y + h - 2 - ch + 1), (x + 1, y + h - 2), (x + 1, y + ch)],
              fill=rim[1])
    d.line([(x + ch, y + 1), (x + w - 3, y + 1)], fill=rim[0])
    d.line([(x + 1, y + ch), (x + ch, y + 1)], fill=rim[0])
    d.line([(x + w - 2, y + h - 1 - ch), (x + w - 1 - ch, y + h - 2), (x + rim_w, y + h - 2)], fill=rim[3])
    i = rim_w
    d.polygon(_chamfer_poly(x + i, y + i, w - 2 * i, h - 2 * i, max(ch - i + 1, 1), max(ch - i + 1, 1)), fill=HUD_INK)
    d.polygon(_chamfer_poly(x + i + 1, y + i + 1, w - 2 * i - 2, h - 2 * i - 2, max(ch - i, 1), max(ch - i, 1)), fill=body[1])


def hud_panel():
    aw, ah = 176, 64
    im = Image.new("RGB", (aw, ah), BG)
    d = ImageDraw.Draw(im)
    x, y, w, h = HUD_BOXES["panel"][1]
    _bevel_frame(d, x, y, w, h, 10, STEEL, BODY, rim_w=3)
    # body: lighter glass band at the top, darker towards the bottom
    d.rectangle((x + 12, y + 5, x + w - 6, y + 12), fill=BODY[0])
    d.rectangle((x + 6, y + h - 13, x + w - 14, y + h - 6), fill=BODY[2])
    # slanted gold accent stripes at the left end and a thin gold trim under the top rim
    d.polygon([(x + 4, y + 20), (x + 20, y + 4), (x + 27, y + 4), (x + 4, y + 27)], fill=GOLD[1])
    d.polygon([(x + 4, y + 31), (x + 31, y + 4), (x + 34, y + 4), (x + 4, y + 34)], fill=GOLD[2])
    d.line([(x + 38, y + 4), (x + w - 6, y + 4)], fill=GOLD[2])
    # vent slots on the right end (inside the right 9-slice margin)
    for k in range(3):
        vx = x + w - 20 + k * 4
        d.polygon([(vx, y + 30), (vx + 2, y + 30), (vx, y + 36), (vx - 2, y + 36)], fill=BODY[3])
        d.line([(vx + 2, y + 31), (vx, y + 36)], fill=BODY[0])
    d.line([(x + 5, y + 21), (x + 21, y + 5)], fill=GOLD[0])
    # rivets in the right-hand corners
    for (rx, ry) in [(x + w - 11, y + 8), (x + w - 22, y + h - 10)]:
        d.rectangle((rx, ry, rx + 2, ry + 2), fill=STEEL[1])
        d.point((rx, ry), fill=STEEL[0])
        d.point((rx + 2, ry + 2), fill=STEEL[3])
    im.resize((aw * HUD_SCALE, ah * HUD_SCALE), Image.NEAREST).save(OUT / "hud_panel.png")


def hud_kit():
    aw, ah = 192, 128
    im = Image.new("RGB", (aw, ah), BG)
    d = ImageDraw.Draw(im)
    # portrait frame: thick steel bevel with gold corner brackets, open window
    x, y, w, h = HUD_BOXES["portrait_frame"][1]
    _bevel_frame(d, x, y, w, h, 1, STEEL, BODY, rim_w=5)
    d.rectangle((x + 7, y + 7, x + w - 8, y + h - 8), fill=BG)
    for (cx, cy, sx, sy) in [(x, y, 1, 1), (x + w - 1, y, -1, 1), (x, y + h - 1, 1, -1), (x + w - 1, y + h - 1, -1, -1)]:
        pts = [(cx + sx * 2, cy + sy * 2), (cx + sx * 15, cy + sy * 2), (cx + sx * 15, cy + sy * 5), (cx + sx * 5, cy + sy * 5),
               (cx + sx * 5, cy + sy * 15), (cx + sx * 2, cy + sy * 15)]
        d.polygon(pts, fill=GOLD[1], outline=HUD_INK)
    # ability cards: dark body, steel (or gold when selected) rim, chamfered corners
    for key, rim, glow in (("ability_card", STEEL, False), ("ability_card_selected", GOLD, True)):
        x, y, w, h = HUD_BOXES[key][1]
        _bevel_frame(d, x, y, w, h, 8, rim, BODY, rim_w=3)
        d.rectangle((x + 10, y + 5, x + w - 6, y + 11), fill=BODY[0])
        d.rectangle((x + 5, y + h - 12, x + w - 11, y + h - 6), fill=BODY[2])
        if glow:
            d.line([(x + 11, y + 5), (x + w - 6, y + 5)], fill=GOLD[2])
            # inner glow line just inside the rim
            d.line([(x + 5, y + 12), (x + 5, y + h - 8)], fill=GOLD[3])
        # corner hardware: rivets top-right and bottom-left, slanted ticks in the chamfer corners
        for (rx, ry) in [(x + w - 9, y + 6), (x + 6, y + h - 9)]:
            d.rectangle((rx, ry, rx + 2, ry + 2), fill=rim[1])
            d.point((rx, ry), fill=rim[0])
            d.point((rx + 2, ry + 2), fill=rim[3])
        d.line([(x + 6, y + 9), (x + 9, y + 6)], fill=rim[2])
        d.line([(x + w - 10, y + h - 7), (x + w - 7, y + h - 10)], fill=rim[2])
    # energy cells: glass capsule, empty (dark) and full (glowing cyan charge)
    for key, fill in (("energy_cell_empty", None), ("energy_cell_full", CYAN)):
        x, y, w, h = HUD_BOXES[key][1]
        d.rounded_rectangle((x, y, x + w - 1, y + h - 1), radius=4, fill=HUD_INK)
        d.rounded_rectangle((x + 1, y + 1, x + w - 2, y + h - 2), radius=3, fill=STEEL[2])
        d.rectangle((x + 3, y + 1, x + w - 4, y + 2), fill=STEEL[0])
        d.rectangle((x + 2, y + 4, x + w - 3, y + h - 5), fill=HUD_INK)
        if fill:
            d.rectangle((x + 3, y + 5, x + w - 4, y + h - 6), fill=fill[2])
            d.rectangle((x + 3, y + 5, x + 6, y + h - 6), fill=fill[1])
            d.rectangle((x + 4, y + 6, x + 4, y + 12), fill=fill[0])
            d.rectangle((x + w - 5, y + 5, x + w - 4, y + h - 6), fill=fill[3])
        else:
            d.rectangle((x + 3, y + 5, x + w - 4, y + h - 6), fill=BODY[2])
            d.rectangle((x + 3, y + 5, x + 4, y + h - 6), fill=BODY[0])
        d.rectangle((x + 3, y + h - 4, x + w - 4, y + h - 3), fill=STEEL[3])
    im.resize((aw * HUD_SCALE, ah * HUD_SCALE), Image.NEAREST).save(OUT / "hud_kit.png")


def podium():
    """Studio podium guide (208x72 art px at 8x): grass-topped stone drum on a light background.
    Textured on purpose (blade strokes, uneven stones, moss): img2img keeps flat areas flat."""
    aw, ah = 208, 72
    rng = np.random.default_rng(7)
    im = Image.new("RGB", (aw, ah), (236, 236, 240))
    d = ImageDraw.Draw(im)
    cx, top, rx, ry = 104, 18, 98, 14
    stone = [(206, 200, 218), (160, 152, 180), (118, 108, 142), (80, 70, 104), (56, 48, 78)]
    base_y = top + 36
    # drum silhouette + bottom shadow
    d.rectangle((cx - rx + 3, top, cx + rx - 3, base_y), fill=HUD_INK)
    d.ellipse((cx - rx + 3, base_y - ry, cx + rx - 3, base_y + ry), fill=HUD_INK)
    d.rectangle((cx - rx + 4, top, cx + rx - 4, base_y), fill=stone[2])
    d.ellipse((cx - rx + 4, base_y - ry - 1, cx + rx - 4, base_y + ry - 1), fill=stone[3])
    # stone courses: blocks of uneven width, lit top edge, shaded right edge, light on the left side
    rows = [(top + 8, top + 18), (top + 18, top + 28), (top + 28, base_y + 6)]
    for ri, (y0, y1) in enumerate(rows):
        x = cx - rx + 4 - int(rng.integers(0, 14))
        while x < cx + rx - 4:
            bw = int(rng.integers(14, 26))
            x0, x1 = max(x, cx - rx + 4), min(x + bw, cx + rx - 4)
            side = (x0 + x1) / 2 - cx
            k = 1 if side < -40 else 2 if side < 50 else 3
            k = min(4, k + ri // 2) if ri == 2 else k
            col = stone[k]
            jitter = int(rng.integers(-8, 9))
            col = tuple(max(0, min(255, c + jitter)) for c in col)
            d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=col)
            d.line([(x0, y0), (x1 - 2, y0)], fill=stone[max(0, k - 1)])
            d.line([(x1 - 1, y0), (x1 - 1, y1 - 1)], fill=stone[min(4, k + 1)])
            if rng.random() < 0.3:
                cxk = int(rng.integers(x0 + 2, max(x0 + 3, x1 - 2)))
                d.line([(cxk, y0 + 2), (cxk + 2, y0 + 5)], fill=stone[min(4, k + 1)])
            x += bw
        d.line([(cx - rx + 4, y1 - 1), (cx + rx - 4, y1 - 1)], fill=stone[4])
    # clip the lowest course to the drum's curved bottom
    a = np.asarray(im).copy()
    yy, xx = np.mgrid[0:ah, 0:aw]
    outside = (yy > base_y) & (((xx - cx) / (rx - 3)) ** 2 + ((yy - base_y) / ry) ** 2 > 1)
    a[outside] = (236, 236, 240)
    im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    d.arc((cx - rx + 3, base_y - ry, cx + rx - 3, base_y + ry), 0, 180, fill=HUD_INK)
    # grass cap: ink rim, dark side band, top with blade texture and a lit back half
    d.ellipse((cx - rx - 1, top - ry - 1, cx + rx + 1, top + ry + 6), fill=HUD_INK)
    d.ellipse((cx - rx, top - ry, cx + rx, top + ry + 5), fill=(38, 120, 56))
    d.ellipse((cx - rx, top - ry, cx + rx, top + ry), fill=(58, 172, 84))
    d.ellipse((cx - rx + 10, top - ry + 2, cx + rx - 14, top + ry - 6), fill=(88, 196, 84))
    d.ellipse((cx - rx + 34, top - ry + 3, cx + rx - 50, top + 2), fill=(132, 214, 92))
    a = np.asarray(im).copy()
    for _ in range(520):
        x = int(rng.integers(cx - rx + 3, cx + rx - 3))
        y = int(rng.integers(top - ry + 1, top + ry))
        if ((x - cx) / rx) ** 2 + ((y - top) / ry) ** 2 < 0.9:
            c = a[y, x].astype(int)
            k = rng.choice([-1, 1])
            c2 = np.clip(c + k * np.array([22, 26, 14]), 0, 255)
            a[y, x] = c2
            if y + 1 < ah:
                a[y + 1, x] = c2
    im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    # flowers
    for _ in range(9):
        x = int(rng.integers(cx - rx + 14, cx + rx - 14))
        y = int(rng.integers(top - ry + 4, top + ry - 3))
        if ((x - cx) / rx) ** 2 + ((y - top) / ry) ** 2 < 0.7:
            col = [(255, 250, 230), (255, 214, 64), (255, 140, 180)][int(rng.integers(0, 3))]
            d.point([(x, y), (x - 1, y), (x + 1, y), (x, y - 1)], fill=col)
            d.point((x, y), fill=(255, 214, 64))
    # overhanging grass fringe and hanging moss
    for x in range(cx - rx + 2, cx + rx - 1, 2):
        yb = top + int((ry + 4) * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2))) + 1
        ln = int(rng.integers(1, 5)) + (3 if rng.random() < 0.12 else 0)
        d.line([(x, yb), (x, yb + ln)], fill=(38, 120, 56) if ln < 4 else (30, 96, 52))
        d.point((x, yb + ln + 1), fill=HUD_INK)
    im.resize((aw * 8, ah * 8), Image.NEAREST).save(OUT / "podium.png")


ALL.update({"hud_panel": hud_panel, "hud_kit": hud_kit, "podium": podium})

if __name__ == "__main__":
    import sys
    for k in (sys.argv[1:] or ALL):
        ALL[k]()
        print("guide", k)
