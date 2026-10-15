"""Authoring script for the built-in courses (until the in-game course editor exists).\n\nWrites client/data/courses/sunny_meadows.json and physics_lab.json in the course data format\ndocumented in docs/COURSES.md. Run from the repo root:  python tools/build_courses.py\n"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "client", "data", "courses")


def P(x, y, **kw):
    return [x, y, kw] if kw else [x, y]


LEFT = [P(-200, -700, c=True), P(-80, -640), P(20, -300), P(120, -40), P(260, 0)]


def close(xr, bottom=600):
    return [P(xr, bottom, c=True), P(-200, bottom, c=True)]


def water(x0, y0, x1, y1):
    return {"type": "water", "points": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}


MEADOW_THEME = {
    "id": "meadow",
    "art": "meadow",  # authored world art (client/assets/worlds/meadow); procedural fallback otherwise
    "sky_top": "#3fa9f5", "sky_bottom": "#c9f0ff", "sun": "#fff3c4",
    "far_hills": "#9fd8b4", "mid_hills": "#73c27f",
    "ground_top": "#8a5a3c", "ground_bottom": "#5b3a29", "ground_strata": "#7a4e34",
    "grass": "#6ccf4a", "grass_light": "#9be36b", "grass_dark": "#3d9a2f",
    "outline": "#2a3a2a", "water_top": "#4fc3f7", "water_bottom": "#1e6fb8", "cloud": "#ffffff",
}

HOLES = [
    {
        "id": "sm_01", "name": "Opening Drive",
        "bounds": {"x": -200, "y": -1500, "w": 3050, "h": 2100},
        "tee": {"x": 350, "y": 0}, "cup": {"x": 2360, "y": -40},
        "terrain": [{"material": "grass", "smooth": True, "points": [
            P(-200, -760, c=True), P(-90, -700), P(20, -320), P(120, -60), P(260, 0), P(450, 0), P(700, -30), P(950, -130),
            P(1150, -95), P(1300, 10), P(1380, 46, m="sand"), P(1460, 60, m="sand"), P(1540, 46), P(1700, -18), P(1900, -62),
            P(2100, -52), P(2250, -40), P(2470, -40), P(2620, -90), P(2740, -320), P(2850, -760, c=True)] + close(2850)}],
        "zones": [],
        "decor": [{"type": "tree", "x": 560, "y": -10, "scale": 1.1}, {"type": "bush", "x": 820, "y": -60, "scale": 1.0},
                  {"type": "flowers", "x": 1050, "y": -115, "scale": 1.0}, {"type": "tree", "x": 1780, "y": -36, "scale": 0.9},
                  {"type": "bush", "x": 2560, "y": -60, "scale": 1.2}, {"type": "flowers", "x": 2150, "y": -50, "scale": 0.9}],
    },
    {
        "id": "sm_02", "name": "Pond Hop",
        "bounds": {"x": -200, "y": -1400, "w": 2900, "h": 2000},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 1975, "y": -60},
        "terrain": [{"material": "grass", "smooth": True, "points": LEFT + [
            P(520, 0), P(640, 30), P(700, 110), P(820, 165, m="sand"), P(1000, 176, m="sand"), P(1180, 165), P(1300, 110),
            P(1360, 30), P(1450, -20), P(1650, -50), P(1850, -60), P(2100, -60), P(2300, -80), P(2450, -200), P(2560, -500),
            P(2700, -760, c=True)] + close(2700)}],
        "zones": [water(630, 40, 1370, 230)],
        "decor": [{"type": "tree", "x": 470, "y": 0, "scale": 1.0}, {"type": "flowers", "x": 1560, "y": -40, "scale": 1.0},
                  {"type": "bush", "x": 2250, "y": -70, "scale": 1.1}, {"type": "rock", "x": 1420, "y": -10, "scale": 0.9}],
    },
    {
        "id": "sm_03", "name": "Bounce House",
        "bounds": {"x": -200, "y": -1500, "w": 3000, "h": 2100},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 1975, "y": -60},
        "terrain": [{"material": "grass", "smooth": True, "points": LEFT + [
            P(560, 0), P(690, -4), P(700, -5, m="bouncy", c=True), P(900, -5, c=True), P(1040, -10, c=True, m="rock"),
            P(1080, -420, c=True), P(1200, -470), P(1330, -430, c=True, m="rock"), P(1370, -60, c=True), P(1500, -45),
            P(1800, -60), P(2100, -60), P(2300, -55), P(2500, -120), P(2650, -400), P(2800, -760, c=True)] + close(2800)}],
        "zones": [],
        "decor": [{"type": "bush", "x": 520, "y": 0, "scale": 1.0}, {"type": "tree", "x": 1200, "y": -470, "scale": 0.9},
                  {"type": "flowers", "x": 1650, "y": -50, "scale": 1.0}, {"type": "tree", "x": 2380, "y": -70, "scale": 1.0}],
    },
    {
        "id": "sm_04", "name": "Sticky Cliffs",
        "bounds": {"x": -200, "y": -1700, "w": 2700, "h": 2300},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 1900, "y": -640},
        "terrain": [{"material": "grass", "smooth": True, "points": LEFT + [
            P(600, 0), P(780, -20), P(860, -60, c=True, m="rock"), P(880, -300, c=True), P(1040, -312, c=True, m="sticky"),
            P(1062, -620, c=True), P(1300, -648), P(1600, -632), P(1800, -640), P(2000, -640), P(2200, -660), P(2350, -720),
            P(2500, -950, c=True)] + close(2500)}],
        "zones": [],
        "decor": [{"type": "flowers", "x": 520, "y": 0, "scale": 1.0}, {"type": "bush", "x": 960, "y": -310, "scale": 0.8},
                  {"type": "tree", "x": 1450, "y": -640, "scale": 1.1}, {"type": "flowers", "x": 2100, "y": -650, "scale": 1.0}],
    },
    {
        "id": "sm_05", "name": "Long Valley",
        "bounds": {"x": -200, "y": -1400, "w": 4400, "h": 2000},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 3700, "y": -40},
        "terrain": [{"material": "grass", "smooth": True, "points": LEFT + [
            P(460, 0), P(700, 40), P(1000, 90), P(1200, 60), P(1300, 70, m="sand"), P(1420, 86, m="sand"), P(1520, 70),
            P(1700, 10), P(2000, -60), P(2200, -40), P(2400, 40), P(2500, 90), P(2600, 170, m="sand"), P(2800, 182, m="sand"),
            P(2950, 140), P(3020, 70), P(3150, 10), P(3400, -30), P(3600, -40), P(3800, -40), P(3950, -80), P(4100, -300),
            P(4200, -700, c=True)] + close(4200)}],
        "zones": [water(2470, 100, 3045, 240)],
        "decor": [{"type": "tree", "x": 800, "y": 50, "scale": 1.2}, {"type": "flowers", "x": 1100, "y": 80, "scale": 1.0},
                  {"type": "tree", "x": 2050, "y": -55, "scale": 1.0}, {"type": "bush", "x": 2300, "y": -10, "scale": 1.0},
                  {"type": "rock", "x": 3100, "y": 30, "scale": 1.0}, {"type": "flowers", "x": 3450, "y": -35, "scale": 1.0}],
    },
    {
        "id": "sm_06", "name": "Island Green",
        "bounds": {"x": -200, "y": -1600, "w": 3550, "h": 2300},
        "tee": {"x": 340, "y": -200}, "cup": {"x": 1700, "y": -95},
        "terrain": [
            {"material": "grass", "smooth": True, "points": [
                P(-200, -900, c=True), P(-80, -850), P(20, -500), P(60, -260), P(140, -200), P(500, -200), P(640, -180),
                P(760, -100), P(820, 60), P(860, 300, c=True), P(900, 420), P(2500, 420), P(2560, 300), P(2620, 40),
                P(2700, -60), P(2900, -80), P(3100, -120), P(3250, -400), P(3350, -800, c=True),
                P(3350, 700, c=True), P(-200, 700, c=True)]},
            {"material": "grass", "smooth": True, "kind": "island", "points": [
                P(1480, -60), P(1560, -92), P(1700, -96), P(1840, -92), P(1920, -60), P(1880, 10), P(1780, 62),
                P(1700, 74), P(1620, 62), P(1520, 10)]}],
        "zones": [water(830, 140, 2600, 440)],
        "decor": [{"type": "tree", "x": 420, "y": -200, "scale": 1.0}, {"type": "flowers", "x": 1590, "y": -90, "scale": 0.7},
                  {"type": "bush", "x": 2850, "y": -80, "scale": 1.0}, {"type": "tree", "x": 3000, "y": -100, "scale": 1.1}],
    },
    {
        "id": "sm_07", "name": "Tunnel Vision",
        "bounds": {"x": -200, "y": -1500, "w": 3250, "h": 2100},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 2500, "y": -30},
        "terrain": [
            {"material": "grass", "smooth": True, "points": LEFT + [
                P(600, 10), P(900, 0), P(1200, 0), P(1500, 0), P(1800, 0), P(2100, -10), P(2400, -30), P(2600, -30),
                P(2800, -60), P(2950, -300), P(3050, -700, c=True)] + close(3050)},
            {"material": "grass", "smooth": True, "kind": "arch", "points": [
                P(900, 16, c=True), P(960, -200), P(1100, -480), P(1350, -620), P(1600, -480), P(1740, -200),
                P(1800, 16, c=True), P(1700, 16, c=True, m="rock"), P(1660, -110, m="rock"), P(1500, -132, m="rock"),
                P(1200, -132, m="rock"), P(1040, -110, m="rock"), P(1000, 16, c=True)]}],
        "zones": [],
        "decor": [{"type": "bush", "x": 620, "y": 10, "scale": 1.0}, {"type": "tree", "x": 1350, "y": -620, "scale": 1.0},
                  {"type": "flowers", "x": 2050, "y": -10, "scale": 1.0}, {"type": "tree", "x": 2250, "y": -20, "scale": 0.9}],
    },
    {
        "id": "sm_08", "name": "Downhill Dash",
        "bounds": {"x": -200, "y": -2000, "w": 3350, "h": 2600},
        "tee": {"x": 360, "y": -700}, "cup": {"x": 2600, "y": -20},
        "terrain": [{"material": "grass", "smooth": True, "points": [
            P(-200, -1300, c=True), P(-80, -1240), P(20, -900), P(120, -720), P(260, -700), P(480, -700), P(650, -660),
            P(900, -520), P(1200, -360, m="rough"), P(1400, -280), P(1600, -200), P(1800, -120), P(2000, -60),
            P(2150, -30, m="sand"), P(2250, -25, m="sand"), P(2330, -30), P(2500, -20), P(2700, -20), P(2900, -40),
            P(3050, -200), P(3150, -600, c=True)] + close(3150)}],
        "zones": [],
        "decor": [{"type": "tree", "x": 560, "y": -690, "scale": 1.1}, {"type": "bush", "x": 1000, "y": -470, "scale": 1.0},
                  {"type": "flowers", "x": 1700, "y": -150, "scale": 1.0}, {"type": "tree", "x": 2850, "y": -35, "scale": 1.0},
                  {"type": "rock", "x": 1500, "y": -240, "scale": 1.1}],
    },
    {
        "id": "sm_09", "name": "Grand Finale",
        "bounds": {"x": -200, "y": -1500, "w": 3100, "h": 2100},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 2425, "y": -340},
        "terrain": [{"material": "grass", "smooth": True, "points": LEFT + [
            P(540, 0), P(660, 40), P(720, 120), P(840, 170, m="sand"), P(1060, 180, m="sand"), P(1200, 160), P(1260, 100),
            P(1300, 20), P(1360, 2), P(1380, 0, m="bouncy", c=True), P(1520, 0, c=True), P(1600, -20), P(1700, -110),
            P(1760, -130, c=True, m="rock"), P(1790, -310, c=True), P(1950, -330), P(2050, -325, m="sand"),
            P(2120, -300, m="sand"), P(2200, -325), P(2300, -340), P(2550, -340), P(2700, -360), P(2820, -500),
            P(2900, -800, c=True)] + close(2900)}],
        "zones": [water(650, 50, 1310, 240)],
        "decor": [{"type": "tree", "x": 470, "y": 0, "scale": 1.0}, {"type": "flowers", "x": 1580, "y": -15, "scale": 0.8},
                  {"type": "bush", "x": 1880, "y": -320, "scale": 0.9}, {"type": "tree", "x": 2650, "y": -350, "scale": 1.0}],
    },
]

LAB = {
    "id": "physics_lab", "name": "Physics Lab", "version": 1, "practiceOnly": True, "theme": MEADOW_THEME,
    "holes": [{
        "id": "lab_01", "name": "Material Testbed",
        "bounds": {"x": -200, "y": -1600, "w": 5400, "h": 2200},
        "tee": {"x": 360, "y": 0}, "cup": {"x": 4600, "y": -40},
        "terrain": [{"material": "grass", "smooth": False, "points": [
            P(-200, -900), P(-100, -900), P(-100, 0), P(800, 0, m="sand"), P(1200, 0, m="ice"), P(1800, 0, m="bouncy"),
            P(2100, 0, m="rough"), P(2500, 0, m="wood"), P(2900, 0, m="rock"), P(3300, 0), P(3400, -260, m="sticky"),
            P(3420, -560), P(3800, -560), P(3900, -300), P(4000, -40), P(5100, -40), P(5100, -1000), P(5200, -1000),
            P(5200, 600), P(-200, 600)]}],
        "zones": [water(4100, -60, 4300, -40)],
        "decor": [],
    }],
}


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


def main():
    os.makedirs(OUT, exist_ok=True)
    meadows = {"id": "sunny_meadows", "name": "Sunny Meadows", "version": 2, "theme": MEADOW_THEME, "holes": HOLES}
    with open(os.path.join(OUT, "sunny_meadows.json"), "w", encoding="utf-8") as f:
        f.write(dumps(meadows) + "\n")
    with open(os.path.join(OUT, "physics_lab.json"), "w", encoding="utf-8") as f:
        f.write(dumps(LAB) + "\n")
    print("wrote", len(HOLES), "Sunny Meadows holes + physics lab")


if __name__ == "__main__":
    main()
