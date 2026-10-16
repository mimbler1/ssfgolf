"""Review sheet for a built character: python tools/artgen/g4_review.py <id> out.png [k]
Rows: swing, idle, victory (if any) on a grass-green backdrop, k x magnified."""
import json, sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
cid, out = sys.argv[1], sys.argv[2]
k = int(sys.argv[3]) if len(sys.argv) > 3 else 3
d = ROOT / "client/assets/characters" / cid
meta = json.loads((d / "character.json").read_text())
W, H = meta["frame_size"]
rows = [a for a in ("swing", "idle", "victory") if a in meta["anims"]]
n = max(len(meta["anims"][a]["frames"]) for a in rows)
sheet = Image.new("RGBA", (W * n, H * len(rows)), (110, 160, 112, 255))
for r, a in enumerate(rows):
    strip = Image.open(d / meta["anims"][a]["sheet"]).convert("RGBA")
    for i, f in enumerate(meta["anims"][a]["frames"]):
        x, y, w, h = f["rect"]
        sheet.alpha_composite(strip.crop((x, y, x + w, y + h)), (i * W, r * H))
sheet.resize((sheet.width * k, sheet.height * k), Image.NEAREST).save(out)
print(out, sheet.size)
