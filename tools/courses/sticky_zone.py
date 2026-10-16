"""Course 3: Sticky Zone - sticky surfaces (docs/COURSE_MANIFEST.md).

Original layouts. Sticky goo (material "sticky") catches ANY ball on contact, regardless of the
ball type, and the next shot is taken from wherever it stuck: walls, slopes and ceilings. Holes
teach landing on goo on purpose, using it as a stepping stone, and keeping clear of goo traps.
Rock and grass faces are normal. The Sticky Ball ability is separate and sticks to anything.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, water, pond, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "sticky", "art": "sticky",
    "sky_top": "#3b2a6b", "sky_bottom": "#c56bd6", "sun": "#ffe6ff",
    "far_hills": "#6a3fa0", "mid_hills": "#4f8a4a",
    "ground_top": "#5a4a3a", "ground_bottom": "#2e2430", "ground_strata": "#4a3a34",
    "grass": "#7bd34a", "grass_light": "#b5f07a", "grass_dark": "#3f8f2f",
    "outline": "#1e1428", "water_top": "#b06cff", "water_bottom": "#5a2a9a", "cloud": "#f3d9ff",
}
GOO = "sticky"


def h1():
    return hole("sz_01", "First Stick", 3, (-200, -1800, 3200, 2500), (360, 0), (2200, 0),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1100, 0, c=True, m=GOO), P(1110, -520, c=True), P(1260, -520, c=True, m="rock"),
            P(1270, 0, c=True), P(1500, 0), P(1900, 0), P(2300, 0), P(2500, -10)] + right_wall(2900, -1000, -30))],
        decor=[deco("mushroom", 700, 0), deco("vine", 1110, -300), deco("mushroom", 1700, 0), deco("crystal", 2450, -10)],
        notes="A goo wall. Stick to its face, then pop the ball up and over from there; or clear it in one big shot.")


def h2():
    return hole("sz_02", "Ceiling Crawl", 4, (-200, -1800, 3600, 2500), (360, 0), (2820, -40),
        [ground(left_wall() + [P(520, 0), P(760, 0), P(820, 20, c=True), P(840, 260, c=True, m="rock"), P(2260, 260, c=True),
            P(2280, 20, c=True), P(2360, -30), P(2600, -40), P(3000, -40)] + right_wall(3400, -1000, -50)),
         poly([P(900, -420, c=True, m=GOO), P(2200, -420, c=True), P(2200, -560, c=True, m="rock"), P(900, -560, c=True)], "rock")],
        zones=[{"type": "acid", "points": [[844, 140], [2256, 140], [2256, 300], [844, 300]]}],
        decor=[deco("vine", 1200, -420), deco("vine", 1800, -420), deco("mushroom", 600, 0), deco("crystal", 2700, -40)],
        notes="A pit of bubbling goo with a sticky ceiling above it. Stick to the ceiling, then drop the ball forward to the green.")


def h3():
    return hole("sz_03", "Glue Gully", 4, (-200, -1500, 3900, 2200), (360, 0), (3200, -30),
        [ground(left_wall() + [P(520, 0), P(800, -20), P(1000, -10, m=GOO), P(1300, -10), P(1450, -60, m="rock"), P(1550, -90),
            P(1650, -60), P(1800, -10, m=GOO), P(2150, -10), P(2300, -50, m="rock"), P(2420, -80), P(2540, -50),
            P(2700, -20, m=GOO), P(2900, -20), P(3050, -30), P(3300, -30)] + right_wall(3700, -900, -40))],
        decor=[deco("mushroom", 1550, -90), deco("vine", 1150, -10), deco("mushroom", 2420, -80), deco("crystal", 3400, -30)],
        notes="Goo strips cover the low ground; rocky humps between them are safe. Land on a hump or past the goo.")


def h4():
    return hole("sz_04", "Wall Climb", 4, (-200, -2300, 3200, 3000), (360, 0), (2300, -1000),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1000, 0), P(1500, 0), P(1700, 0, c=True, m=GOO), P(1710, -980, c=True, m="rock"),
            P(1760, -1000, c=True), P(2100, -1000), P(2500, -1000), P(2600, -1020)] + right_wall(3000, -1600, -1040)),
         block(1050, -460, 1130, -330, GOO), block(1350, -760, 1430, -620, GOO)],
        decor=[deco("vine", 1090, -460), deco("vine", 1390, -760), deco("mushroom", 2000, -1000), deco("crystal", 2450, -1000)],
        notes="The green is a thousand pixels up. Climb it: goo blocks and a goo cliff face are the handholds.")


def h5():
    return hole("sz_05", "Goo Islands", 4, (-200, -1700, 3800, 2400), (360, 0), (3020, -30),
        [ground(left_wall() + [P(520, 0), P(700, 0), P(760, 30, c=True), P(780, 300, c=True, m="rock"), P(2620, 300, c=True),
            P(2640, 30, c=True), P(2700, -20), P(2900, -30), P(3200, -30)] + right_wall(3600, -1000, -40)),
         block(1050, -120, 1200, -60, GOO, top=GOO), block(1550, -260, 1700, -200, GOO), block(2100, -140, 2250, -80, GOO)],
        zones=[{"type": "acid", "points": [[784, 160], [2616, 160], [2616, 320], [784, 320]]}],
        decor=[deco("mushroom", 600, 0), deco("crystal", 2800, -20), deco("vine", 1625, -260)],
        notes="Three floating goo islands over a goo pit. Hop from island to island, sticking each time.")


def h6():
    return hole("sz_06", "Sticky Trap", 4, (-200, -1600, 3400, 2300), (360, 0), (2400, -20),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1700, -20), P(1950, -20, m=GOO), P(2250, -20), P(2300, -20, m="rock"),
            P(2340, -40), P(2380, -20), P(2420, -20), P(2460, -40, m="rock"), P(2500, -20, m=GOO), P(2800, -20), P(2900, -30)] +
            right_wall(3200, -900, -40))],
        decor=[deco("mushroom", 1000, -10), deco("vine", 2100, -20), deco("vine", 2650, -20), deco("crystal", 1500, -20)],
        notes="A tiny green ringed by goo. Anything slightly long or short sticks and leaves an awkward chip.")


def h7():
    return hole("sz_07", "The Chimney", 5, (-200, -2400, 2800, 3100), (360, 0), (1760, -1220),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1000, 0), P(1200, 0), P(1300, 0, c=True, m=GOO), P(1310, -900, c=True)] +
            [P(1560, -900, c=True), P(1570, -1200, c=True), P(1640, -1220), P(1900, -1220), P(2000, -1240)] + right_wall(2400, -1700, -1260)),
         poly([P(960, -420, c=True, m="rock"), P(1060, -420, c=True, m=GOO), P(1060, 80, c=True, m="rock"), P(960, 80, c=True, m="rock")], "rock")],
        decor=[deco("vine", 1305, -500), deco("crystal", 1900, -1220), deco("mushroom", 700, 0)],
        notes="A narrow shaft between two goo faces. Bounce-stick your way up it, then pop over the lip to the ledge green.")


def h8():
    p, z = pond(900, 2300, 0, 180, bed="rock")
    return hole("sz_08", "Under the Bridge", 4, (-200, -1600, 3600, 2300), (360, 0), (2900, -20),
        [ground(left_wall() + [P(520, 0), P(800, 0)] + p + [P(2500, -10), P(2800, -20), P(3100, -20)] + right_wall(3400, -900, -30)),
         poly([P(1100, -300, c=True, m="wood"), P(2100, -300, c=True), P(2100, -260, c=True, m=GOO), P(1100, -260, c=True)], "wood")],
        zones=[z],
        decor=[deco("vine", 1300, -260), deco("vine", 1900, -260), deco("mushroom", 2700, -20)],
        notes="The bridge deck is ordinary wood on top but goo underneath. A low line sticks under it; a high one rides over.")


def h9():
    return hole("sz_09", "Goo Gauntlet", 5, (-200, -2000, 4400, 2700), (360, 0), (3740, -600),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1000, 0, m=GOO), P(1300, 0), P(1400, 0, c=True, m="rock"), P(1420, -300, c=True),
            P(1500, -310), P(1800, -310, m=GOO), P(2000, -310), P(2100, -310, c=True, m=GOO), P(2110, -600, c=True),
            P(2300, -600), P(2700, -600), P(3000, -620, m="rock"), P(3100, -650), P(3200, -620), P(3500, -600), P(3900, -600),
            P(4000, -620)] + right_wall(4200, -1300, -640)),
         poly([P(2500, -900, c=True, m=GOO), P(3300, -900, c=True), P(3300, -1000, c=True, m="rock"), P(2500, -1000, c=True)], "rock")],
        decor=[deco("mushroom", 700, 0), deco("vine", 1150, 0), deco("crystal", 1650, -310), deco("vine", 2105, -450),
               deco("mushroom", 3700, -600)],
        notes="Goo on the floor, on the risers and on the ceiling. Use the risers to climb; avoid the floor strips.")


def build():
    return write_course("sticky_zone", "Sticky Zone", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 3,
                        "Medium", "Goo walls, ceilings and islands: shoot from wherever you stick")


if __name__ == "__main__":
    build()
