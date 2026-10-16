"""Shared authoring helpers for the built-in courses (docs/COURSES.md, docs/COURSE_MANIFEST.md).

Coordinates are pixels with y pointing down (negative = up). The ground surface of a hole is
usually around y = 0. A ball has radius 9; a full-power 45 degree shot carries about 1500 px and a
full-power shot straight up rises about 680 px: no single shot can clear anything taller.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "client", "data", "courses")


def P(x, y, **kw):
    """A control point. m=<material> sets the edge starting here; c=True makes a hard corner."""
    return [x, y, kw] if kw else [x, y]


def ground(points, material="grass", bottom=700, smooth=True, kind="ground"):
    """A ground polygon: the surface `points` left->right, closed down to `bottom`.

    The first and last points should be tall boundary walls (use left_wall/right_wall)."""
    # Boundary-wall run-in points (flag "w") must never step backwards past the fairway, or the
    # outline folds over itself; drop any that would.
    out = []
    max_x = -1e9
    for pt in points:
        flags = pt[2] if len(pt) > 2 else {}
        if flags.get("w") and pt[0] <= max_x + 40:
            continue
        if flags.get("w"):
            flags = {k: v for k, v in flags.items() if k != "w"}
            pt = [pt[0], pt[1], flags] if flags else [pt[0], pt[1]]
        out.append(pt)
        max_x = max(max_x, pt[0])
    x0 = out[0][0]
    x1 = out[-1][0]
    return {"material": material, "smooth": smooth, "kind": kind,
            "points": out + [P(x1, bottom, c=True), P(x0, bottom, c=True)]}


def left_wall(x=-200, top=-800, ground_y=0, foot=260):
    """Curved boundary wall rising on the left, landing on ground_y at x + foot."""
    return [P(x, top, c=True), P(x + 110, top + 60), P(x + 210, ground_y - 330), P(x + 300, ground_y - 50), P(x + foot + 160, ground_y)]


def right_wall(x, top=-800, ground_y=0):
    """Curved boundary wall rising on the right, ending at x."""
    return [P(x - 420, ground_y, w=True), P(x - 270, ground_y - 50, w=True), P(x - 150, ground_y - 300), P(x, top, c=True)]


def block(x0, y0, x1, y1, material="rock", kind="island", top=None, smooth=False):
    """A rectangular solid (platform, wall, pillar). `top` overrides the top edge material."""
    t = top or material
    return {"material": material, "smooth": smooth, "kind": kind, "points": [
        P(x0, y0, c=True, m=t), P(x1, y0, c=True), P(x1, y1, c=True), P(x0, y1, c=True)]}


def poly(points, material="rock", kind="island", smooth=False):
    return {"material": material, "smooth": smooth, "kind": kind, "points": points}


def zone(kind, x0, y0, x1, y1):
    return {"type": kind, "points": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}


def water(x0, y0, x1, y1):
    return zone("water", x0, y0, x1, y1)


def lava(x0, y0, x1, y1):
    return zone("lava", x0, y0, x1, y1)


def gravity(x0, y0, x1, y1, scale=None, vector=None):
    f = {"type": "gravity", "points": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}
    if vector is not None:
        f["vector"] = list(vector)
    else:
        f["scale"] = scale
    return f


def deco(kind, x, y, scale=1.0):
    return {"type": kind, "x": x, "y": y, "scale": scale}


def hole(hid, name, par, bounds, tee, cup, terrain, zones=None, fields=None, decor=None, notes=""):
    x, y, w, h = bounds
    d = {"id": hid, "name": name, "par": par,
         "bounds": {"x": x, "y": y, "w": w, "h": h},
         "tee": {"x": tee[0], "y": tee[1]}, "cup": {"x": cup[0], "y": cup[1]},
         "terrain": terrain, "zones": zones or [], "decor": decor or []}
    if fields:
        d["fields"] = fields
    if notes:
        d["notes"] = notes
    return d


def write_course(cid, name, theme, holes, order, difficulty, mechanic, extra=None):
    assert len(holes) == 9, "%s has %d holes" % (cid, len(holes))
    data = {"id": cid, "name": name, "version": 3, "order": order, "difficulty": difficulty,
            "mechanic": mechanic, "theme": theme, "holes": holes}
    if extra:
        data.update(extra)
    path = os.path.join(OUT, cid + ".json")
    with open(path, "w", encoding="utf-8") as f:
        f.write(dumps(data) + "\n")
    print("wrote", path, "par", sum(h["par"] for h in holes))
    return path


def dumps(obj, indent=0):
    """JSON with one point/short list per line, so hole files stay readable and diff well."""
    pad = "  " * indent
    if isinstance(obj, dict):
        if not obj:
            return "{}"
        if all(not isinstance(v, (dict, list)) for v in obj.values()) and len(obj) <= 5:
            return json.dumps(obj)
        items = [pad + "  " + json.dumps(k) + ": " + dumps(v, indent + 1) for k, v in obj.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(obj, list):
        if not obj:
            return "[]"
        flat = all(not isinstance(v, (dict, list)) for v in obj)
        is_point = len(obj) == 3 and isinstance(obj[2], dict) and all(isinstance(v, (int, float)) for v in obj[:2])
        if flat or is_point:
            return json.dumps(obj)
        items = [pad + "  " + dumps(v, indent + 1) for v in obj]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(obj)


def pond(x0, x1, rim_y, floor_y, bed="sand", slope=70):
    """Surface points for a water basin between rims at x0 and x1, plus its water zone.

    Returns (points, zone). The water line sits 14 px below the rims so a ball resting on a
    rim is never inside the hazard."""
    pts = [P(x0, rim_y), P(x0 + slope * 0.5, rim_y + (floor_y - rim_y) * 0.5), P(x0 + slope, floor_y, m=bed),
           P(x1 - slope, floor_y), P(x1 - slope * 0.5, rim_y + (floor_y - rim_y) * 0.5), P(x1, rim_y)]
    return pts, water(x0 + 4, rim_y + 14, x1 - 4, floor_y + 40)
