"""Magnified crop of one frame for pixel review.

usage: python tools/sprites/zoom.py <character dir> <frame> <x0> <y0> <x1> <y1> <scale> <out.png>
"""
import sys
from pathlib import Path

from PIL import Image

import spritekit as sk

d, frame = Path(sys.argv[1]), sys.argv[2]
x0, y0, x1, y1, k = (int(v) for v in sys.argv[3:8])
pal = sk.Palette.load(d / "palette.txt")
img = sk.render(sk.read_grid(d / "src" / f"{frame}.txt"), pal).crop((x0, y0, x1, y1))
bg = Image.new("RGBA", img.size, (64, 68, 84, 255))
bg.alpha_composite(img)
bg.resize((img.width * k, img.height * k), Image.NEAREST).save(sys.argv[8])
