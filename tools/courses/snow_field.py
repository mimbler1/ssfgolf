"""Course 4: Snow Field - snow and ice (docs/COURSE_MANIFEST.md, docs/COURSE_REFERENCE.md).

Rebuilt in Super Stickman Golf 3's structure (tour 1, course 4; nine holes). SSG3's Snow Field
pars and geometry are not available, so the pars here are design pars and every layout is
original. Snow (the base ground) is soft, grabs the ball and plugs landings; ice is almost
frictionless; greens are frosted turf ("grass"). Verified detail kept as a design constraint:
hole 4 can be aced touching only the green (tests/ace_search.gd --only grass proves it). Par on
SSG3's Snow Field unlocks the Ice Ball, which freezes the lakes here.

Every solid piece is attached to the ground (no floating platforms).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, pond, deco, hole, write_course  # noqa: E402

THEME = {
    "id": "snow", "art": "snow",
    "sky_top": "#5b8fd6", "sky_bottom": "#e6f2ff", "sun": "#ffffff",
    "far_hills": "#b9cbe8", "mid_hills": "#e9f1fb",
    "ground_top": "#7a8aa6", "ground_bottom": "#3e4a66", "ground_strata": "#62708c",
    "grass": "#f2f7ff", "grass_light": "#ffffff", "grass_dark": "#c9d6ea",
    "outline": "#1e2a40", "water_top": "#5fc0e8", "water_bottom": "#1e5a9a", "cloud": "#ffffff",
}
S = "snow"
I = "ice"
G = "grass"   # frosted putting green (art: cap_green)
R = "rock"


def green(points):
    """Mark a run of surface points as putting green."""
    return [P(x, y, m=G) for x, y in points]


def h1():
    return hole("sf_01", "First Frost", 4, (-200, -1600, 4600, 2300), (360, 0), (3500, -20),
        [ground(left_wall() + [P(520, 0), P(900, -30), P(1300, -60), P(1700, -40), P(2000, -20), P(2300, -20, m=I),
            P(2800, -20)] + green([(3100, -26), (3300, -30), (3500, -20), (3700, -32)]) + [P(3850, -42)] +
            right_wall(4400, -1000, -60), material=S)],
        decor=[deco("pine", 650, -5), deco("snowman", 1300, -60), deco("pine", 1900, -25), deco("ice_chunk", 2550, -20),
               deco("pine", 4000, -50)],
        notes="A rolling snowfield. Snow grabs the ball; the strip of ice in front of the green does not. Land past it or roll across it gently onto a green that gathers toward the cup.")


def h2():
    return hole("sf_02", "Ice Rink", 4, (-200, -1600, 4800, 2300), (360, 0), (3550, -150),
        [ground(left_wall() + [P(520, 0), P(800, 0), P(900, 0, m=I), P(2900, 0), P(2950, 0, c=True, m=R), P(2990, -150, c=True)] +
            green([(3200, -150), (3400, -152), (3550, -144), (3750, -154)]) + [P(3950, -162)] +
            right_wall(4600, -1100, -180), material=S)],
        decor=[deco("pine", 650, 0), deco("ice_chunk", 1500, 0), deco("ice_chunk", 2400, 0), deco("snowman", 3300, -150),
               deco("pine", 4100, -165)],
        notes="A long sheet of ice runs to a rock step. A putt-weight shot slides for hundreds of pixels: judge the power to stop on the ice by the step, or carry onto the green.")


def h3():
    return hole("sf_03", "Slalom", 4, (-200, -2000, 5000, 2700), (380, -700), (4100, 6),
        [ground([P(-200, -1300, c=True), P(-90, -1240), P(20, -900), P(120, -740), P(260, -700), P(600, -700), P(800, -650),
            P(1100, -540, m=I), P(1400, -430), P(1700, -330, m=I), P(2000, -240), P(2300, -160, m=I), P(2600, -90),
            P(2900, -40), P(3200, -10), P(3600, 0)] + green([(3850, 2), (4100, 6), (4300, 0)]) + [P(4400, -10)] +
            right_wall(4800, -1100, -40), material=S)],
        decor=[deco("pine", 450, -700), deco("flag_slalom", 1250, -490), deco("flag_slalom", 1850, -285),
               deco("flag_slalom", 2450, -125), deco("pine", 3000, -30), deco("snowman", 4450, -12)],
        notes="Downhill through the slalom: bands of ice speed the ball up, bands of snow slow it down. Land on the snow and let it run.")


def h4():
    return hole("sf_04", "Summit Green", 4, (-200, -1900, 4200, 2600), (360, -600), (2400, -304),
        [ground([P(-200, -1200, c=True), P(-90, -1140), P(20, -850), P(120, -640), P(260, -600), P(600, -600), P(700, -560),
            P(800, -420, m=R), P(900, -150), P(1000, -20), P(1300, 0), P(1600, 0), P(1800, 0), P(1880, 0, c=True, m=R),
            P(1920, -330, c=True)] + green([(1960, -332), (2150, -336), (2280, -330), (2340, -316), (2400, -304), (2460, -316),
            (2520, -330), (2650, -338)]) + [P(2750, -340), P(2900, -346), P(3300, -360)] + right_wall(4000, -1200, -380), material=S)],
        decor=[deco("pine", 480, -600), deco("snowman", 1400, 0), deco("pine", 1700, 0), deco("summit_flag", 2800, -335),
               deco("pine", 3200, -355)],
        notes="From the high tee, carry the snowy valley to a bowl-shaped green on the plateau. Land on the green and it can feed all the way into the cup.")


def h5():
    p1, z1 = pond(1250, 2050, -10, 160, bed=R)
    p2, z2 = pond(2350, 3300, -10, 160, bed=R)
    return hole("sf_05", "Frozen Lake", 5, (-200, -1700, 5400, 2400), (360, 0), (4300, -36),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1100, -10, m=I), P(1200, -10)] + p1 +
            [P(2120, -40, m=R), P(2200, -60), P(2280, -40)] + p2 + [P(3450, -20), P(3800, -30)] +
            green([(4100, -40), (4300, -36), (4500, -44)]) + [P(4650, -50)] + right_wall(5200, -1100, -70), material=S)],
        zones=[z1, z2],
        decor=[deco("pine", 650, -5), deco("ice_chunk", 1650, 40), deco("rock", 2200, -60), deco("ice_chunk", 2800, 40),
               deco("pine", 3600, -25), deco("snowman", 4700, -52)],
        notes="A lake split by a rocky spit. Hop the spit to cross in two, play round the long way, or freeze the water with the Ice Ball.")


def h6():
    return hole("sf_06", "Ice Cave", 4, (-200, -2100, 5000, 2800), (360, 0), (3900, 4),
        [ground(left_wall() + [P(520, 0), P(900, -20), P(1300, -30), P(1700, -10), P(1950, -80), P(2150, -90), P(2350, -20),
            P(2500, 0, m=I), P(3750, 0, m=G), P(3900, 4, m=G), P(4050, 0), P(4150, 0, c=True, m=R), P(4150, -200, c=True, m=R),
            P(2500, -200, c=True, m=R), P(2460, -300, c=True), P(3000, -600), P(3800, -900), P(4800, -1000, c=True)], material=S)],
        decor=[deco("pine", 650, -5), deco("snowman", 1350, -30), deco("rock", 2050, -88), deco("icicle", 2900, -190),
               deco("icicle", 3400, -190), deco("icicle", 3800, -190), deco("pine", 3100, -650)],
        notes="Clear the snow hump, then run the ball into the low ice cave under the mountain. The ice floor keeps it sliding toward the green at the back; the back wall sends overhit shots back.")


def h7():
    return hole("sf_07", "Glacier Climb", 5, (-200, -2200, 5000, 2900), (360, 0), (4100, -796),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1100, -20), P(1300, -30, c=True, m=R), P(1340, -260, c=True),
            P(1600, -270), P(1800, -280, m=I), P(2300, -430), P(2400, -440), P(2500, -440, c=True, m=R), P(2540, -640, c=True),
            P(2800, -650), P(3100, -660, m=I), P(3300, -700), P(3400, -700, c=True, m=R), P(3440, -800, c=True)] +
            green([(3700, -800), (3900, -800), (4100, -796), (4300, -806)]) + [P(4450, -816)] +
            right_wall(4800, -1600, -840), material=S)],
        decor=[deco("pine", 650, 0), deco("rock", 1500, -268), deco("ice_chunk", 2050, -355), deco("pine", 2700, -650),
               deco("ice_chunk", 3200, -680), deco("summit_flag", 4400, -812)],
        notes="Rock steps and icy ramps lead up the glacier. A ball that stops on an uphill ice ramp slides back down: carry past the top of each ramp.")


def h8():
    return hole("sf_08", "Crevasse", 4, (-200, -1600, 4600, 2300), (360, 0), (3500, -14),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1300, -20), P(1500, -20, m=I), P(1880, -20, c=True, m=R),
            P(1900, 420, c=True, m=S), P(2180, 420, c=True, m=R), P(2200, -20, c=True), P(2500, -20), P(2900, -20)] +
            green([(3300, -20), (3500, -14), (3700, -22)]) + [P(3850, -30)] + right_wall(4400, -900, -50), material=S)],
        decor=[deco("pine", 650, -5), deco("ice_chunk", 1700, -20), deco("rock", 2400, -20), deco("snowman", 2800, -20),
               deco("pine", 4000, -40)],
        notes="A deep crevasse cuts the ice field, and the lip in front of it is ice. Lay up on the snow early or commit to the carry; a ball in the crack has a steep climb out.")


def h9():
    p, z = pond(900, 1500, -20, 120, bed=R)
    return hole("sf_09", "Mountain Top", 5, (-200, -2400, 6200, 3100), (360, 0), (5300, -966),
        [ground(left_wall() + [P(520, 0), P(800, -20)] + p + [P(1650, -40), P(1900, -120), P(2200, -200), P(2400, -240, m=I),
            P(2900, -420), P(3000, -430), P(3100, -430, c=True, m=R), P(3140, -650, c=True), P(3400, -660), P(3700, -680),
            P(3800, -690, c=True, m=R), P(3840, -900, c=True), P(4100, -910), P(4400, -930, m=I), P(4700, -950),
            P(4900, -960)] + green([(5100, -970), (5300, -966), (5500, -976)]) + [P(5650, -990)] +
            right_wall(6000, -1800, -1020), material=S)],
        zones=[z],
        decor=[deco("pine", 650, -10), deco("ice_chunk", 1200, 20), deco("pine", 2000, -150), deco("snowman", 3300, -655),
               deco("pine", 4000, -905), deco("summit_flag", 5600, -985)],
        notes="The climb to the summit: a frozen pond, an icy slope, two rock steps and a last icy run to the summit green.")


def build():
    return write_course("snow_field", "Snow Field", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 4,
                        "Medium", "Snow grabs, ice slides: power control, slopes and frozen water",
                        {"parSource": "design", "layout": 2}, strict=True)


if __name__ == "__main__":
    build()
