"""Preview portraits: python g4_pview.py out.png id..."""
import sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
out, ids = sys.argv[1], sys.argv[2:]
sheet = Image.new("RGBA", (len(ids) * 330, 330), (20, 20, 30, 255))
for i, c in enumerate(ids):
    p = ROOT / f"art/characters/{c}/v4/portrait.png"
    im = Image.open(p).convert("RGBA")
    bg = Image.new("RGBA", im.size, (40, 44, 70, 255)); bg.alpha_composite(im)
    sheet.paste(bg.resize((256, 256), Image.NEAREST), (i * 330, 0))
    sheet.paste(bg, (i * 330 + 260, 0))
sheet.save(out)
