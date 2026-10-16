"""v4 roster specs, part 2: bolt (robot builder), dino, wizard, astronaut, knight, pirate,
skeleton, cowboy. Briefs from character_defs.gd. Registered into g4_chars.SPECS."""
from __future__ import annotations

import math

from g4_chars import (SLATE_BG, SPECS, Part, _halfplane, _local, add, beard, belt, capsule, chain, collar, dk, ellipse,
                      face, hair_cap, head_local, hl, humanoid, lerp, poly, skirt, vest)
from g4_roster import hair_back, scarf


def _down(p):
    """Unit vector along the body from shoulder to hip ("down" the torso) and its normal."""
    dx, dy = p["hip"][0] - p["sh"][0], p["hip"][1] - p["sh"][1]
    L = math.hypot(dx, dy) or 1.0
    return (dx / L, dy / L), (-dy / L, dx / L)


# ---------------------------------------------------------------- robot (Bolt)

def robot(s: dict, p: dict) -> list[Part]:
    c = s["c"]
    parts: list[Part] = []
    hd, ch = p["grip"], p["ch"]
    wheel = (-1.0, -10.0)

    def club():
        if p.get("no_club") or p.get("empty_hands"):
            return
        parts.append(Part("shaft", capsule(hd, ch, 0.7), "#c9d1de", shade=False, line=False))
        a = math.atan2(ch[1] - hd[1], ch[0] - hd[0])
        parts.append(Part("clubhead", capsule(ch, (ch[0] + 3.5 * math.cos(a), ch[1] + 3.5 * math.sin(a)), 2.0, 2.3), "#aab4c4"))

    def arm(sh, el, hand, far):
        metal = c["metal"] if not far else dk(c["metal"])
        parts.append(Part("upper", capsule(p[sh], p[el], 2.6, 2.4), metal))
        parts.append(Part("fore", capsule(p[el], hand, 2.6, 2.4), metal))
        parts.append(Part("upper", ellipse(p[el], 3.2, 3.2), c["dark"] if not far else dk(c["dark"])))
        parts.append(Part("hand" if not far else "fist", ellipse(hand, 3.6, 3.3), c["body"] if not far else dk(c["body"])))

    if p["club_behind"]:
        club()
    arm("sh_f", "el_f", p.get("hd_f", p["hd"]), True)
    # wheel + telescopic stalk
    parts.append(Part("shin", capsule(wheel, p["hip"], 3.2, 3.6), c["metal"]))
    parts.append(Part("tyre", ellipse(wheel, 10.0, 10.0), c["tyre"]))
    parts.append(Part("hub", ellipse(wheel, 5.0, 5.0), c["metal"]))
    parts.append(Part("hub", ellipse(wheel, 2.0, 2.0), c["accent"], line=False))
    # body: rounded barrel with a cream chest panel
    waist = lerp(p["hip"], p["sh"], 0.05)
    chest = add(p["sh"], (-2.0, 2.0))
    parts.append(Part("torso", capsule(waist, chest, 10.5, 11.0), c["body"]))
    dn, nm = _down(p)
    pc = lerp(waist, chest, 0.55)
    parts.append(Part("panel", ellipse(add(pc, (nm[0] * -4.5, nm[1] * -4.5)), 5.5, 7.5,
                                       math.atan2(dn[1], dn[0])), c["panel"]))
    parts.append(Part("light", ellipse(add(pc, (nm[0] * -5.5 - dn[0] * 3, nm[1] * -5.5 - dn[1] * 3)), 1.6, 1.6), c["light"], line=False))
    if not p["club_behind"]:
        club()
    # head: rounded monitor box, dark screen face, LED eyes, antenna
    parts.append(Part("neck", capsule(p["neck"], head_local(p, 0, 6), 3.0), c["dark"]))
    hr = 11.0
    box = poly(hl(p, {"head": (hr, hr)}, [(-0.95, -0.85), (0.95, -0.85), (1.05, -0.65), (1.05, 0.7), (0.9, 0.88), (-0.95, 0.88), (-1.05, 0.7), (-1.05, -0.65)]))
    parts.append(Part("antenna", capsule(head_local(p, -0.2 * hr, -0.8 * hr), head_local(p, -0.35 * hr, -1.45 * hr), 0.8), c["metal"]))
    parts.append(Part("antenna", ellipse(head_local(p, -0.36 * hr, -1.55 * hr), 2.0, 2.0), c["light"]))
    parts.append(Part("head", box, c["body"]))
    parts.append(Part("visor", poly(hl(p, {"head": (hr, hr)}, [(0.05, -0.55), (1.12, -0.55), (1.12, 0.55), (0.05, 0.55)])), c["screen"], shade=False))
    for ex in (0.42, 0.85):
        parts.append(Part("eye_white", ellipse(head_local(p, ex * hr, -0.08 * hr), 1.4, 2.0), c["led"], shade=False, line=False))
    parts.append(Part("ear", ellipse(head_local(p, -0.45 * hr, 0.0), 2.6, 3.4), c["metal"]))
    arm("sh", "el", p["hd"], False)
    return parts


# ---------------------------------------------------------------- humanoid add-ons

def dino_head(s, p, pr):
    hr = pr["head"][0]
    c = s["c"]
    t = math.radians(p.get("tilt", 0))
    return [Part("head", ellipse(head_local(p, 0.75 * hr, 0.05 * hr), hr * 1.05, hr * 0.62, t), c["skin"]),
            Part("mouth", poly(hl(p, pr, [(0.2, 0.32), (1.75, 0.18), (1.7, 0.42), (0.3, 0.55)])), c["mouth"], shade=False),
            Part("teeth", poly(hl(p, pr, [(0.5, 0.3), (1.6, 0.2), (1.55, 0.3), (0.55, 0.4)])), c["claw"], shade=False, line=False),
            Part("face", ellipse(head_local(p, 0.95 * hr, 0.62 * hr), hr * 0.8, hr * 0.3, t), c["belly"]),
            Part("eye_white", ellipse(head_local(p, 0.3 * hr, -0.42 * hr), 2.0, 2.4), "#fffbe8", shade=False, line=False),
            Part("pupil", ellipse(head_local(p, 0.4 * hr, -0.38 * hr), 1.0, 1.7), c["eye"], shade=False, line=False),
            Part("brow", capsule(head_local(p, 0.1 * hr, -0.68 * hr), head_local(p, 0.55 * hr, -0.62 * hr), 1.0), c["stripe"], line=False),
            Part("face", ellipse(head_local(p, 1.62 * hr, -0.18 * hr), 1.0, 0.8), c["stripe"], shade=False, line=False)]


def dino_tail(s, p, pr):
    h = p["hip"]
    return [Part("tail", chain([add(h, (-4, 1)), add(h, (-13, 6)), add(h, (-21, 13)), add(h, (-27, 22))], [8.0, 6.0, 3.6, 1.4]), s["c"]["skin"])]


def dino_plates(s, p, pr):
    out = []
    dn, nm = _down(p)
    n0 = p["neck"]
    for i, t in enumerate((0.0, 0.3, 0.6, 0.9)):
        b = lerp(n0, p["hip"], t)
        b = add(b, (nm[0] * 9.5, nm[1] * 9.5))
        tip = add(b, (nm[0] * 4.5 - dn[0] * 1.5, nm[1] * 4.5 - dn[1] * 1.5))
        out.append(Part("plate", poly([add(b, (-dn[0] * 3, -dn[1] * 3)), tip, add(b, (dn[0] * 3, dn[1] * 3))]), s["c"]["plate"]))
    return out


def dino_belly(s, p, pr):
    dn, nm = _down(p)
    m = lerp(p["hip"], p["sh"], 0.5)
    return [Part("belly", ellipse(add(m, (-nm[0] * 6.5, -nm[1] * 6.5)), 5.5, 12.0, math.atan2(dn[1], dn[0]) + math.pi / 2), s["c"]["belly"])]


def wizard_hat(color, band, star):
    def f(s, p, pr):
        out = [Part("hat", poly(hl(p, pr, [(-1.45, -0.45), (1.55, -0.55), (1.6, -0.35), (-1.5, -0.25)])), color),
               Part("hat", poly(hl(p, pr, [(-0.9, -0.45), (0.95, -0.5), (0.2, -1.6), (-0.6, -2.3), (-1.5, -2.6), (-0.95, -2.0), (-0.5, -1.3)])), color),
               Part("band", poly(hl(p, pr, [(-0.92, -0.62), (0.95, -0.66), (0.86, -0.48), (-0.92, -0.45)])), band),
               Part("star", ellipse(head_local(p, 0.0, -1.05 * pr["head"][0]), 1.6, 1.6), star, line=False)]
        return out
    return f


def robe(color, trim):
    def f(s, p, pr):
        h = p["hip"]
        ground = -1.5
        k = (p["kb"][0] + p["kf"][0]) / 2
        top = add(h, (0, -4))
        pts = [add(top, (-9, 0)), add(top, (9, 0)), (max(p["af"][0], p["kf"][0]) + 6, ground - 4), (min(p["ab"][0], p["kb"][0]) - 6, ground - 4)]
        return [Part("robe", poly(pts), color),
                Part("trim", capsule((pts[3][0] + 1, ground - 4.5), (pts[2][0] - 1, ground - 4.5), 1.3), trim)]
    return f


def helmet_bubble(color, glass):
    def f(s, p, pr):
        hr = pr["head"][0]
        ring = ellipse(head_local(p, 0.05 * hr, -0.05 * hr), hr * 1.32, hr * 1.3)
        hole = ellipse(head_local(p, 0.42 * hr, 0.05 * hr), hr * 0.78, hr * 0.85)
        return [Part("helmet", ring & ~hole, color),
                Part("visor", poly(hl(p, pr, [(0.0, -1.05), (1.0, -0.85), (1.25, -0.35), (0.5, -0.62)])), glass, shade=False)]
    return f


def backpack(color):
    def f(s, p, pr):
        dn, nm = _down(p)
        m = lerp(p["hip"], p["sh"], 0.6)
        c0 = add(m, (nm[0] * 10.5, nm[1] * 10.5))
        return [Part("pack", ellipse(c0, 5.5, 10.0, math.atan2(dn[1], dn[0]) + math.pi / 2), color)]
    return f


def great_helm(color, plume, eye):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = [Part("plume", chain([head_local(p, -0.1 * hr, -1.0 * hr), head_local(p, -0.9 * hr, -1.5 * hr), head_local(p, -1.6 * hr, -1.2 * hr)], [3.2, 3.6, 2.2]), plume),
               Part("helmet", poly(hl(p, pr, [(-1.05, -0.95), (0.95, -1.0), (1.15, -0.55), (1.18, 0.55), (0.9, 1.05), (-1.0, 1.05), (-1.1, 0.0)])), color),
               Part("visor", poly(hl(p, pr, [(0.2, -0.22), (1.2, -0.25), (1.2, -0.05), (0.2, -0.02)])), "#1d1a2b", shade=False),
               Part("eye_white", ellipse(head_local(p, 0.75 * hr, -0.13 * hr), 1.6, 0.9), eye, shade=False, line=False)]
        return out
    return f


def cape(color):
    def f(s, p, pr):
        dn, nm = _down(p)
        sh = add(p["sh"], (-3, 0))
        b0 = add(sh, (nm[0] * 6, nm[1] * 6))
        b1 = add(p["hip"], (nm[0] * 13 + dn[0] * 18, nm[1] * 13 + dn[1] * 18))
        b2 = add(p["hip"], (nm[0] * 2 + dn[0] * 20, nm[1] * 2 + dn[1] * 20))
        return [Part("cape", poly([add(sh, (-nm[0] * 2, -nm[1] * 2)), b0, b1, b2]), color)]
    return f


def tabard(color, trim):
    def f(s, p, pr):
        dn, nm = _down(p)
        a = add(lerp(p["sh"], p["hip"], 0.05), (-nm[0] * 2.5, -nm[1] * 2.5))
        b = add(p["hip"], (-nm[0] * 2.5 + dn[0] * 12, -nm[1] * 2.5 + dn[1] * 12))
        return [Part("tabard", capsule(a, b, 7.5, 7.0), color),
                Part("trim", ellipse(lerp(a, b, 0.3), 2.6, 2.8), trim, line=False)]
    return f


def tricorn(color, trim):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("hat", poly(hl(p, pr, [(-1.6, -0.35), (-1.0, -1.25), (0.0, -0.95), (1.0, -1.25), (1.7, -0.32), (0.0, -0.48)])), color),
                Part("trim", poly(hl(p, pr, [(-1.6, -0.35), (0.0, -0.48), (1.7, -0.32), (1.62, -0.22), (0.0, -0.36), (-1.55, -0.24)])), trim),
                Part("hat", ellipse(head_local(p, 0.0, -0.95 * hr), 2.2, 1.8), "#f3ecd8", line=False)]
    return f


def coat_tails(color, trim):
    def f(s, p, pr):
        dn, nm = _down(p)
        h = p["hip"]
        pts = [add(h, (nm[0] * 9.5, nm[1] * 9.5)), add(h, (-nm[0] * 9, -nm[1] * 9)),
               add(h, (-nm[0] * 10 + dn[0] * 17, -nm[1] * 10 + dn[1] * 17)), add(h, (nm[0] * 12 + dn[0] * 19, nm[1] * 12 + dn[1] * 19))]
        return [Part("coat", poly(pts), color),
                Part("trim", capsule(pts[2], pts[3], 1.2), trim)]
    return f


def sash(color):
    def f(s, p, pr):
        dn, nm = _down(p)
        w = lerp(p["hip"], p["sh"], 0.22)
        r = pr["torso"][0] + 0.6
        return [Part("sash", capsule(add(w, (nm[0] * r, nm[1] * r)), add(w, (-nm[0] * r, -nm[1] * r)), 2.2), color)]
    return f


def skull_face(glow):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("pupil", ellipse(head_local(p, 0.5 * hr, -0.08 * hr), 2.6, 3.0), "#2a2440", shade=False, line=False),
                Part("eye_white", ellipse(head_local(p, 0.55 * hr, -0.05 * hr), 1.1, 1.4), glow, shade=False, line=False),
                Part("mouth", poly(hl(p, pr, [(0.45, 0.45), (1.0, 0.4), (1.0, 0.62), (0.45, 0.66)])), "#2a2440", shade=False, line=False),
                Part("teeth", capsule(head_local(p, 0.5 * hr, 0.53 * hr), head_local(p, 0.95 * hr, 0.5 * hr), 0.5), "#f3ecd8", shade=False, line=False),
                Part("face", ellipse(head_local(p, 0.98 * hr, 0.18 * hr), 1.0, 1.4), "#2a2440", shade=False, line=False)]
    return f


def cowboy_hat(color, band):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("hat", poly(hl(p, pr, [(-1.75, -0.28), (-1.5, -0.5), (1.6, -0.55), (1.95, -0.42), (1.7, -0.25)])), color),
                Part("hat", poly(hl(p, pr, [(-0.85, -0.5), (0.85, -0.55), (0.75, -1.3), (0.2, -1.12), (-0.3, -1.32), (-0.85, -1.15)])), color),
                Part("band", poly(hl(p, pr, [(-0.85, -0.68), (0.82, -0.72), (0.8, -0.56), (-0.85, -0.52)])), band)]
    return f


def mustache(color):
    def f(s, p, pr):
        return [Part("beard", poly(hl(p, pr, [(0.5, 0.3), (1.08, 0.24), (1.15, 0.45), (0.9, 0.48), (0.55, 0.52), (0.3, 0.6)])), color)]
    return f


def bandana(color):
    def f(s, p, pr):
        n = p["neck"]
        return [Part("scarf", capsule(add(n, (-4, 1.5)), add(n, (3, 1.2)), 2.8), color),
                Part("scarf", poly([add(n, (0, 2)), add(n, (5, 2.5)), add(n, (2.5, 7))]), color)]
    return f


def peg_leg(wood):
    def f(s, p, pr):
        # front shin becomes a wooden peg (drawn over the trouser shin)
        k, a = p["kf"], p["af"]
        return [Part("peg", capsule(lerp(k, a, 0.15), (a[0], a[1] + 4.2), 2.4, 1.8), wood)]
    return f


# ---------------------------------------------------------------- specs

SPECS.update({
    "bolt": dict(
        name="Bolt", build=robot,
        c=dict(body="#2ec4b6", panel="#fdf3d8", metal="#a9b6cc", dark="#3d4a63", screen="#13213a", led="#6ff7ff",
               accent="#ffd166", light="#ef476f", tyre="#2b2d42", skin="#2ec4b6", glove="#2ec4b6", shirt="#2ec4b6"),
        hand_tol=16.0, eye_fix=False, colors=48, spots=[((-0.36, -1.55), 2.2, "#ef476f", 11.0)],
        # finish: club resting over the shoulder so the arms never cover the screen face
        pose_fix={"finish": {"hd": (12, -62), "ca": -158, "club_behind": True, "bend": 1}},
        prompt="cute teal caddie robot golfer, rounded teal metal body, cream chest panel, boxy head with dark screen face "
               "and glowing cyan eyes, short antenna with red light, grey metal arms, single rubber wheel instead of legs",
    ),
    "dino": dict(
        name="Tee-Rex", build=humanoid, size=1.0,
        c=dict(skin="#5cc45a", shirt="#5cc45a", pants="#5cc45a", shoe="#3d9a4a", glove="#5cc45a", stripe="#3d9a4a",
               belly="#f6e7b0", plate="#ff9f1c", claw="#fffbe8", mouth="#7a2a3a", eye="#1d1a2b"),
        prop=dict(thigh=(7.0, 5.6), shin=(4.6, 3.6), torso=(10.0, 9.0), upper=(2.4, 2.2), fore=(2.2, 2.0), hand=2.6,
                  head=(10.0, 9.0), pelvis=(10.5, 8.0), shoe=4.0, neck=5.5),
        no_face=True, no_ear=True,
        features={"back": [dino_tail, dino_plates], "torso": [dino_belly], "head": [dino_head]},
        prompt="cute green t-rex dinosaur golfer standing upright, cream belly, orange back spikes, big toothy grin, "
               "tiny arms, thick tail",
    ),
    "wizard": dict(
        name="Fizzwick", build=humanoid, long_sleeve=True,
        c=dict(skin="#f5c9a6", shirt="#6c4bd8", pants="#4a3aa0", shoe="#3a2a70", glove="#f5c9a6", sleeve_long="#6c4bd8",
               hair="#f4f6fb", brow="#e0e4f0"),
        prop=dict(upper=(4.2, 4.6), fore=(4.0, 4.4), torso=(9.0, 9.8)),
        features={"legs": [robe("#6c4bd8", "#ffd166")], "hair": [hair_back("#f4f6fb", -0.3, -0.2), beard("#f4f6fb", 1.7),
                                                                   wizard_hat("#6c4bd8", "#ffd166", "#fff3b0")]},
        prompt="old wizard golfer, long flowing white beard, tall pointy purple wizard hat with gold band and star, "
               "long purple robe with gold trim, wide sleeves",
    ),
    "astronaut": dict(
        name="Nova", build=humanoid, bg=SLATE_BG,
        c=dict(skin="#b07a55", shirt="#f4f6fb", pants="#f4f6fb", shoe="#b9c3d6", glove="#f4f6fb", hair="#2b1d16", brow="#2b1d16"),
        prop=dict(thigh=(5.8, 5.2), shin=(5.0, 4.6), torso=(10.0, 10.5), upper=(4.0, 3.8), fore=(3.8, 3.6), hand=3.8, shoe=4.0,
                  head=(9.4, 9.6)),
        features={"behind_body": [backpack("#b9c3d6")], "torso": [belt("#ff8c42", "#b9c3d6")],
                  "hair": [hair_back("#2b1d16", -0.45, -0.3), helmet_bubble("#f4f6fb", "#2b3a66")]},
        prompt="astronaut woman golfer, white spacesuit with orange accents, round white helmet with open glass front, "
               "dark hair, brown skin, grey backpack, chunky grey boots",
    ),
    "knight": dict(
        name="Sir Putts", build=humanoid, long_sleeve=True,
        c=dict(skin="#c3cbd9", shirt="#c3cbd9", pants="#aab3c4", shoe="#8a93a6", glove="#c3cbd9", sleeve_long="#c3cbd9"),
        prop=dict(thigh=(5.8, 5.2), shin=(5.0, 4.4), torso=(10.0, 10.8), upper=(4.2, 3.8), fore=(3.8, 3.5), hand=3.8, shoe=3.9,
                  head=(10.2, 10.4)),
        no_face=True, no_ear=True,
        features={"back": [cape("#c62f3a")], "torso": [tabard("#3a5bd9", "#ffd166"), belt("#5a4630", "#ffd166")],
                  "hair": [great_helm("#c3cbd9", "#ef476f", "#fff3b0")]},
        prompt="noble armored knight golfer, shining steel plate armor, closed great helm with visor slit and pink plume, "
               "long bright blue tabard with gold emblem worn over the armor, red cape",
    ),
    "pirate": dict(
        name="Cap'n Slice", build=humanoid, long_sleeve=True,
        pose_fix={"finish": {"hd": (14, -62), "ca": -158, "club_behind": True, "bend": 1}},
        c=dict(skin="#eaa87c", shirt="#2b4a8c", pants="#3a3550", shoe="#3a2a24", glove="#eaa87c", sleeve_long="#2b4a8c",
               hair="#d4572a", brow="#a8401c"),
        prop=dict(torso=(10.0, 10.5), pelvis=(9.5, 6.5)),
        features={"torso": [coat_tails("#2b4a8c", "#ffd166"), collar("#2ec4b6"), sash("#e63946")],
                  "hair": [hair_back("#d4572a", -0.4, -0.25), beard("#d4572a", 1.1), tricorn("#262833", "#ffd166")]},
        prompt="jolly pirate captain golfer, black tricorn hat with gold trim and skull, bushy ginger beard, blue long coat "
               "with gold trim, red sash, dark trousers, tall black leather boots",
    ),
    "skeleton": dict(
        name="Rattles", build=humanoid, bg=SLATE_BG,
        c=dict(skin="#f3ecd8", shirt="#3f8f5a", pants="#4a4560", shoe="#2a2440", glove="#f3ecd8", hair="#8a6f5a"),
        prop=dict(thigh=(3.2, 2.6), shin=(2.6, 2.2), torso=(7.0, 8.4), upper=(2.2, 2.0), fore=(2.0, 1.8), hand=3.0, neck=2.2,
                  head=(10.4, 10.8), pelvis=(8.0, 5.6)),
        no_face=True, no_ear=True,
        features={"torso": [collar("#f2c14e")], "head": [skull_face("#7df9ff")]},
        prompt="friendly skeleton golfer, white bone skull with glowing cyan eye sockets, bony arms and legs, green golf vest "
               "with yellow trim, dark purple trousers",
    ),
    "cowboy": dict(
        name="Dusty", build=humanoid,
        c=dict(skin="#e7a97e", shirt="#e9b949", pants="#3e6bb0", shoe="#6b3e22", glove="#8b5a2b", hair="#6b3e22", brow="#6b3e22"),
        prop=dict(torso=(8.4, 9.6)),
        features={"torso": [vest("#8b5a2b", low=0.25), belt("#5a3418", "#ffd166")], "front": [],
                  "hair": [hair_back("#6b3e22", -0.4, -0.3), mustache("#6b3e22"), bandana("#e63946"), cowboy_hat("#a8743f", "#5a3418")]},
        prompt="lanky cowboy golfer, wide brimmed brown cowboy hat, bushy brown mustache, red bandana, yellow shirt, "
               "brown leather vest, blue jeans, cowboy boots",
    ),
})
