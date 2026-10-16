"""Course 3: Sticky Zone - sticky surfaces (docs/COURSE_MANIFEST.md, docs/COURSE_REFERENCE.md).

Rebuilt in Super Stickman Golf 3's structure (tour 1, course 3; nine holes). SSG3's Sticky Zone
pars and geometry are not available, so the pars here are design pars and every layout is
original. Sticky goo (material "sticky") catches ANY ball on contact and the next shot is taken
from wherever it stuck: walls, ledges and ceilings. Verified detail kept as a design constraint:
hole 7 can be completed without touching goo (tests/no_touch_check.gd proves the route).

Every solid piece is attached to the ground: ceilings are overhangs that grow out of a cliff or
the boundary wall, and handholds are ledges on a wall (no floating slabs or islands).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, zone, cliff, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "sticky", "art": "sticky",
    "sky_top": "#3b2a6b", "sky_bottom": "#c56bd6", "sun": "#ffe6ff",
    "far_hills": "#6a3fa0", "mid_hills": "#4f8a4a",
    "ground_top": "#5a4a3a", "ground_bottom": "#2e2430", "ground_strata": "#4a3a34",
    "grass": "#7bd34a", "grass_light": "#b5f07a", "grass_dark": "#3f8f2f",
    "outline": "#1e1428", "water_top": "#b06cff", "water_bottom": "#5a2a9a", "cloud": "#f3d9ff",
}
GOO = "sticky"
R = "rock"


def acid(x0, y0, x1, y1):
    return zone("acid", x0, y0, x1, y1)


def h1():
    return hole("sz_01", "First Stick", 4, (-200, -1800, 4200, 2500), (360, 0), (2900, -2),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1250, -10), P(1450, -10, c=True, m=GOO), P(1460, -440, c=True), P(1700, -450), P(1900, -430), P(2100, -330),
            P(2250, -150), P(2350, -30), P(2450, -5), P(2650, -12), P(2900, -2), P(3100, -14), P(3400, -34)] +
            right_wall(4000, -1100, -50))],
        decor=[deco("mushroom", 700, 0), deco("crystal", 1650, -450), deco("mushroom", 2550, -8), deco("crystal", 3500, -12)],
        notes="A rock mesa with a goo face. Land on top and roll down the back to the green; anything short sticks to the face and pops up from there.")


def h2():
    return hole("sz_02", "Goo Ledges", 4, (-200, -2000, 4400, 2700), (360, 0), (2900, -640),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1000, 0), P(1060, 0, c=True, m=R), P(1100, -200, c=True, m=GOO),
            P(1450, -200, c=True, m=R), P(1490, -420, c=True, m=GOO), P(1850, -420, c=True, m=R), P(1890, -640, c=True),
            P(2200, -640), P(2600, -640), P(3600, -640)] + right_wall(4200, -1400, -650))],
        decor=[deco("mushroom", 700, 0), deco("crystal", 1280, -200), deco("crystal", 1670, -420), deco("mushroom", 2300, -640),
               deco("mushroom", 3400, -640)],
        notes="Climb two goo-topped ledges to the green. Goo stops the ball dead where it lands, so every landing is a new tee.")


def h3():
    return hole("sz_03", "Ceiling Crawl", 5, (-200, -2100, 4400, 2800), (360, 0), (2700, -20),
        [ground(left_wall() + [P(520, 0), P(820, 0), P(860, 20, c=True, m=R), P(880, 260, c=True, m=R), P(2080, 260, c=True),
            P(2100, 20, c=True), P(2180, -20), P(2700, -20), P(3200, -20), P(3300, -20, c=True, m=R), P(3300, -340, c=True, m=GOO),
            P(950, -340, c=True, m=R), P(950, -1150, c=True), P(2200, -1170), P(3300, -1190), P(4200, -1200, c=True)])],
        zones=[acid(884, 140, 2076, 280)],
        decor=[deco("mushroom", 650, 0), deco("vine", 1400, -330), deco("vine", 2300, -330), deco("crystal", 3150, -20),
               deco("mushroom", 2400, -1170)],
        notes="An acid pit lies under a goo-lined overhang that reaches out from the far cliff. Stick to the ceiling well out over the pit, then drop forward onto the cove green.")


def h4():
    return hole("sz_04", "Wall Climb", 5, (-200, -2400, 3800, 3100), (360, 0), (2600, -1000),
        [ground(left_wall(top=-1300) + [P(520, 0), P(900, 0), P(1250, 0), P(1300, 0, c=True, m=GOO), P(1300, -330, c=True),
            P(1420, -332), P(1520, -330), P(1540, -330, c=True, m=GOO), P(1540, -660, c=True), P(1660, -662), P(1760, -660),
            P(1780, -660, c=True, m=GOO), P(1780, -1000, c=True), P(1950, -1005), P(2300, -1000), P(2900, -1000), P(3200, -1020)] +
            right_wall(3600, -1800, -1040))],
        decor=[deco("mushroom", 800, 0), deco("crystal", 1430, -332), deco("mushroom", 1660, -662), deco("crystal", 2100, -1000),
               deco("mushroom", 2900, -1000)],
        notes="The green is a thousand pixels up a staircase of goo cliffs. Stick to a face, pop up onto the step above, and climb.")


def h5():
    return hole("sz_05", "Glue Gully", 4, (-200, -1500, 4800, 2200), (360, 0), (3800, -30),
        [ground(left_wall() + [P(520, 0), P(800, -20), P(950, -10, m=GOO), P(1250, -10), P(1400, -70, m=R), P(1520, -110),
            P(1640, -70), P(1800, -10, m=GOO), P(2150, -10), P(2300, -80, m=R), P(2440, -120), P(2580, -80),
            P(2750, -10, m=GOO), P(3100, -10), P(3250, -30), P(3600, -30), P(4100, -30)] + right_wall(4600, -900, -40))],
        decor=[deco("mushroom", 650, -15), deco("crystal", 1520, -110), deco("mushroom", 2440, -120), deco("crystal", 3400, -30),
               deco("mushroom", 4000, -30)],
        notes="Goo fills every trough; the rocky humps between them are safe. Land on a hump or carry the goo entirely.")


def h6():
    underside = [P(2600, -430, c=True, m=GOO), P(1900, -430, c=True, m=GOO), P(1850, -320, c=True, m=GOO), P(1800, -430, c=True, m=GOO),
                 P(1200, -430, c=True, m=GOO), P(1150, -320, c=True, m=GOO), P(1100, -430, c=True, m=GOO), P(60, -430, c=True)]
    return hole("sz_06", "Low Ceiling", 5, (-200, -1900, 5600, 2600), (360, 0), (4700, -300),
        [ground([P(-200, -1200, c=True), P(2600, -1200, c=True, m=R)] + underside +
            [P(140, -150), P(260, 0), P(520, 0), P(900, 0, m=GOO), P(1150, 0), P(1500, -10), P(1900, -10), P(2300, -10),
             P(2700, -20), P(3000, -60), P(3300, -160), P(3600, -260), P(3900, -300), P(4200, -300, m=GOO), P(4400, -300),
             P(4700, -300), P(5000, -310)] + right_wall(5400, -1300, -320))],
        decor=[deco("mushroom", 600, 0), deco("vine", 700, -420), deco("vine", 1500, -420), deco("vine", 2300, -420),
               deco("crystal", 3500, -230), deco("mushroom", 4900, -305)],
        notes="A long corridor under a goo-studded roof. Keep every shot low (anything that rises sticks to the ceiling), then climb out to the green.")


def h7():
    # Zigzag chimney: cliff ledge -> pillar top -> higher cliff ledge -> green; no ledge overhangs
    # another. Goo only on the pillar's outer (tee-side) face: the shortcut.
    return hole("sz_07", "The Chimney", 5, (-200, -2200, 3400, 2900), (360, 0), (2300, -900),
        [ground(left_wall(top=-1200) + [P(520, 0), P(800, 0), P(1060, 0), P(1100, 0, c=True, m=GOO), P(1100, -420, c=True, m=R),
            P(1180, -420, c=True, m=R), P(1180, 0, c=True), P(1300, 0), P(1440, 0),
            P(1500, 0, c=True, m=R), P(1500, -230, c=True, m=R), P(1370, -230, c=True, m=R), P(1370, -265, c=True), P(1500, -265, c=True, m=R),
            P(1500, -660, c=True, m=R), P(1370, -660, c=True, m=R), P(1370, -695, c=True), P(1500, -695, c=True, m=R),
            P(1500, -900, c=True), P(1700, -905), P(2100, -900), P(2500, -900), P(2800, -920)] +
            right_wall(3200, -1700, -940))],
        decor=[deco("mushroom", 700, 0), deco("crystal", 1140, -420), deco("mushroom", 1950, -900), deco("crystal", 2650, -905)],
        notes="A zigzag chimney: the pillar's goo face is the shortcut; without touching goo, climb from cliff ledge to pillar top to the higher ledge and over the lip.")


def h8():
    return hole("sz_08", "Sticky Trap", 4, (-200, -1700, 4400, 2400), (360, 0), (3100, -20),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1500, -20, c=True, m=GOO), P(1540, -260, c=True, m=R),
            P(1700, -270), P(1860, -260, c=True, m=R), P(1900, -20, c=True), P(2300, -20), P(2700, -20, m=GOO),
            P(2980, -20, m=R), P(3020, -35), P(3060, -20), P(3140, -20, m=R), P(3180, -35), P(3220, -20, m=GOO),
            P(3500, -20), P(3800, -30)] + right_wall(4200, -900, -40))],
        decor=[deco("mushroom", 700, -5), deco("crystal", 1700, -270), deco("mushroom", 2400, -20), deco("crystal", 3650, -25)],
        notes="Hop the goo-faced ridge, then find a tiny green ringed by goo. Anything long or short sticks and leaves an awkward chip.")


def h9():
    return hole("sz_09", "Goo Gauntlet", 5, (-200, -2100, 5000, 2800), (360, 0), (4200, -600),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1000, 0, m=GOO), P(1300, 0), P(1400, 0, c=True, m=GOO), P(1420, -300, c=True),
            P(1500, -310), P(1800, -310, m=GOO), P(2000, -310), P(2100, -310, c=True, m=GOO), P(2110, -600, c=True),
            P(2400, -600), P(2700, -600, m=GOO), P(2900, -600), P(3100, -600), P(3300, -620, m=R), P(3400, -650), P(3500, -620),
            P(3700, -600), P(4000, -600), P(4300, -600), P(4500, -600, c=True, m=R), P(4500, -880, c=True, m=GOO),
            P(3700, -880, c=True, m=R), P(3700, -960, c=True), P(4200, -980), P(4800, -1000, c=True)])],
        decor=[deco("mushroom", 650, 0), deco("crystal", 1650, -310), deco("mushroom", 2500, -600), deco("vine", 3900, -870),
               deco("vine", 4350, -870), deco("crystal", 3400, -650)],
        notes="Goo on the floor, on the risers and on the ceiling over the green. Use the risers to climb, avoid the floor strips, and keep the approach under the overhang.")


def build():
    return write_course("sticky_zone", "Sticky Zone", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 3,
                        "Medium", "Goo walls, ledges and ceilings: shoot from wherever you stick",
                        {"parSource": "design", "layout": 2}, strict=True)


if __name__ == "__main__":
    build()
