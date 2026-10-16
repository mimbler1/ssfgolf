"""Contact sheet of files: python g4_sheet.py out.png w file1 file2 ... (thumb width w)"""
import sys
from PIL import Image, ImageDraw
out, w, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
ims = []
for f in files:
    im = Image.open(f).convert("RGB")
    h = round(im.height * w / im.width)
    ims.append((f.replace("\\", "/").split("/")[-1], im.resize((w, h), Image.NEAREST if im.width < w else Image.LANCZOS)))
cols = min(len(ims), max(1, 2000 // w))
H = max(i.height for _, i in ims) + 14
sheet = Image.new("RGB", (cols * w, ((len(ims) + cols - 1) // cols) * H), (30, 30, 36))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(ims):
    x, y = (i % cols) * w, (i // cols) * H
    sheet.paste(im, (x, y + 14)); d.text((x + 3, y + 1), n, fill=(255, 255, 255))
sheet.save(out); print(sheet.size)
