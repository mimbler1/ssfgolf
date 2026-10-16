"""v4 roster specs for the converted legacy characters (briefs from character_defs.gd).
Registered into g4_chars.SPECS (imported at the end of g4_chars)."""
from __future__ import annotations

import math

from g4_chars import (SLATE_BG, SPECS, Part, _halfplane, add, beard, belt, capsule, cap, chain, collar, dk, ellipse,
                      hair_cap, head_local, hl, humanoid, lerp, poly)


# ---------------------------------------------------------------- feature helpers

def beanie(color, cuff=None):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = [Part("hat", ellipse(head_local(p, -0.05 * hr, -0.42 * hr), hr * 1.1, hr * 0.92, math.radians(p.get("tilt", 0))) & _halfplane(p, -0.3 * hr), color)]
        out.append(Part("hat", poly(hl(p, pr, [(-1.15, -0.5), (1.08, -0.5), (1.08, -0.22), (-1.15, -0.22)])), cuff or dk(color, 0.85)))
        out.append(Part("hat", ellipse(head_local(p, -0.15 * hr, -1.38 * hr), 2.6, 2.4), cuff or dk(color, 0.85)))
        return out
    return f


def sunhat(color, band):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = [Part("hat", poly(hl(p, pr, [(-1.7, -0.42), (1.75, -0.48), (1.8, -0.3), (-1.75, -0.22)])), color)]
        out.append(Part("hat", ellipse(head_local(p, 0.0, -0.62 * hr), hr * 0.9, hr * 0.62, math.radians(p.get("tilt", 0))) & _halfplane(p, -0.38 * hr), color))
        out.append(Part("band", poly(hl(p, pr, [(-0.88, -0.62), (0.88, -0.62), (0.88, -0.45), (-0.88, -0.45)])), band))
        return out
    return f


def bun(color):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("hair", hair_cap(p, pr, -0.35, -0.25), color),
                Part("hair", ellipse(head_local(p, -0.95 * hr, -0.75 * hr), 4.0, 3.8), color)]
    return f


def glasses(color):
    def f(s, p, pr):
        ex, ey = s.get("eye", (0.45, -0.05))
        hr = pr["head"][0]
        c0 = head_local(p, ex * hr + 0.6, ey * hr + 0.2)
        ring = ellipse(c0, 3.2, 3.0) & ~ellipse(c0, 2.1, 1.9)
        arm = capsule(head_local(p, (ex - 0.25) * hr, ey * hr - 0.4), head_local(p, -0.2 * hr, ey * hr - 0.2), 0.6)
        return [Part("glasses", ring | arm, color, shade=False, line=False)]
    return f


def hair_back(color, top=-0.4, back=-0.18):
    def f(s, p, pr):
        return [Part("hair", hair_cap(p, pr, top, back), color)]
    return f


def scarf(color, stripe):
    def f(s, p, pr):
        n = p["neck"]
        tail0 = add(n, (-3, 2))
        return [Part("scarf", capsule(add(n, (-5, 1.5)), add(n, (3, 1.0)), 3.4), color),
                Part("scarf", chain([tail0, add(tail0, (-4, 5)), add(tail0, (-5, 11))], [2.6, 2.4, 2.2]), stripe)]
    return f


def horns_small(color):
    def f(s, p, pr):
        return [Part("horn", poly(hl(p, pr, [(-0.4, -0.85), (-0.55, -1.45), (-0.1, -0.95)])), color),
                Part("horn", poly(hl(p, pr, [(0.25, -0.92), (0.45, -1.5), (0.6, -0.85)])), color)]
    return f


def face_patch(color):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("face", ellipse(head_local(p, 0.42 * hr, 0.12 * hr), hr * 0.62, hr * 0.62), color)]
    return f


def stripe_shirt(color, frac=0.62):
    def f(s, p, pr):
        a = lerp(p["hip"], p["sh"], frac)
        r = pr["torso"][1] + 0.4
        ang = math.atan2(p["sh"][1] - p["hip"][1], p["sh"][0] - p["hip"][0]) + math.pi / 2
        dx, dy = math.cos(ang), math.sin(ang)
        return [Part("stripe", capsule(add(a, (dy * r, -dx * r)), add(a, (-dy * r, dx * r)), 1.6), color)]
    return f


# ---------------------------------------------------------------- specs

SPECS.update({
    "stickman": dict(
        name="Stickman", build=humanoid, bg=SLATE_BG,
        c=dict(skin="#f6f6fa", shirt="#2b2d42", pants="#2b2d42", shoe="#2b2d42", glove="#f6f6fa", hair="#2b2d42", eye="#1a1a28"),
        prop=dict(thigh=(2.2, 2.0), shin=(2.0, 1.9), torso=(2.4, 2.4), upper=(1.9, 1.8), fore=(1.8, 1.7), hand=3.0,
                  neck=1.8, head=(11.5, 11.5), pelvis=(2.6, 2.4), shoe=2.6),
        no_ear=True, eye=(0.36, -0.2), eye_px=(2, 4), eye_white=False,
        features={},
        prompt="classic stick figure man, big round white head with simple cartoon face, thick black stick arms and legs, "
               "thin black stick body, minimalist",
        portrait_prompt="classic stick figure man with a big round white head and simple cartoon face, thin black stick neck and shoulders",
    ),
    "ace": dict(
        name="Ace", build=humanoid, size=1.03,
        c=dict(skin="#f1b98c", shirt="#1f4e8c", pants="#d9c8a2", shoe="#6b3f26", glove="#f4f4f8", hair="#5b3a29", brow="#4a2c1e"),
        prop=dict(torso=(8.2, 9.6)),
        features={"torso": [collar("#f4f4f8"), belt("#4a2e1d", "#d8d8e0")],
                  "hair": [cap("#1f4e8c", 1.0, back_hair="#5b3a29")]},
        prompt="tall confident pro tour golfer man, navy blue baseball cap, short brown hair, navy polo shirt with white collar, "
               "khaki trousers, brown leather belt, brown golf shoes, white golf glove",
    ),
    "nana": dict(
        name="Nana Birdie", build=humanoid, size=0.94,
        c=dict(skin="#f6d2b8", shirt="#ff8fab", pants="#9d8df1", shoe="#7a4b3a", glove="#fff6f0", hair="#e6e3ef", brow="#b8b4c8"),
        prop=dict(torso=(8.8, 9.4), head=(10.4, 10.6)),
        features={"torso": [collar("#fff6f0")], "hair": [bun("#e6e3ef"), sunhat("#f2d27a", "#ef476f"), glasses("#8a5a9a")]},
        prompt="cheerful grandma golfer, old lady, white hair in a bun, round purple glasses, straw sun hat with pink ribbon, "
               "pink cardigan, lavender trousers, brown shoes",
    ),
    "brick": dict(
        name="Brick", build=humanoid, size=1.04,
        c=dict(skin="#e9a87c", shirt="#c62f3a", pants="#3e5f9e", shoe="#6b4426", glove="#e9a87c", hair="#c8562a", brow="#a8401c"),
        prop=dict(thigh=(6.0, 5.2), shin=(5.0, 4.3), torso=(10.2, 11.5), upper=(4.3, 3.8), fore=(3.9, 3.5), hand=3.8,
                  head=(10.2, 10.4), pelvis=(9.6, 6.6), shoe=3.8),
        features={"torso": [belt("#4a2e1d")], "hair": [beard("#c8562a", 0.5), beanie("#2a9d8f", "#1f7368")]},
        prompt="burly lumberjack golfer, red and black plaid flannel shirt with rolled sleeves, short ginger beard, "
               "teal knit beanie, blue jeans, brown work boots",
    ),
    "skipper": dict(
        name="Skipper", build=humanoid, size=0.88, short_pants=True,
        c=dict(skin="#c98a5e", shirt="#ffd166", pants="#2f6fb5", shoe="#ef476f", glove="#f4f4f8", hair="#2b1d16", brow="#2b1d16",
               sock="#f4f4f8"),
        prop=dict(head=(11.6, 11.8), torso=(8.0, 8.8)),
        features={"torso": [stripe_shirt("#ef476f")], "hair": [cap("#4361ee", 1.1, back_hair="#2b1d16")]},
        prompt="energetic ten year old kid golfer boy, blue baseball cap, short black curly hair, yellow t-shirt with pink stripe, "
               "blue shorts, white socks, pink sneakers",
    ),
    "frost": dict(
        name="Frost", build=humanoid, bg=SLATE_BG,
        c=dict(skin="#9fb7d6", shirt="#eef6ff", pants="#eef6ff", shoe="#9fb7d6", glove="#9fb7d6", hair="#eef6ff", brow="#dde9f8"),
        prop=dict(thigh=(6.4, 5.8), shin=(5.8, 5.2), torso=(12.0, 12.5), upper=(4.8, 4.4), fore=(4.4, 4.0), hand=4.4,
                  head=(11.0, 11.0), pelvis=(11.5, 7.5), shoe=4.2, neck=4.5),
        no_ear=True,
        features={"head": [face_patch("#9fb7d6")], "hair": [hair_back("#eef6ff", -0.5, -0.05)],
                  "front": [scarf("#ef476f", "#ffd166")]},
        prompt="friendly gentle yeti golfer, shaggy white fur, round pale blue face, no horns, pink and yellow striped scarf, "
               "big bare blue feet",
    ),
})
