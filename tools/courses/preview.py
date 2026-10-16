"""Renders course review maps from a course_report JSON (client/tests/course_report.gd).

  python tools/courses/preview.py <report.json> <out_dir>

Each hole becomes <out_dir>/<hole id>.png: terrain by edge material, hazard zones, gravity
fields, tee, cup and the solver bot's shot paths (numbered). For design review only.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

MAT = {"grass": (92, 190, 70), "rough": (60, 130, 50), "sand": (236, 206, 130), "snow": (240, 246, 255),
       "ice": (150, 220, 255), "rock": (140, 140, 150), "wood": (170, 110, 60), "sticky": (180, 80, 230),
       "bouncy": (255, 70, 110), "cup": (30, 30, 30), "conveyor_r": (255, 170, 40), "conveyor_l": (255, 120, 40)}
ZONE = {"water": (60, 140, 230, 150), "lava": (255, 90, 30, 160), "acid": (120, 230, 60, 160)}


def render(h, out):
    bx, by, bw, bh = h["bounds"]
    margin = 200
    k = min(1600 / (bw + margin * 2), 900 / (bh + margin * 2))

    def T(p):
        return ((p[0] - bx + margin) * k, (p[1] - by + margin) * k)

    W = int((bw + margin * 2) * k)
    H = int((bh + margin * 2) * k)
    im = Image.new("RGBA", (W, H), (205, 230, 250, 255))
    d = ImageDraw.Draw(im, "RGBA")
    d.rectangle([T((bx, by)), T((bx + bw, by + bh))], outline=(120, 120, 160), width=1)
    for f in h["fields"]:
        col = (170, 120, 255, 70) if not f["has_vector"] else (255, 120, 220, 80)
        d.polygon([T(p) for p in f["points"]], fill=col, outline=(120, 60, 200))
        cx = sum(p[0] for p in f["points"]) / len(f["points"])
        cy = sum(p[1] for p in f["points"]) / len(f["points"])
        label = "g x%.2f" % f["scale"] if not f["has_vector"] else "g (%d,%d)" % tuple(f["vector"])
        d.text(T((cx, cy)), label, fill=(80, 20, 140))
    for z in h["zones"]:
        d.polygon([T(p) for p in z["points"]], fill=ZONE.get(z["type"], (255, 0, 255, 120)))
    for poly in h["polygons"]:
        pts = [T(p) for p in poly["points"]]
        d.polygon(pts, fill=(120, 85, 60, 255))
        n = len(pts)
        for i in range(n):
            d.line([pts[i], pts[(i + 1) % n]], fill=MAT.get(poly["mats"][i], (255, 0, 255)), width=3)
    cols = [(255, 255, 255), (255, 220, 60), (255, 120, 60), (60, 220, 255), (200, 120, 255), (120, 255, 120)]
    for si, s in enumerate(h["shots"]):
        c = cols[si % len(cols)]
        pts = [T(p) for p in s["path"] if not isinstance(p[0], str)]
        if len(pts) > 1:
            d.line(pts, fill=c + (230,), width=2)
        fx, fy = T(s["from"])
        d.ellipse([fx - 4, fy - 4, fx + 4, fy + 4], fill=c)
        d.text((fx + 5, fy - 14), str(si + 1), fill=(0, 0, 0))
        for p in s["path"]:
            if isinstance(p[0], str):
                x, y = T(p[1:])
                d.line([x - 6, y - 6, x + 6, y + 6], fill=(255, 0, 0), width=3)
                d.line([x - 6, y + 6, x + 6, y - 6], fill=(255, 0, 0), width=3)
    tx, ty = T(h["tee"])
    d.rectangle([tx - 5, ty - 5, tx + 5, ty + 5], fill=(255, 255, 255), outline=(0, 0, 0))
    cx, cy = T(h["cup"])
    d.line([cx, cy, cx, cy - 40], fill=(0, 0, 0), width=2)
    d.polygon([(cx, cy - 40), (cx + 22, cy - 33), (cx, cy - 26)], fill=(255, 40, 40))
    status = "holed in %d" % h["strokes"] if h["holed"] else "NOT HOLED"
    d.text((8, 8), "%s  %s  par %s  solver: %s" % (h["id"], h["name"], h["par"], status), fill=(0, 0, 0))
    im.save(os.path.join(out, h["id"] + ".png"))


def main():
    rep = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for h in rep["holes"]:
        render(h, out)
        print("%s %-22s par %s  %s" % (h["id"], h["name"], h["par"], ("holed in %d" % h["strokes"]) if h["holed"] else "NOT HOLED"))


if __name__ == "__main__":
    main()
