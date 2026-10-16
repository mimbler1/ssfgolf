"""Course 5: Gravity Lab - gravity fields (docs/COURSE_MANIFEST.md, PHYSICS_SPEC.md section 6).

Original layouts. Every hole uses gravity fields that change the ball's real physics:
low gravity, heavy gravity, lift shafts (upward gravity), sideways gravity and zero-G.
Ceilings contain the fields so no ball can float away. Acid vats are the hazard.
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


def h1():
    return hole("gl5_01", "Low-G Orientation", 3, (-200, -2600, 4400, 3300), (360, 0), (3500, -20),
        [ground(left_wall(top=-1400) + [P(520, 0), P(900, -10), P(1500, -20), P(2200, -20), P(2900, -20), P(3300, -20), P(3800, -30)] +
            right_wall(4200, -1600, -40), material=M),
         block(-200, -2400, 4200, -2300, M)],
        fields=[gravity(-200, -2300, 4200, 400, scale=0.4)],
        decor=[deco("lab_light", 1000, -10), deco("console", 2400, -20), deco("lab_light", 3100, -20)],
        notes="The whole room runs at 40% gravity. Shots fly two and a half times as far and hang in the air.")


def h2():
    return hole("gl5_02", "Lift Shaft", 4, (-200, -2100, 3600, 2800), (360, 0), (2600, 0),
        [ground(left_wall(top=-1300) + [P(520, 0), P(800, 0), P(1300, 0, c=True, m=M), P(1300, -950, c=True), P(1420, -950, c=True),
            P(1420, 0, c=True), P(1800, 0), P(2300, 0), P(2900, 0), P(3000, -20)] + right_wall(3400, -1300, -40), material=M),
         block(-200, -1900, 3400, -1800, M)],
        fields=[gravity(900, -1150, 1300, 0, vector=(0, -1400))],
        decor=[deco("arrow_up", 1100, 0), deco("console", 600, 0), deco("lab_light", 2200, 0)],
        notes="The wall is far too tall to clear. Roll into the lift shaft beside it and drift over the top.")


def h3():
    return hole("gl5_03", "Float Chamber", 4, (-200, -1700, 3800, 2400), (360, 0), (3020, -20),
        [ground(left_wall(top=-1100) + [P(520, 0), P(760, 0), P(800, 30, c=True), P(820, 260, c=True), P(2580, 260, c=True),
            P(2600, 30, c=True), P(2660, -20), P(2900, -20), P(3200, -20)] + right_wall(3600, -1100, -40), material=M),
         block(700, -760, 2700, -660, M)],
        zones=[acid(824, 120, 2576, 280)],
        fields=[gravity(800, -660, 2600, 30, scale=0.25)],
        decor=[deco("vat_pipe", 900, 120), deco("vat_pipe", 2500, 120), deco("lab_light", 3000, -20)],
        notes="A low-gravity chamber over an acid vat. Hit it softly: the ball floats, and the ceiling is low.")


def h4():
    return hole("gl5_04", "Heavy Landing", 4, (-200, -1800, 3600, 2500), (360, 0), (2500, -20),
        [ground(left_wall(top=-1200) + [P(520, 0), P(900, -10), P(1400, -20), P(1900, -20), P(2100, -20), P(2500, -20), P(2900, -20),
            P(3000, -30)] + right_wall(3400, -1200, -50), material=M)],
        fields=[gravity(2050, -1400, 2950, 0, scale=2.6)],
        decor=[deco("arrow_down", 2500, -20), deco("console", 1200, -20), deco("lab_light", 3100, -30)],
        notes="A heavy-gravity field over the green slams long shots down early. Aim to land just inside it.")


def h5():
    return hole("gl5_05", "Crosswind", 4, (-200, -1800, 4000, 2500), (360, 0), (3300, -20),
        [ground(left_wall(top=-1200) + [P(520, 0), P(900, -10), P(1400, -20), P(1440, 20, c=True), P(1460, 240, c=True), P(2340, 240, c=True),
            P(2360, 20, c=True), P(2400, -20), P(3000, -20), P(3600, -30)] + right_wall(3800, -1200, -50), material=M),
         block(-200, -1600, 3800, -1500, M)],
        zones=[acid(1464, 110, 2336, 260)],
        fields=[gravity(1000, -1500, 2700, -80, vector=(-380, 1350))],
        decor=[deco("fan", 2700, -20), deco("lab_light", 600, -10), deco("console", 3200, -20)],
        notes="Gravity in the middle bay pulls back toward the tee as well as down. Over-hit into the headwind.")


def h6():
    return hole("gl5_06", "Ceiling Walk", 4, (-200, -1900, 3800, 2600), (360, 0), (2800, 0),
        [ground(left_wall(top=-1200) + [P(520, 0), P(800, 0), P(1000, 0), P(1050, 30, c=True), P(1070, 260, c=True),
            P(2230, 260, c=True), P(2250, 30, c=True), P(2300, 0), P(2700, 0), P(3100, 0)] + right_wall(3600, -1200, -20), material=M),
         block(900, -900, 2400, -800, M)],
        zones=[acid(1074, 120, 2226, 280)],
        fields=[gravity(1050, -800, 2250, -140, vector=(0, -1500))],
        decor=[deco("arrow_up", 1600, -800), deco("lab_light", 2600, 0), deco("console", 600, 0)],
        notes="Over the vat gravity points up. The ball falls onto the ceiling, rolls along it and drops off the far end.")


def h7():
    return hole("gl5_07", "Zero-G Corridor", 4, (-200, -1700, 3900, 2400), (360, 0), (3150, -320),
        [ground(left_wall(top=-1100) + [P(520, 0), P(900, 0), P(960, 30, c=True), P(980, 260, c=True), P(2420, 260, c=True),
            P(2440, 30, c=True), P(2500, -300, c=True), P(2700, -310), P(3100, -320), P(3400, -320), P(3500, -340)] +
            right_wall(3700, -1100, -360), material=M),
         block(900, -560, 2500, -480, M)],
        zones=[acid(984, 120, 2416, 280)],
        fields=[gravity(960, -480, 2440, 30, scale=0.0)],
        decor=[deco("lab_light", 700, 0), deco("console", 2900, -315), deco("lab_light", 3300, -320)],
        notes="No gravity at all over the vat: the ball flies dead straight. Aim the exit at the raised green.")


def h8():
    return hole("gl5_08", "Flip Floors", 4, (-200, -2300, 3600, 3000), (360, 0), (2700, -1040),
        [ground(left_wall(top=-1700) + [P(520, 0), P(900, 0), P(1500, 0), P(1900, 0), P(2300, 0), P(2700, 0), P(2900, -20)] +
            right_wall(3400, -1700, -40), material=M),
         block(1400, -1020, 3400, -940, M)],
        fields=[gravity(1100, -940, 1400, 0, vector=(300, -1400))],
        decor=[deco("arrow_up", 1250, 0), deco("console", 2200, 0), deco("lab_light", 3000, -1030)],
        notes="The cup is on the upper deck. A lift beside the deck carries the ball up and over onto it.")


def h9():
    return hole("gl5_09", "Experiment 9", 5, (-200, -2500, 5000, 3200), (360, 0), (4300, -620),
        [ground(left_wall(top=-1800) + [P(520, 0), P(800, 0), P(900, 30, c=True), P(920, 260, c=True), P(1880, 260, c=True),
            P(1900, 30, c=True), P(1960, 0), P(2300, 0), P(2500, 0, c=True, m=M), P(2500, -600, c=True), P(2620, -600, c=True),
            P(2620, -600), P(3000, -600), P(3400, -610), P(3800, -620), P(4400, -620), P(4600, -640)] + right_wall(4800, -1800, -660),
            material=M),
         block(-200, -2300, 4800, -2200, M)],
        zones=[acid(924, 120, 1876, 280)],
        fields=[gravity(900, -1400, 1900, 30, scale=0.3), gravity(2150, -1100, 2500, 0, vector=(250, -1400))],
        decor=[deco("lab_light", 600, 0), deco("arrow_up", 2320, 0), deco("console", 3600, -620), deco("lab_light", 4200, -620)],
        notes="Float the vat, ride the lift to the upper deck, then a long approach on normal gravity.")


def build():
    return write_course("gravity_lab", "Gravity Lab", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 5,
                        "Hard", "Gravity fields: low-G, heavy-G, lifts, sideways pull and zero-G")


if __name__ == "__main__":
    build()
