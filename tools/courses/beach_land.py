"""Course 2: Beach Land - coastal terrain (docs/COURSE_MANIFEST.md, docs/COURSE_REFERENCE.md).

Rebuilt to Super Stickman Golf 3's verified Beach Land structure: nine holes with the original
pars 5-5-5-5-4-4-4-4-5 (total 41). SSG3's hole geometry is not available, so every layout is
original, built around the course's identity: sand traps that plug the ball, sea inlets and
lagoons, palm-lined dunes, rock cliffs and a pier. Verified detail kept as a design constraint:
hole 4 (par 5) can be holed in one with the plain ball.

Every solid piece is attached to the ground (no floating platforms); fairways are dune grass.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, water, pond, bunker, cliff, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "beach", "art": "beach",
    "sky_top": "#3da7f0", "sky_bottom": "#ffe8c4", "sun": "#fff2b0",
    "far_hills": "#7fd0e6", "mid_hills": "#f0d39a",
    "ground_top": "#d9a066", "ground_bottom": "#9c5f36", "ground_strata": "#c4874f",
    "grass": "#a6d65a", "grass_light": "#d4ef8a", "grass_dark": "#6fa83a",
    "outline": "#3a2a20", "water_top": "#3fd0e0", "water_bottom": "#1878b8", "cloud": "#ffffff",
}


def h1():
    inlet, z = pond(1950, 2450, -10, 140)
    return hole("bl_01", "Sandbar", 5, (-200, -1900, 5600, 2600), (360, 0), (4650, -468),
        [ground(left_wall() + [P(520, 0), P(900, -20), P(1250, -10)] + bunker(1400, 1680, -8, 45) +
            [P(1820, -10)] + inlet + [P(2550, -20), P(2700, -28)] + cliff(2780, -28, -450) +
            [P(2950, -462), P(3350, -470)] + bunker(3550, 3850, -470, 45) +
            [P(4100, -475), P(4450, -480), P(4650, -468), P(4850, -482), P(5050, -505)] + right_wall(5400, -1400, -530))],
        zones=[z],
        decor=[deco("palm", 640, -10), deco("shell", 1150, -12), deco("umbrella", 1850, -10), deco("crab", 2600, -22),
               deco("palm", 3050, -465), deco("grass_tuft", 3300, -470), deco("palm", 4250, -478), deco("lighthouse", 5150, -515, 1.1)],
        notes="Drive along the beach past the bunker and the sea inlet, pop the ball up onto the sea cliff, then work across the bunkered top to a green that gathers the ball toward the cup.")


def h2():
    pool, z = pond(2650, 3150, 0, 140)
    return hole("bl_02", "Palm Point", 5, (-200, -2100, 6000, 2800), (380, -420), (5050, -300),
        [ground([P(-200, -1200, c=True), P(-90, -1140), P(20, -800), P(120, -470), P(260, -420), P(560, -420), P(700, -400)] +
            cliff(800, -390, -40, 90) + [P(1050, -10), P(1400, 0), P(1700, 10)] + bunker(1900, 2150, 10, 42) +
            [P(2400, 0)] + pool + [P(3350, -10), P(3650, -50), P(3900, -150), P(4150, -250), P(4350, -280)] +
            bunker(4450, 4650, -280, 40) + [P(4800, -295), P(5200, -300)] + right_wall(5800, -1300, -310))],
        zones=[z],
        decor=[deco("palm", 520, -420), deco("lighthouse", 120, -440, 0.8), deco("shell", 1300, 0), deco("palm", 2300, 0),
               deco("crab", 3450, -15), deco("grass_tuft", 4000, -180), deco("palm", 4250, -270), deco("umbrella", 5300, -300)],
        notes="Tee off the headland onto the long beach, carry the tide pool, then climb the dunes to a raised green guarded by a pot bunker.")


def h3():
    return hole("bl_03", "Lagoon Pier", 5, (-200, -1800, 5400, 2500), (360, 0), (4500, -150),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1100, -10), P(1180, 30, c=True), P(1220, 220, c=True, m="sand"),
            P(3360, 220, c=True), P(3400, 30, c=True), P(3480, -20), P(3800, -60), P(4100, -120), P(4300, -150),
            P(4700, -150)] + right_wall(5200, -1100, -160)),
         block(1650, -40, 2550, -14, "wood"), block(1700, -14, 1730, 220, "wood"), block(2470, -14, 2500, 220, "wood")],
        zones=[water(1184, 40, 3396, 260)],
        decor=[deco("palm", 600, 0), deco("umbrella", 950, -10), deco("buoy", 1400, 60), deco("buoy", 2950, 60),
               deco("palm", 3700, -50), deco("shell", 4000, -110), deco("palm", 4800, -150)],
        notes="The lagoon is wider than any shot carries: lay up on the wooden pier, then play across to the far shore and up the dune to the green.")


def h4():
    steps = [P(780, 100, m="sand"), P(1150, 105, m="sand"), P(1250, 100)]
    return hole("bl_04", "Cliffhanger", 5, (-200, -2100, 4400, 2800), (360, -700), (2290, -500),
        [ground([P(-200, -1500, c=True), P(-90, -1440), P(20, -1100), P(120, -760), P(260, -700), P(560, -700)] +
            cliff(650, -700, 100, 60) + steps + [P(1450, 110), P(1650, 100)] +
            cliff(1700, 100, -150) + [P(1800, -155)] + cliff(1850, -155, -500, 30) +
            [P(1960, -505), P(2150, -500), P(2420, -500)] + cliff(2440, -500, -900, 10, "rock") +
            [P(2600, -930), P(3000, -960), P(4200, -980, c=True)])],
        decor=[deco("palm", 500, -700), deco("lighthouse", 140, -720, 0.9), deco("crab", 1350, 105), deco("palm", 1550, 100),
               deco("grass_tuft", 2050, -503), deco("palm", 2800, -945)],
        notes="A high tee over a deep valley to a short plateau green with a rock backstop. Carry the lip perfectly and it can drop for an ace; come up short and it is the long way round: out of the valley sand and up the rock steps.")


def h5():
    return hole("bl_05", "Sea Arch", 4, (-200, -1800, 4800, 2500), (360, 0), (3950, -20),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1500, -20), P(1800, -20), P(2100, -20),
            P(2300, -10)] + bunker(2500, 2700, -10, 40) + [P(2900, -15), P(3300, -20), P(3700, -20), P(4200, -25)] +
            right_wall(4600, -1000, -30)),
         poly([P(1350, -10, c=True, m="rock"), P(1420, -260), P(1560, -480), P(1800, -560), P(2040, -480), P(2180, -260),
               P(2250, -10, c=True), P(2120, -10, c=True), P(2060, -180), P(1950, -300), P(1800, -330), P(1650, -300),
               P(1540, -180), P(1480, -10, c=True)], "rock", kind="arch", smooth=True)],
        decor=[deco("palm", 700, -10), deco("shell", 1150, -18), deco("grass_tuft", 1800, -560), deco("crab", 2800, -15),
               deco("palm", 3400, -20), deco("umbrella", 4100, -25)],
        notes="A natural sea arch spans the fairway. Thread a low shot through it, or loft one over the top; the bunker beyond catches long run-outs.")


def h6():
    return hole("bl_06", "Hidden Cove", 4, (-200, -1900, 4600, 2600), (360, 0), (3500, 0),
        [ground(left_wall() + [P(520, 0), P(900, -20), P(1300, -40), P(1600, -30)] + bunker(1750, 1950, -25, 40) +
            [P(2100, -20), P(2500, -10), P(2900, 0), P(3300, 0), P(3700, 0), P(3820, 0, c=True, m="rock"),
             P(3820, -230, c=True, m="rock"), P(2700, -230, c=True, m="rock"), P(2660, -300, c=True), P(3100, -360), P(3700, -420),
             P(4400, -460, c=True)])],
        decor=[deco("palm", 650, -10), deco("shell", 1200, -35), deco("palm", 2200, -18), deco("crab", 3100, 0),
               deco("grass_tuft", 3200, -365), deco("palm", 3900, -430)],
        notes="The cup hides in a cove under a rock overhang. Keep the approach low and run it in, or bank it off the cove's back wall.")


def h7():
    return hole("bl_07", "Tide Steps", 4, (-200, -2100, 4600, 2800), (360, 0), (3300, -620),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(1050, 0)] + cliff(1150, 0, -200) +
            [P(1260, -202), P(1360, -202, m="sand"), P(1480, -200, m="sand"), P(1560, -202), P(1650, -202)] +
            cliff(1720, -202, -410) + [P(1830, -412), P(1930, -412, m="sand"), P(2050, -410, m="sand"), P(2130, -412),
            P(2220, -412)] + cliff(2290, -412, -620) + [P(2400, -622), P(2900, -620), P(3800, -620)] +
            right_wall(4400, -1500, -640))],
        decor=[deco("palm", 700, 0), deco("crab", 950, 0), deco("palm", 1600, -202), deco("shell", 2180, -412),
               deco("palm", 2700, -620), deco("lighthouse", 4000, -640, 1.0)],
        notes="Three rock terraces up from the beach. Each step has a sand pocket that plugs the ball; land on the grass behind it or skip a step.")


def h8():
    moat, z = pond(1750, 2050, -20, 110)
    return hole("bl_08", "Sandcastle", 4, (-200, -1900, 4400, 2600), (360, 0), (3050, -240),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1600, -20)] + moat +
            [P(2300, -40), P(2500, -120), P(2700, -220), P(2800, -240), P(3400, -240), P(3550, -230), P(3800, -200)] +
            right_wall(4200, -1000, -200)),
         block(2720, -400, 2780, -238, "sand"), block(2700, -430, 2800, -400, "sand"),
         block(3380, -400, 3440, -238, "sand"), block(3360, -430, 3460, -400, "sand")],
        zones=[z],
        decor=[deco("palm", 700, -10), deco("umbrella", 1200, -18), deco("buoy", 1900, 0), deco("flag_small", 2750, -430),
               deco("flag_small", 3410, -430), deco("shell", 3600, -225), deco("palm", 3900, -205)],
        notes="Carry the moat, climb the dune and drop the ball into the castle courtyard. The sand towers plug anything that hits them.")


def h9():
    lagoon, z = pond(900, 1800, 0, 150)
    return hole("bl_09", "Coastal Classic", 5, (-200, -2000, 6600, 2700), (360, 0), (5600, -80),
        [ground(left_wall() + [P(520, 0), P(700, 0)] + lagoon + [P(1950, -10), P(2250, -30)] + cliff(2350, -30, -480) +
            [P(2470, -485), P(2800, -490)] + bunker(3000, 3250, -490, 42) + [P(3450, -492), P(3700, -495)] +
            bunker(3850, 4050, -495, 40) + [P(4250, -490), P(4500, -420), P(4800, -250), P(5100, -110), P(5350, -80),
            P(5800, -80)] + right_wall(6400, -1200, -90))],
        zones=[z],
        decor=[deco("palm", 600, 0), deco("buoy", 1350, 30), deco("palm", 2100, -20), deco("palm", 2650, -488),
               deco("grass_tuft", 3550, -494), deco("palm", 4350, -470), deco("crab", 5200, -95), deco("lighthouse", 6000, -90, 1.1)],
        notes="The full tour: carry the lagoon, climb the sea cliff, thread the two cliff-top bunkers, then run down the slope to the lighthouse green.")


def build():
    return write_course("beach_land", "Beach Land", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 2,
                        "Easy", "Sand that plugs, water carries, cliffs and long shots",
                        {"parSource": "ssg3", "layout": 2}, strict=True)


if __name__ == "__main__":
    build()
