"""Course 2: Beach Land - coastal terrain (docs/COURSE_MANIFEST.md).

Original layouts built around the course's theme: sand traps that plug the ball, water carries,
beaches, cliffs, changes of elevation, longer shots and careful landings. Fairways are dune grass
("grass"); sand is the trap material.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, water, pond, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "beach", "art": "beach",
    "sky_top": "#3da7f0", "sky_bottom": "#ffe8c4", "sun": "#fff2b0",
    "far_hills": "#7fd0e6", "mid_hills": "#f0d39a",
    "ground_top": "#d9a066", "ground_bottom": "#9c5f36", "ground_strata": "#c4874f",
    "grass": "#a6d65a", "grass_light": "#d4ef8a", "grass_dark": "#6fa83a",
    "outline": "#3a2a20", "water_top": "#3fd0e0", "water_bottom": "#1878b8", "cloud": "#ffffff",
}


def h1():
    p, z = pond(2480, 2980, -20, 150)
    return hole("bl_01", "Shoreline", 3, (-200, -1500, 3500, 2200), (360, 0), (2160, -20),
        [ground(left_wall() + [P(520, 0), P(800, -20), P(1100, -14), P(1320, 8), P(1400, 40, m="sand"),
            P(1560, 52, m="sand"), P(1700, 40), P(1780, 6), P(1900, -16), P(2100, -20), P(2300, -20)] + p +
            [P(3060, -30)] + right_wall(3300, -900, -40))],
        zones=[z],
        decor=[deco("palm", 600, -10), deco("shell", 1250, 0), deco("umbrella", 1950, -20), deco("palm", 3150, -40)],
        notes="A straightforward drive. The pot bunker plugs anything that lands short; the sea waits behind the green.")


def h2():
    p1, z1 = pond(700, 1000, 0, 120)
    p2, z2 = pond(1350, 1650, -10, 120)
    p3, z3 = pond(2000, 2300, -20, 130)
    return hole("bl_02", "Tide Pools", 4, (-200, -1500, 3600, 2200), (360, 0), (2720, -30),
        [ground(left_wall() + [P(520, 0)] + p1 + [P(1120, -10), P(1240, -10)] + p2 + [P(1760, -20), P(1880, -20)] + p3 +
            [P(2450, -30), P(2900, -30)] + right_wall(3400, -900, -40))],
        zones=[z1, z2, z3],
        decor=[deco("shell", 1180, -10), deco("rock", 1820, -20), deco("palm", 2600, -30), deco("crab", 2850, -30)],
        notes="Three tide pools with short dry banks between them: carry them one at a time or fly them all.")


def h3():
    return hole("bl_03", "Lighthouse Cliff", 4, (-200, -1900, 3300, 2600), (360, 0), (2160, -700),
        [ground(left_wall() + [P(560, 0), P(900, 10), P(1180, 0), P(1300, -20, c=True, m="rock"), P(1330, -330, c=True, m="sand"),
            P(1470, -340, c=True, m="rock"), P(1500, -690, c=True), P(1640, -700), P(1900, -700), P(2400, -700), P(2560, -720)] +
            right_wall(3100, -1300, -740))],
        decor=[deco("lighthouse", 2600, -730, 1.2), deco("palm", 700, 0), deco("rock", 1100, 0), deco("grass_tuft", 1800, -700)],
        notes="The green is on top of the cliff. A sandy ledge halfway up catches short shots (and plugs them).")


def h4():
    return hole("bl_04", "Dune Run", 5, (-200, -1500, 4700, 2200), (360, 0), (3980, 10),
        [ground(left_wall() + [P(520, 0), P(760, -90), P(980, -130), P(1160, -60), P(1300, 30, m="sand"), P(1460, 50, m="sand"),
            P(1600, 20), P(1800, -110), P(2050, -170), P(2300, -80), P(2450, 20, m="sand"), P(2640, 40, m="sand"), P(2780, 10),
            P(3000, -90), P(3250, -120), P(3480, -40), P(3700, 10), P(3900, 10), P(4100, 10)] + right_wall(4500, -900, 0))],
        decor=[deco("grass_tuft", 900, -130), deco("palm", 2050, -170), deco("shell", 2700, 30), deco("grass_tuft", 3250, -120),
               deco("umbrella", 3800, 10)],
        notes="Long rolling dunes. Sand fills every trough, so each shot has to land on a crest or roll over one.")


def h5():
    return hole("bl_05", "Pier Pressure", 4, (-200, -1500, 3600, 2200), (360, 0), (2700, -40),
        [ground(left_wall() + [P(520, 0), P(780, 0), P(860, 40, c=True), P(900, 220, c=True, m="sand"), P(2380, 220, c=True),
            P(2420, 40, c=True), P(2480, -30), P(2600, -40), P(2900, -40)] + right_wall(3400, -900, -50)),
         block(1150, -40, 1750, -14, "wood"), block(1300, -14, 1330, 220, "wood"), block(1600, -14, 1630, 220, "wood")],
        zones=[water(864, 60, 2416, 260)],
        decor=[deco("palm", 640, 0), deco("buoy", 2000, 60), deco("umbrella", 2800, -40)],
        notes="Carry the bay, or play safe: lay up on the wooden pier halfway and chip on.")


def h6():
    return hole("bl_06", "Hidden Cove", 4, (-200, -1600, 3400, 2300), (360, 0), (2180, 0),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1200, -10), P(1500, -4), P(1800, 0), P(2100, 0), P(2400, 0), P(2560, -40)] +
            right_wall(3200, -1000, -60)),
         poly([P(1500, -200, c=True, m="rock"), P(2500, -200), P(2900, -260), P(3300, -300, c=True), P(3300, -1100, c=True),
               P(1700, -1100, c=True), P(1560, -760), P(1420, -420), P(1440, -260)], "rock", smooth=True)],
        decor=[deco("rock", 1000, -10), deco("shell", 1700, -4), deco("crab", 2350, 0)],
        notes="The cup hides under a rock overhang. Keep it low and run it in, or bank it off the ceiling.")


def h7():
    p, z = pond(1300, 2500, 10, 160)
    return hole("bl_07", "High Tide", 4, (-200, -2000, 3500, 2700), (360, -600), (2860, 0),
        [ground([P(-200, -1300, c=True), P(-90, -1240), P(20, -900), P(120, -640), P(260, -600), P(560, -600), P(700, -560),
            P(860, -380, m="rock"), P(1000, -160), P(1150, -20), P(1240, 0)] + p + [P(2620, 0), P(2800, 0), P(3000, 0)] +
            right_wall(3300, -1000, -10))],
        zones=[z],
        decor=[deco("palm", 450, -600), deco("lighthouse", 160, -620, 0.8), deco("buoy", 1900, 30), deco("palm", 2950, 0)],
        notes="Hit down off the bluff over a wide channel. The extra height carries further than it looks.")


def h8():
    return hole("bl_08", "Sandcastle", 3, (-200, -1600, 3000, 2300), (360, 0), (1720, 0),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1200, 0), P(1500, 0), P(1700, 0), P(1900, 0), P(2200, 0), P(2400, -20)] +
            right_wall(2800, -900, -40)),
         block(1460, -230, 1520, 0, "sand"), block(1440, -270, 1540, -230, "sand"),
         block(1920, -230, 1980, 0, "sand"), block(1900, -270, 2000, -230, "sand")],
        decor=[deco("flag_small", 1490, -270), deco("flag_small", 1950, -270), deco("shell", 1100, 0), deco("umbrella", 2300, -20)],
        notes="The cup sits in the courtyard of a sandcastle. Lob it in high; anything that hits the walls plugs.")


def h9():
    p, z = pond(760, 1500, 0, 150)
    return hole("bl_09", "Coastal Classic", 5, (-200, -1900, 4500, 2600), (360, 0), (3800, -420),
        [ground(left_wall() + [P(520, 0)] + p + [P(1640, -20), P(1900, -40), P(2100, -40, c=True, m="rock"), P(2140, -400, c=True),
            P(2300, -410), P(2600, -420), P(2780, -410, m="sand"), P(2980, -400, m="sand"), P(3120, -410), P(3400, -420),
            P(3800, -420), P(4000, -430)] + right_wall(4300, -1200, -440))],
        zones=[z],
        decor=[deco("palm", 600, 0), deco("buoy", 1100, 30), deco("rock", 1900, -40), deco("palm", 2450, -415),
               deco("lighthouse", 4100, -440, 1.0)],
        notes="Everything at once: a water carry, a cliff, a bunker across the top and a long final approach.")


def build():
    return write_course("beach_land", "Beach Land", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 2,
                        "Easy", "Sand that plugs, water carries, cliffs and long shots")


if __name__ == "__main__":
    build()
