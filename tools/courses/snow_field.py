"""Course 4: Snow Field - snow and ice (docs/COURSE_MANIFEST.md).

Original layouts. Snow and ice are different physics materials: snow is soft, grabs the ball and
plugs it on landing; ice is almost frictionless, so balls (and spin) slide. Holes mix both with
water, steep slopes and a ski jump. The Ice Ball ability can freeze the lakes.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import P, ground, left_wall, right_wall, block, poly, water, pond, deco, hole, write_course  # noqa: E402

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


def h1():
    return hole("sf_01", "First Frost", 3, (-200, -1500, 3300, 2200), (360, 0), (2300, -20),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1200, -20), P(1500, -20, m=I), P(1950, -20), P(2050, -20), P(2600, -20),
            P(2700, -40)] + right_wall(3100, -900, -60), material=S)],
        decor=[deco("pine", 650, 0), deco("snowman", 1100, -20), deco("pine", 2700, -40), deco("rock", 1800, -20)],
        notes="Snow holds the ball; the strip of ice in front of the green does not. Land past it or roll across it gently.")


def h2():
    return hole("sf_02", "The Rink", 3, (-200, -1400, 3800, 2100), (360, 0), (3160, -10),
        [ground(left_wall() + [P(520, 0), P(800, 0, m=I), P(2900, 0), P(3000, -10), P(3260, -10), P(3330, -40, m="rock"),
            P(3380, -140)] + right_wall(3700, -900, -160), material=S)],
        decor=[deco("pine", 600, 0), deco("flag_small", 1800, 0), deco("pine", 3450, -300)],
        notes="A long sheet of ice. Power is everything: a putt-weight shot slides for hundreds of pixels. A rock lip behind the green stops the worst overruns.")


def h3():
    return hole("sf_03", "Slalom", 4, (-200, -2200, 4200, 2900), (360, -900), (3500, -20),
        [ground([P(-200, -1500, c=True), P(-90, -1440), P(20, -1100), P(120, -940), P(260, -900), P(520, -900), P(700, -860),
            P(950, -740), P(1150, -690, m=I), P(1300, -640), P(1450, -560), P(1700, -470, m=I), P(1850, -420), P(2050, -330),
            P(2300, -240, m=I), P(2450, -190), P(2700, -110), P(2950, -40), P(3200, -20), P(3600, -20), P(3800, -40)] +
            right_wall(4000, -900, -60), material=S)],
        decor=[deco("pine", 400, -900), deco("pine", 1000, -730), deco("flag_slalom", 1500, -550), deco("flag_slalom", 2350, -230),
               deco("pine", 3700, -40)],
        notes="Downhill through gates of ice. Every icy patch speeds the ball up the hill's fall line.")


def h4():
    return hole("sf_04", "Frozen Lake", 4, (-200, -1500, 3700, 2200), (360, 0), (1900, -60),
        [ground(left_wall() + [P(520, 0), P(760, 10), P(820, 60, c=True), P(840, 240, c=True, m="rock"), P(2860, 240, c=True),
            P(2880, 60, c=True), P(2940, 0), P(3100, -10)] + right_wall(3500, -900, -30), material=S),
         poly([P(1700, -60, m=S), P(1820, -66), P(1980, -66), P(2100, -60), P(2120, 20, m="rock"), P(2000, 70), P(1800, 70),
               P(1680, 20)], "rock", smooth=True)],
        zones=[water(844, 80, 2856, 260)],
        decor=[deco("pine", 600, 0), deco("pine", 3000, -10), deco("ice_chunk", 1300, 80), deco("ice_chunk", 2500, 80)],
        notes="An island green in a frozen-over lake that is not frozen enough to stand on. Carry it, or bring an Ice Ball.")


def h5():
    return hole("sf_05", "Avalanche Ridge", 4, (-200, -2100, 3400, 2800), (360, 0), (2600, -760),
        [ground(left_wall() + [P(520, 0), P(800, -60), P(1000, -200, m=I), P(1150, -280), P(1300, -300), P(1500, -420, m=I),
            P(1650, -500), P(1800, -520), P(2000, -640, m=I), P(2150, -720), P(2300, -750), P(2500, -760), P(2800, -760),
            P(2900, -780)] + right_wall(3200, -1500, -800), material=S)],
        decor=[deco("pine", 650, -10), deco("rock", 1300, -300), deco("pine", 1800, -520), deco("snowman", 2450, -760)],
        notes="Uphill in steps. The icy ramps between the shelves send short shots sliding back down.")


def h6():
    return hole("sf_06", "Icicle Cave", 4, (-200, -1600, 3600, 2300), (360, 0), (2500, 0),
        [ground(left_wall() + [P(520, 0), P(900, 0), P(1100, 0, m=I), P(2200, 0), P(2300, 0), P(2700, 0), P(2800, -20)] +
            right_wall(3400, -1000, -40), material=S),
         poly([P(1050, -250, c=True, m="rock"), P(1300, -200), P(1600, -230), P(1900, -190), P(2200, -220), P(3400, -260, c=True),
               P(3400, -1200, c=True), P(1300, -1200, c=True), P(1100, -700), P(1000, -400)], "rock", smooth=True)],
        decor=[deco("icicle", 1350, -205), deco("icicle", 1750, -215), deco("icicle", 2150, -215), deco("pine", 700, 0)],
        notes="A low cave with an ice floor. Run it in under the icicles; it will keep sliding if you hit it too hard.")


def h7():
    return hole("sf_07", "Ski Jump", 4, (-200, -2200, 4200, 2900), (360, -800), (3300, 0),
        [ground([P(-200, -1500, c=True), P(-90, -1440), P(20, -1000), P(120, -840), P(260, -800), P(480, -800), P(600, -760),
            P(700, -680, m=I), P(900, -470), P(1080, -330), P(1200, -300), P(1260, -320, c=True), P(1290, -330, c=True),
            P(1300, 200, c=True), P(2350, 200, c=True), P(2360, 20, c=True), P(2500, 0), P(3000, 0), P(3600, 0), P(3700, -20)] +
            right_wall(4000, -900, -40), material=S)],
        zones=[water(1310, 120, 2340, 260)],
        decor=[deco("pine", 400, -800), deco("flag_slalom", 1150, -310), deco("pine", 2700, 0), deco("snowman", 3500, 0)],
        notes="Roll down the icy in-run and off the kicker: the jump carries the gap. A soft flighted shot works too.")


def h8():
    return hole("sf_08", "Crevasse", 4, (-200, -1600, 3500, 2600), (360, 0), (2560, -40),
        [ground(left_wall() + [P(520, 0), P(900, -10), P(1150, -20, m=I), P(1260, -20), P(1300, 40, c=True), P(1330, 700, c=True),
            P(1620, 700, c=True), P(1650, 40, c=True), P(1700, -30), P(2000, -40), P(2400, -40), P(2700, -40), P(2800, -60)] +
            right_wall(3300, -900, -80), material=S, bottom=900)],
        zones=[water(1334, 560, 1616, 760)],
        decor=[deco("pine", 700, -10), deco("ice_chunk", 1200, -20), deco("pine", 2200, -40), deco("rock", 1750, -30)],
        notes="A deep crack in the ice field. The lip in front of it is ice, so lay up early or commit to the carry.")


def h9():
    return hole("sf_09", "Summit", 5, (-200, -2400, 4400, 3100), (360, 0), (3750, -1060),
        [ground(left_wall() + [P(520, 0), P(800, -40), P(1100, -120, m=I), P(1300, -160), P(1500, -170), P(1700, -260),
            P(1900, -420, m="rock"), P(1980, -560), P(2100, -600), P(2400, -620, m=I), P(2600, -620), P(2800, -700),
            P(3000, -860, m="rock"), P(3080, -1000), P(3200, -1050), P(3500, -1060), P(3900, -1060), P(4000, -1080)] +
            right_wall(4200, -1700, -1100), material=S)],
        decor=[deco("pine", 650, -20), deco("pine", 1400, -165), deco("rock", 2000, -580), deco("snowman", 2700, -650),
               deco("summit_flag", 3950, -1070)],
        notes="The long climb to the top: snowfields, an icy plateau and two rocky steps.")


def build():
    return write_course("snow_field", "Snow Field", THEME, [h1(), h2(), h3(), h4(), h5(), h6(), h7(), h8(), h9()], 4,
                        "Medium", "Snow grabs, ice slides: power control, slopes and frozen water")


if __name__ == "__main__":
    build()
