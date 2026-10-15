"""Contact sheet of every candidate for some jobs: python tools/artgen/contact.py out.png job1 job2 ..."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
OUT = Path(__file__).resolve().parent / "out"
tiles = []
for job in sys.argv[2:]:
    for f in sorted((OUT / job).glob("*.png")):
        im = Image.open(f).convert("RGB")
        im.thumbnail((384, 384), Image.NEAREST)
        tiles.append((f"{job}/{f.stem}", im))
cols = 4
w = max(t[1].width for t in tiles); h = max(t[1].height for t in tiles) + 16
sheet = Image.new("RGB", (cols * w, ((len(tiles) + cols - 1) // cols) * h), (30, 30, 36))
d = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(tiles):
    x, y = (i % cols) * w, (i // cols) * h
    sheet.paste(im, (x, y + 16)); d.text((x + 4, y + 2), name, fill=(255, 255, 255))
sheet.save(sys.argv[1]); print(sheet.size)
