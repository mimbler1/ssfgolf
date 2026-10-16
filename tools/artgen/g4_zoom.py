"""Zoom chosen frames: python g4_zoom.py <id> <anim> out.png k idx..."""
import json, sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
cid, anim, out, k = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
ids = [int(a) for a in sys.argv[5:]]
d = ROOT / "client/assets/characters" / cid
meta = json.loads((d / "character.json").read_text())
s = Image.open(d / meta["anims"][anim]["sheet"]).convert("RGBA")
W, H = meta["frame_size"]
bg = Image.new("RGBA", (W * len(ids), H), (110, 160, 112, 255))
for i, j in enumerate(ids):
    bg.alpha_composite(s.crop((j * W, 0, j * W + W, H)), (i * W, 0))
box = bg.getbbox()
bg.crop((0, 8, bg.width, H)).resize((bg.width * k, (H - 8) * k), Image.NEAREST).save(out)
