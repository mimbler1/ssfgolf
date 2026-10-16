"""Course 1: Golf Land - the introductory grassland course (docs/COURSE_MANIFEST.md).

Teaches the fundamentals in order: a basic drive, carrying water, platforms, a bounce pad,
a downhill run, a low tunnel shot, an island green, a long multi-shot hole and a finale that
combines them. Eight holes come from the original Sunny Meadows set (re-ordered, given pars);
"Step Up" is new and replaces Sticky Cliffs, which moved to Sticky Zone's theme.
"""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from build_courses import HOLES as MEADOW_HOLES, MEADOW_THEME  # noqa: E402
from lib import P, ground, left_wall, right_wall, deco, hole, write_course  # noqa: E402

THEME = dict(MEADOW_THEME)


def _from_meadow(sm_id, gl_id, par):
    h = copy.deepcopy(next(x for x in MEADOW_HOLES if x["id"] == sm_id))
    h["id"] = gl_id
    h["par"] = par
    return h


STEP_UP = hole(
    "gl_03", "Step Up", 4, (-200, -1700, 3200, 2400), (360, 0), (2380, -520),
    [ground(left_wall() + [
        P(560, 0), P(700, 0, c=True, m="rock"), P(740, -170, c=True), P(800, -180), P(1050, -184), P(1260, -180, c=True, m="rock"),
        P(1300, -350, c=True), P(1360, -356), P(1640, -360), P(1840, -356, c=True, m="rock"), P(1880, -520, c=True),
        P(1960, -524), P(2200, -520), P(2560, -520), P(2600, -540)] + right_wall(3000, -1100, -540))],
    decor=[deco("bush", 480, 0), deco("flowers", 960, -184), deco("tree", 1500, -360, 0.9), deco("rock", 2050, -520),
           deco("tree", 2700, -560, 1.0)],
    notes="Three terraces. Each riser is rock: hit up onto the next shelf with enough height to stop.")


def build():
    holes = [
        _from_meadow("sm_01", "gl_01", 3),
        _from_meadow("sm_02", "gl_02", 3),
        STEP_UP,
        _from_meadow("sm_03", "gl_04", 3),
        _from_meadow("sm_08", "gl_05", 3),
        _from_meadow("sm_07", "gl_06", 4),
        _from_meadow("sm_06", "gl_07", 4),
        _from_meadow("sm_05", "gl_08", 5),
        _from_meadow("sm_09", "gl_09", 4),
    ]
    return write_course("golf_land", "Golf Land", THEME, holes, 1, "Beginner",
                        "Fundamentals: power, angle, bounce, roll, water and sand",
                        {"aliases": ["sunny_meadows"]})


if __name__ == "__main__":
    build()
