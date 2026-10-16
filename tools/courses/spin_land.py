"""Course 6: Spin Land - spin and ball control (docs/COURSE_MANIFEST.md, PHYSICS_SPEC.md section 4).

Rebuilt in Super Stickman Golf 3's structure (tour 2, course 6; nine holes). SSG3's Spin Land
pars and geometry are not available, so the pars here are design pars and every layout is
original, set in a breezy windmill-and-carnival world. Holes reward real spin: perched and
narrow greens (backspin stops the ball), rolling runs (topspin carries further), rebounds off
walls, a green that runs toward water, belts that drag the ball, pillars and a half-pipe.
Verified detail kept as a design constraint: the course can be finished under par without spin
(the solver bot never uses spin and is well under par).

Every solid piece is attached to the ground: ledges grow out of cliffs, pillars stand on the
basin floor (no floating platforms, no balloons).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, zone, pond, bunker, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "spin", "art": "spin",
    "sky_top": "#ff9d6c", "sky_bottom": "#ffe3b8", "sun": "#fff6d8",
    "far_hills": "#e7a3c0", "mid_hills": "#9fd18a",
    "ground_top": "#b07a52", "ground_bottom": "#6e4430", "ground_strata": "#946446",
    "grass": "#8fdc5a", "grass_light": "#c2f28a", "grass_dark": "#57a83a",
    "outline": "#3a2230", "water_top": "#6fd2ff", "water_bottom": "#2a78c0", "cloud": "#fff4ea",
}
BR = "conveyor_r"
BL = "conveyor_l"
R = "rock"


def h1():
    return hole("sl_01", "Check It", 4, (-200, -1700, 4400, 2400), (360, 0), (2100, -300),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1200, -30), P(1400, -60, m="rough"), P(1600, -140),
            P(1720, -230, c=True, m=R), P(1760, -300, c=True), P(1950, -304), P(2100, -300), P(2250, -304),
            P(2300, -300, c=True, m=R), P(2360, -220, c=True, m="rough"), P(2500, -120), P(2700, -40, m="sand"), P(2950, -30),
            P(3200, -20), P(3700, -30)] + right_wall(4200, -1000, -40))],
        decor=[deco("windmill", 700, -10, 1.2), deco("pinwheel", 1900, -304), deco("bush", 2800, -35), deco("gear", 3400, -22)],
        notes="A perched green on a mesa with run-off slopes on both sides. Land it soft or add backspin to hold the top.")


def h2():
    return hole("sl_02", "Roll On", 4, (-200, -1600, 5600, 2300), (360, 0), (4600, -40),
        [ground(left_wall() + [P(520, 0), P(800, -80), P(1050, -140), P(1300, -60), P(1450, 10, m="rough"), P(1650, 20, m="rough"),
            P(1800, -60), P(2100, -170), P(2400, -80), P(2550, 10, m="rough"), P(2750, 20, m="rough"), P(2900, -60), P(3200, -160),
            P(3500, -90), P(3700, -40), P(4000, -30), P(4300, -36), P(4600, -40), P(4900, -44), P(5000, -50)] +
            right_wall(5400, -1100, -70))],
        decor=[deco("windmill", 1050, -140), deco("bush", 1550, 15), deco("pinwheel", 2100, -170), deco("bush", 2650, 15),
               deco("windmill", 3200, -160, 0.9), deco("gear", 4900, -44)],
        notes="Rolling crests with rough in every trough. Land on a downslope and let it run; topspin carries it over the next crest.")


def h3():
    p, z = pond(1600, 2790, -20, 180)
    return hole("sl_03", "Narrow Ledge", 4, (-200, -1900, 4000, 2600), (360, 0), (2550, -340),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1500, -20)] + p[:-1] +
            [P(2800, 60, c=True, m=R), P(2800, -300, c=True, m=R), P(2300, -300, c=True, m=R), P(2300, -340, c=True),
             P(2800, -340, c=True, m=R), P(2840, -900, c=True), P(3200, -910), P(3800, -920, c=True)])],
        zones=[z],
        decor=[deco("windmill", 700, -10), deco("bush", 1350, -20), deco("pinwheel", 2500, -400), deco("windmill", 3400, -912, 0.9)],
        notes="The green is a narrow ledge jutting from the cliff above a pond. Land soft or with backspin: a hot landing kicks off the cliff face and drops into the water.")


def h4():
    return hole("sl_04", "Backboard", 4, (-200, -1800, 4400, 2500), (360, 0), (3250, -20),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1800, -20)] + bunker(2300, 2950, -20, 50) +
            [P(3050, -20), P(3250, -20), P(3350, -20), P(3400, -20, c=True, m=R), P(3440, -900, c=True), P(3800, -910),
             P(4200, -920, c=True)])],
        decor=[deco("windmill", 700, -10), deco("bush", 1500, -20), deco("gear", 2000, -20), deco("pinwheel", 3100, -20)],
        notes="A long bunker guards a green at the foot of a tall wall. Plug it in the sand, or bank the ball off the backboard and let it drop onto the green; spin changes the rebound.")


def h5():
    p, z = pond(3740, 4500, -100, 120)
    return hole("sl_05", "Stop Short", 4, (-200, -1900, 5200, 2600), (360, -500), (3550, -104),
        [ground([P(-200, -1100, c=True), P(-90, -1050), P(20, -700), P(120, -540), P(260, -500), P(600, -500), P(800, -470),
            P(1100, -380), P(1400, -300), P(1800, -250), P(2300, -200), P(2700, -160)] + bunker(2850, 3250, -140, 45) +
            [P(3350, -110), P(3550, -104), P(3700, -110)] + p + [P(4600, -110), P(4700, -120)] + right_wall(5000, -1100, -140))],
        zones=[z],
        decor=[deco("windmill", 500, -500), deco("bush", 1500, -290), deco("gear", 2400, -195), deco("pinwheel", 3400, -108),
               deco("windmill", 4800, -125, 0.9)],
        notes="A short green sits between a bunker and the water. A plain shot that lands hot runs off the back into the pond; hit it high and soft, or check it with backspin.")


def h6():
    return hole("sl_06", "Conveyor Climb", 5, (-200, -2100, 5200, 2800), (360, 0), (4200, -700),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1100, 0, m=BR), P(1700, 0), P(1760, 0, c=True, m=R), P(1800, -240, c=True),
            P(1900, -242, m=BL), P(2600, -242), P(2660, -242, c=True, m=R), P(2700, -480, c=True), P(2800, -482, m=BR),
            P(3300, -482), P(3360, -482, c=True, m=R), P(3400, -700, c=True), P(3700, -700), P(4200, -700), P(4500, -710)] +
            right_wall(5000, -1600, -730))],
        decor=[deco("gear", 700, 0), deco("windmill", 1400, 0, 0.9), deco("gear", 2200, -242), deco("pinwheel", 3000, -482),
               deco("windmill", 4000, -700)],
        notes="Climb three terraces of conveyor belts: the first and third carry the ball on, the middle one drags it back toward the drop.")


def h7():
    return hole("sl_07", "Pillar Hop", 4, (-200, -1800, 5000, 2500), (360, 0), (4000, -40),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1100, -20), P(1160, 10, c=True, m=R), P(1180, 260, c=True, m="sand"),
            P(1500, 260, c=True, m=R), P(1500, -80, c=True), P(1700, -80, c=True, m=R), P(1700, 260, c=True, m="sand"),
            P(2100, 260, c=True, m=R), P(2100, -140, c=True), P(2300, -140, c=True, m=R), P(2300, 260, c=True, m="sand"),
            P(2700, 260, c=True, m=R), P(2700, -60, c=True), P(2900, -60, c=True, m=R), P(2900, 260, c=True, m="sand"),
            P(3180, 260, c=True, m=R), P(3200, 10, c=True), P(3300, -20), P(3700, -30), P(4000, -40), P(4300, -44)] +
            right_wall(4800, -1000, -60))],
        zones=[zone("water", 1164, 30, 3196, 280)],
        decor=[deco("windmill", 700, -10), deco("pinwheel", 1600, -80), deco("bush", 2200, -140), deco("pinwheel", 2800, -60),
               deco("windmill", 3600, -28, 0.9)],
        notes="Stone pillars rise from the pond, too far apart to fly in one go. Hop them with checked landings, or risk the long carry.")


def h8():
    return hole("sl_08", "Half-Pipe", 5, (-200, -1800, 5200, 2600), (360, -200), (4000, -224),
        [ground([P(-200, -900, c=True), P(-90, -850), P(20, -500), P(120, -240), P(260, -200), P(700, -200), P(900, -180),
            P(1100, -60), P(1300, 150), P(1600, 330), P(2000, 400, m="rough"), P(2400, 400), P(2800, 330), P(3100, 150),
            P(3300, -60), P(3500, -200), P(3700, -220), P(4000, -224), P(4300, -220), P(4600, -230)] +
            right_wall(5000, -1000, -250))],
        decor=[deco("windmill", 500, -200), deco("bush", 2200, 400), deco("gear", 3800, -222), deco("pinwheel", 4300, -220)],
        notes="A deep half-pipe separates the tee from the green. Fly it, or ride it: the ball's momentum (and topspin) can carry it up the far wall.")


def h9():
    p, z = pond(2400, 3200, -140, 60)
    return hole("sl_09", "Spin Cycle", 5, (-200, -2000, 6400, 2700), (360, 0), (5400, -560),
        [ground(left_wall() + [P(520, 0), P(800, -80), P(1100, -120), P(1350, -40), P(1500, 10, m="rough"), P(1700, 20, m="rough"),
            P(1900, -60), P(2200, -140)] + p + [P(3300, -150), P(3500, -150, m=BR), P(4000, -150), P(4060, -150, c=True, m=R),
            P(4100, -400, c=True), P(4300, -400), P(4500, -420), P(4700, -460, m="rough"), P(4850, -500), P(4950, -520, c=True, m=R),
            P(4990, -560, c=True), P(5200, -562), P(5400, -560), P(5600, -562), P(5650, -560, c=True, m=R),
            P(5700, -480, c=True, m="sand"), P(5900, -470), P(6000, -480)] + right_wall(6200, -1300, -500))],
        zones=[z],
        decor=[deco("windmill", 700, -50), deco("bush", 1600, 15), deco("pinwheel", 2000, -100), deco("gear", 3700, -150),
               deco("windmill", 4300, -400, 0.9), deco("pinwheel", 5300, -561)],
        notes="Everything spin: crests to run over, a pond, a belt, a rough climb, and a perched green with a sand drop behind it.")


def build():
    return write_course("spin_land", "Spin Land", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 6,
                        "Hard", "Spin control: perched greens, long rolls, rebounds and belts",
                        {"parSource": "design", "layout": 2}, strict=True)


if __name__ == "__main__":
    build()
