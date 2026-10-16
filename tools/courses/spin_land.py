"""Course 6: Spin Land - spin and ball control (docs/COURSE_MANIFEST.md, PHYSICS_SPEC.md section 4).

Original layouts for a breezy windmill-and-carnival world. Holes reward real spin: greens perched
above run-off slopes (backspin stops the ball), long rolling runs (topspin carries further),
narrow ledges, conveyor belts that drag and spin the ball, and a half-pipe. Every hole can still
be finished with a plain ball; spin makes it shorter and safer.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, water, pond, deco, hole, write_course  # noqa: E402

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


def h1():
    return hole("sl_01", "Check It", 3, (-200, -1600, 3400, 2300), (360, 0), (1780, -260),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1200, -40), P(1350, -120), P(1450, -230, m="rock"), P(1520, -260),
            P(1700, -262), P(1900, -258), P(2000, -240), P(2150, -150), P(2350, -40), P(2600, 20), P(2900, 20), P(3000, 0)] +
            right_wall(3200, -900, -20))],
        decor=[deco("windmill", 700, -10, 1.2), deco("pinwheel", 1600, -262), deco("bush", 2700, 20)],
        notes="A small raised green with a run-off slope behind it. Backspin stops the ball on top; topspin runs it off.")


def h2():
    return hole("sl_02", "Long Roller", 4, (-200, -1500, 4800, 2200), (360, 0), (4100, 80),
        [ground(left_wall() + [P(520, 0), P(800, -10), P(1200, 0), P(1600, 20), P(2000, 30), P(2300, 20), P(2500, 40), P(2800, 50),
            P(3200, 60), P(3600, 70), P(3900, 80), P(4300, 80), P(4400, 60)] + right_wall(4600, -900, 40))],
        decor=[deco("windmill", 1400, 10), deco("pinwheel", 2600, 45), deco("balloon", 3500, -300), deco("bush", 4200, 80)],
        notes="A long, gently falling fairway. Topspin turns a decent drive into a huge rolling one.")


def h3():
    return hole("sl_03", "Conveyor Belt", 4, (-200, -1500, 3800, 2200), (360, 0), (3000, -20),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(900, 0, m=BL), P(2200, -10), P(2300, -10), P(2600, -20), P(3200, -20),
            P(3300, -30)] + right_wall(3600, -900, -50))],
        decor=[deco("gear", 900, 0), deco("gear", 2200, -10), deco("windmill", 2900, -20)],
        notes="A belt runs back toward the tee across the middle. Fly it, or land with topspin to fight the drag.")


def h4():
    return hole("sl_04", "Ledge", 4, (-200, -1900, 3100, 2600), (360, 0), (1950, -560),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1300, 0), P(1500, 0), P(1700, 0, c=True, m="rock"), P(1720, -540, c=True),
            P(1880, -560), P(2040, -556), P(2100, -540, c=True, m="rock"), P(2120, -360, c=True), P(2400, -340), P(2700, -340),
            P(2800, -360)] + right_wall(2900, -1300, -400))],
        decor=[deco("pinwheel", 1900, -560), deco("windmill", 600, 0), deco("bush", 2500, -340)],
        notes="The green is a narrow shelf with drops on both sides. Land soft with backspin or chip on from the lower step.")


def h5():
    return hole("sl_05", "Rollercoaster", 4, (-200, -1500, 4200, 2200), (360, 0), (3600, -20),
        [ground(left_wall() + [P(520, 0), P(800, 120), P(1000, 160), P(1200, 100), P(1400, -80), P(1550, -160), P(1700, -80),
            P(1900, 120), P(2100, 170), P(2300, 100), P(2500, -100), P(2650, -170), P(2800, -100), P(3000, 20), P(3200, 0),
            P(3400, -20), P(3800, -20), P(3900, -40)] + right_wall(4000, -900, -60))],
        decor=[deco("balloon", 1550, -400), deco("pinwheel", 2650, -170), deco("windmill", 3700, -20)],
        notes="Two big humps. Momentum management: carry the crests or let the dips swing the ball back and forth.")


def h6():
    return hole("sl_06", "Back Door", 4, (-200, -1600, 3600, 2300), (360, 0), (2050, -40),
        [ground(left_wall() + [P(520, 0), P(900, -20), P(1300, -30), P(1700, -40), P(2000, -40), P(2150, -40), P(2250, 0),
            P(2400, 160), P(2550, 330, m="sand"), P(2900, 340, m="sand"), P(3050, 300), P(3200, 200)] + right_wall(3400, -800, 0))],
        decor=[deco("windmill", 1100, -30), deco("pinwheel", 1900, -40), deco("bush", 2700, 335)],
        notes="The green sits on the edge of a steep drop into a bunker. Any release sends the ball over: stop it dead.")


def h7():
    return hole("sl_07", "Belt Maze", 4, (-200, -2000, 3600, 2700), (360, 0), (2700, -620),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1300, 0), P(1600, 0), P(2000, 0), P(2400, 0), P(2700, 0), P(3000, -20)] +
            right_wall(3400, -1400, -60)),
         poly([P(900, -280, c=True, m=BR), P(1900, -280, c=True), P(1900, -230, c=True, m="rock"), P(900, -230, c=True)], "rock"),
         poly([P(1500, -620, c=True, m=BL), P(3400, -620, c=True), P(3400, -560, c=True, m="rock"), P(1500, -560, c=True)], "rock")],
        decor=[deco("gear", 900, -280), deco("gear", 1900, -280), deco("pinwheel", 2800, -620)],
        notes="Two belts: the low one carries you forward, the high one (with the green) drags you back toward its edge.")


def h8():
    return hole("sl_08", "Half Pipe", 4, (-200, -1600, 3300, 2400), (360, -400), (2560, -400),
        [ground([P(-200, -1000, c=True), P(-90, -940), P(20, -640), P(120, -440), P(260, -400), P(560, -400), P(700, -360),
            P(900, -200), P(1100, -40), P(1300, 20), P(1500, 20), P(1700, -40), P(1900, -200), P(2100, -360), P(2240, -400),
            P(2500, -400), P(2700, -400), P(2800, -420)] + right_wall(3100, -1000, -440))],
        decor=[deco("windmill", 400, -400), deco("balloon", 1400, -500), deco("pinwheel", 2600, -400)],
        notes="A big bowl between two decks. Roll it through the pipe with exactly enough pace, or fly it straight over.")


def h9():
    p, z = pond(2700, 3400, 0, 160)
    return hole("sl_09", "Spin Cycle", 5, (-200, -1900, 4600, 2600), (360, 0), (4050, -300),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(900, 0, m=BL), P(1700, 0), P(1900, -20), P(2200, -120), P(2400, -60),
            P(2600, 0)] + p + [P(3500, -20), P(3700, -150, m="rock"), P(3800, -290), P(3950, -300), P(4150, -296), P(4250, -270),
            P(4300, -200)] + right_wall(4400, -1100, -100))],
        zones=[z],
        decor=[deco("gear", 900, 0), deco("windmill", 2200, -120), deco("balloon", 3000, -350), deco("pinwheel", 4000, -300)],
        notes="A backward belt, a rolling hill, a pond and a perched green to finish: every spin skill in one hole.")


def build():
    return write_course("spin_land", "Spin Land", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 6,
                        "Hard", "Spin control: perched greens, long rolls and conveyors")


if __name__ == "__main__":
    build()
