"""Course 5: Gravity Lab - gravity fields (docs/COURSE_MANIFEST.md, PHYSICS_SPEC.md section 6).

Rebuilt in Super Stickman Golf 3's structure (tour 2, course 5; nine holes). SSG3's Gravity Lab
pars and geometry are not available, so the pars here are design pars and every layout is
original. Every hole uses gravity fields that change the ball's real physics: low gravity, heavy
gravity, lift shafts (upward gravity), sideways pull and zero-G. Acid vats are the hazard. Par on
SSG3's Gravity Lab unlocks the Anti-Grav Ball.

Each lab is a room: tall walls with the ceiling resting on them (ceiling dips make low roofs
where a hole needs one), and upper decks grow out of a wall. Nothing floats; the room still
contains every field so no ball can drift away.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, zone, gravity, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "lab", "art": "lab",
    "sky_top": "#141c33", "sky_bottom": "#2c3e66", "sun": "#9ff7ff",
    "far_hills": "#24365a", "mid_hills": "#33507a",
    "ground_top": "#5c6a80", "ground_bottom": "#2a3142", "ground_strata": "#48546a",
    "grass": "#9fe8ff", "grass_light": "#d8fbff", "grass_dark": "#4fb0d8",
    "outline": "#0e1220", "water_top": "#7dff6a", "water_bottom": "#2a8a3a", "cloud": "#3a4a70",
}
M = "rock"   # lab floor plating (art: metal); physics: rock


def acid(x0, y0, x1, y1):
    return zone("acid", x0, y0, x1, y1)


def ceiling(x0, x1, top, dips=()):
    """The room's ceiling resting on the walls at x0 and x1, underside at `top`. dips: (a, b, y)
    sections where the roof comes down to y (low roofs)."""
    under = [P(x1, top, c=True)]
    for a, b, y in sorted(dips, reverse=True):
        under += [P(b, top, c=True), P(b, y, c=True), P(a, y, c=True), P(a, top, c=True)]
    under.append(P(x0, top, c=True))
    return poly([P(x0, top - 120, c=True, m=M), P(x1, top - 120, c=True)] + under, M)


def h1():
    return hole("gl5_01", "Low-G Orientation", 5, (-200, -1800, 6000, 2500), (360, 0), (4300, -220),
        [ground(left_wall(top=-1500) + [P(520, 0), P(900, -10), P(1300, -20, c=True, m=M), P(1300, -800, c=True, m=M),
            P(1380, -800, c=True, m=M), P(1380, -20, c=True), P(1800, -20), P(1900, -20, c=True, m=M), P(1920, 200, c=True),
            P(2680, 200, c=True, m=M), P(2700, -20, c=True), P(3200, -20), P(3300, -20, c=True, m=M), P(3300, -700, c=True, m=M),
            P(3380, -700, c=True, m=M), P(3380, -20, c=True), P(3600, -20, c=True, m=M), P(3640, -220, c=True), P(4000, -226),
            P(4300, -220), P(4600, -228), P(4900, -232), P(5200, -240, c=True, m=M), P(5200, -700, c=True), P(5800, -720, c=True),
            P(5800, -1500, c=True)], material=M),
         ceiling(-200, 5800, -1500)],
        zones=[acid(1924, 80, 2676, 220)],
        fields=[gravity(-200, -1500, 5800, 700, scale=0.4)],
        decor=[deco("console", 700, 0), deco("lab_light", 1600, -20), deco("vat_pipe", 2300, 200), deco("console", 3000, -20),
               deco("lab_light", 4500, -225)],
        notes="The whole room runs at 40% gravity. Shots fly two and a half times as far and roll further too: float over two dividers and the acid vat to the raised green.")


def h2():
    return hole("gl5_02", "Lift Shaft", 4, (-200, -2000, 4000, 2700), (360, 0), (2700, 0),
        [ground(left_wall(top=-1700) + [P(520, 0), P(800, 0), P(1100, 0), P(1500, 0, c=True, m=M), P(1500, -1300, c=True, m=M),
            P(1620, -1300, c=True, m=M), P(1620, 0, c=True), P(2000, 0), P(2500, 0), P(2700, 0), P(3000, 0), P(3200, -20)] +
            right_wall(3800, -1700, -40), material=M),
         ceiling(-200, 3800, -1700)],
        fields=[gravity(1100, -1690, 1500, 0, vector=(0, -1400))],
        decor=[deco("arrow_up", 1300, 0), deco("console", 650, 0), deco("lab_light", 2300, 0), deco("fan", 3100, -10)],
        notes="The wall is far too tall to clear. Roll into the lift shaft beside it, ride it to the ceiling, and drift over the top.")


def h3():
    return hole("gl5_03", "Float Chamber", 4, (-200, -1800, 4400, 2500), (360, 0), (3500, -20),
        [ground(left_wall(top=-1500) + [P(520, 0), P(760, 0), P(800, 30, c=True, m=M), P(820, 260, c=True), P(2780, 260, c=True, m=M),
            P(2800, 30, c=True), P(2860, -20), P(3200, -20), P(3500, -20), P(3800, -30)] + right_wall(4200, -1500, -40), material=M),
         ceiling(-200, 4200, -1500, dips=[(700, 2900, -700)])],
        zones=[acid(824, 120, 2776, 280)],
        fields=[gravity(800, -700, 2800, 30, scale=0.25)],
        decor=[deco("vat_pipe", 950, 120), deco("vat_pipe", 2650, 120), deco("console", 600, 0), deco("lab_light", 3300, -20)],
        notes="A low-gravity chamber over a long acid vat, under a low roof. Hit it softly: the ball floats, and anything too high bounces off the ceiling.")


def h4():
    return hole("gl5_04", "Heavy Landing", 4, (-200, -1800, 4400, 2500), (360, 0), (3100, -20),
        [ground(left_wall(top=-1200) + [P(520, 0), P(900, -10), P(1400, -20), P(1500, -20, c=True, m=M), P(1520, 220, c=True),
            P(2080, 220, c=True, m=M), P(2100, -20, c=True), P(2500, -20), P(2900, -20), P(3100, -20), P(3400, -20),
            P(3700, -30)] + right_wall(4200, -1200, -50), material=M)],
        zones=[acid(1524, 100, 2076, 240)],
        fields=[gravity(2400, -1400, 3600, 0, scale=2.6)],
        decor=[deco("console", 900, -10), deco("vat_pipe", 1800, 220), deco("arrow_down", 3000, -20), deco("lab_light", 3800, -32)],
        notes="Carry the acid gap; then a heavy-gravity field over the green slams long shots straight down. Aim to enter it just past its edge.")


def h5():
    return hole("gl5_05", "Crosswind", 5, (-200, -1800, 4800, 2500), (360, 0), (4000, -300),
        [ground(left_wall(top=-1200) + [P(520, 0), P(900, -10), P(1500, -20), P(1540, 20, c=True, m=M), P(1560, 240, c=True),
            P(2340, 240, c=True, m=M), P(2360, 20, c=True), P(2400, -20), P(2900, -20), P(3200, -20), P(3300, -20, c=True, m=M),
            P(3340, -300, c=True), P(3700, -300), P(4000, -300), P(4300, -310)] + right_wall(4600, -1300, -330), material=M)],
        zones=[acid(1564, 110, 2336, 260)],
        fields=[gravity(1100, -1500, 2600, -80, vector=(-260, 1400))],
        decor=[deco("fan", 3000, -20), deco("lab_light", 600, -5), deco("console", 3550, -300), deco("lab_light", 4200, -305)],
        notes="Gravity over the wide vat pulls back toward the tee as well as down. Over-hit into the headwind, then pop up the step to the green.")


def h6():
    return hole("gl5_06", "Ceiling Walk", 4, (-200, -1900, 4400, 2600), (360, 0), (3500, -160),
        [ground(left_wall(top=-1600) + [P(520, 0), P(800, 0), P(1000, 0), P(1050, 30, c=True, m=M), P(1070, 260, c=True),
            P(2230, 260, c=True, m=M), P(2250, 30, c=True), P(2300, 0), P(2700, 0), P(3000, 0, c=True, m=M), P(3040, -160, c=True),
            P(3300, -162), P(3500, -160), P(3700, -166), P(3800, -172)] + right_wall(4200, -1600, -190), material=M),
         ceiling(-200, 4200, -1600, dips=[(900, 2400, -800)])],
        zones=[acid(1074, 120, 2226, 280)],
        fields=[gravity(1050, -800, 2250, -140, vector=(0, -1500))],
        decor=[deco("arrow_up", 1600, 0), deco("console", 600, 0), deco("lab_light", 2600, 0), deco("lab_light", 3700, -166)],
        notes="Over the vat gravity points up. The ball falls onto the ceiling, rolls along it and drops off the far end; time it to come down on the raised green.")


def h7():
    return hole("gl5_07", "Zero-G Corridor", 5, (-200, -1800, 4400, 2500), (360, 0), (3400, -320),
        [ground(left_wall(top=-1400) + [P(520, 0), P(900, 0), P(960, 30, c=True, m=M), P(980, 260, c=True), P(2620, 260, c=True, m=M),
            P(2640, 30, c=True), P(2700, -300, c=True), P(2900, -310), P(3400, -320), P(3700, -320), P(3800, -340)] +
            right_wall(4200, -1400, -360), material=M),
         ceiling(-200, 4200, -1400, dips=[(900, 2700, -560)])],
        zones=[acid(984, 120, 2616, 280)],
        fields=[gravity(960, -560, 2640, 30, scale=0.0)],
        decor=[deco("lab_light", 700, 0), deco("vat_pipe", 1800, 260), deco("console", 3100, -315), deco("lab_light", 3600, -320)],
        notes="No gravity at all over the vat: the ball flies dead straight until it hits something. Aim the exit at the raised green.")


def h8():
    return hole("gl5_08", "Flip Floors", 5, (-200, -2200, 3800, 2900), (360, 0), (2900, -1020),
        [ground(left_wall(top=-1800) + [P(520, 0), P(900, 0), P(1500, 0), P(1900, 0), P(2300, 0), P(2700, 0), P(3200, 0, c=True, m=M),
            P(3200, -940, c=True, m=M), P(1400, -940, c=True, m=M), P(1400, -1020, c=True), P(2000, -1020), P(2600, -1020),
            P(3000, -1020), P(3600, -1030, c=True), P(3600, -1800, c=True)], material=M),
         ceiling(-200, 3600, -1800)],
        fields=[gravity(1100, -1700, 1400, 0, vector=(300, -1400))],
        decor=[deco("arrow_up", 1250, 0), deco("console", 2200, 0), deco("lab_light", 2600, -1020), deco("fan", 700, 0)],
        notes="The cup is on the upper deck, which grows out of the far wall. A lift beside the deck carries the ball up and over onto it.")


def h9():
    return hole("gl5_09", "Experiment 9", 5, (-200, -2500, 5600, 3200), (360, 0), (4700, -920),
        [ground(left_wall(top=-2000) + [P(520, 0), P(800, 0), P(900, 30, c=True, m=M), P(920, 260, c=True), P(1880, 260, c=True, m=M),
            P(1900, 30, c=True), P(1960, 0), P(2300, 0), P(2500, 0), P(5000, 0, c=True, m=M), P(5000, -860, c=True, m=M),
            P(2800, -860, c=True, m=M), P(2800, -920, c=True), P(3400, -920), P(4000, -920), P(4700, -920), P(5400, -930, c=True),
            P(5400, -2000, c=True)], material=M),
         ceiling(-200, 5400, -2000, dips=[(800, 2000, -900)])],
        zones=[acid(924, 120, 1876, 280)],
        fields=[gravity(900, -900, 1900, 30, scale=0.3), gravity(2400, -1900, 2800, 0, vector=(250, -1400)),
                gravity(3200, -1900, 4400, -930, vector=(-300, 1400))],
        decor=[deco("lab_light", 600, 0), deco("arrow_up", 2600, 0), deco("console", 3600, -920), deco("fan", 4400, -920),
               deco("lab_light", 4950, -922)],
        notes="Float the low-g vat, ride the lift onto the upper deck, then play the long approach into a crosswind that pushes back toward the tee.")


def build():
    return write_course("gravity_lab", "Gravity Lab", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 5,
                        "Hard", "Gravity fields: low-G, heavy-G, lifts, sideways pull and zero-G",
                        {"parSource": "design", "layout": 2}, strict=True)


if __name__ == "__main__":
    build()
