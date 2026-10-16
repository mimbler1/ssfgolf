"""v4 character designs: guide builders + generation prompts.

Each spec is the brief for one roster id (names, colours and taglines come from
client/scripts/render/toon/character_defs.gd). `build(spec, pose)` returns the parts list that
g4_rig.render() turns into a shaded guide frame.
"""
from __future__ import annotations

import math

from g4_rig import Part, capsule, chain, ellipse, head_local, poly

DARKEN = 0.80


def dk(hexc: str, f: float = DARKEN) -> tuple[int, int, int]:
    h = hexc.lstrip("#")
    return tuple(int(int(h[i:i + 2], 16) * f) for i in (0, 2, 4))


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


# ---------------------------------------------------------------- generic humanoid

def humanoid(s: dict, p: dict) -> list[Part]:
    c = s["c"]
    pr = dict(thigh=(5.2, 4.4), shin=(4.2, 3.4), torso=(8.5, 9.5), upper=(3.6, 3.2), fore=(3.1, 2.8),
              hand=3.3, neck=3.0, head=(10.0, 10.5), shoe=3.3, pelvis=(8.5, 6.0))
    pr.update(s.get("prop", {}))
    k = float(s.get("size", 1.0))
    pr = {n: (tuple(x * k for x in v) if isinstance(v, tuple) else v * k) for n, v in pr.items()}
    parts: list[Part] = []
    feats = s.get("features", {})

    def run(layer):
        for f in feats.get(layer, []):
            parts.extend(f(s, p, pr))

    def club():
        if p.get("no_club") or p.get("empty_hands"):
            return
        hd, ch = p["grip"], p["ch"]
        parts.append(Part("shaft", capsule(hd, ch, 0.7), "#c9d1de", shade=False, line=False))
        a = math.atan2(ch[1] - hd[1], ch[0] - hd[0])
        tip = (ch[0] + 3.5 * math.cos(a), ch[1] + 3.5 * math.sin(a))
        parts.append(Part("clubhead", capsule(ch, tip, 2.0, 2.3), "#aab4c4"))
        parts.append(Part("grip", capsule(hd, lerp(hd, ch, 0.22), 1.1), "#343046", shade=False))

    def leg(k, a, t, far):
        col = c["pants"] if not far else dk(c["pants"])
        shoe = c["shoe"] if not far else dk(c["shoe"])
        if s.get("short_pants"):
            skin = c["skin"] if not far else dk(c["skin"])
            sock = c.get("sock", "#f4f4f8") if not far else dk(c.get("sock", "#f4f4f8"))
            parts.append(Part("thigh", capsule(p["hip"], p[k], *pr["thigh"]), skin))
            parts.append(Part("shin", capsule(p[k], p[a], *pr["shin"]), skin))
            parts.append(Part("shin", capsule(lerp(p[k], p[a], s.get("sock_from", 0.62)), p[a], pr["shin"][1] * 1.08), sock))
            parts.append(Part("thigh", capsule(p["hip"], lerp(p["hip"], p[k], s.get("shorts_len", 0.62)), pr["thigh"][0] * 1.12, pr["thigh"][1] * 1.15), col))
        else:
            parts.append(Part("thigh", capsule(p["hip"], p[k], *pr["thigh"]), col))
            parts.append(Part("shin", capsule(p[k], p[a], *pr["shin"]), col))
        if s.get("peg") and not far:
            return
        heel = (p[a][0] - 2.5, p[a][1] + 2.2)
        parts.append(Part("shoe", capsule(heel, (p[t][0] - 1.0, p[t][1] - 0.6), pr["shoe"], pr["shoe"] * 0.85) & _above(-0.6), shoe))

    def arm(sh, el, far):
        sleeve = c["shirt"] if not far else dk(c["shirt"])
        skin = c["skin"] if not far else dk(c["skin"])
        glove = c.get("glove", c["skin"])
        hand = p["hd"] if not far else p.get("hd_f", p["hd"])
        parts.append(Part("fore", capsule(p[el], hand, *pr["fore"]), (c.get("sleeve_long", sleeve) if not far else dk(c.get("sleeve_long", c["shirt"]))) if s.get("long_sleeve") else skin))
        parts.append(Part("upper", capsule(p[sh], p[el], *pr["upper"]), sleeve))
        holds = ((not far) != bool(p.get("club_far"))) and not p.get("empty_hands")
        bare = c.get("bare_hand", c["skin"])
        if not far:
            parts.append(Part("hand" if holds else "fist", ellipse(hand, pr["hand"], pr["hand"] * 0.9), glove if holds else bare))
        elif "hd_f" in p:
            parts.append(Part("hand" if holds else "fist", ellipse(hand, pr["hand"], pr["hand"] * 0.95), dk(glove if isinstance(glove, str) else "#ffffff") if holds else dk(bare)))

    if p["club_behind"]:
        club()
    run("back")
    arm("sh_f", "el_f", True)
    leg("kb", "ab", "tb", True)
    run("behind_body")
    # pelvis + torso
    parts.append(Part("pelvis", ellipse(p["hip"], *pr["pelvis"],
                                        math.atan2(p["sh"][1] - p["hip"][1], p["sh"][0] - p["hip"][0]) + math.pi / 2), c["pants"]))
    waist = lerp(p["hip"], p["sh"], 0.18)
    chest = add(p["sh"], (-2.0, 1.5))
    parts.append(Part("torso", capsule(waist, chest, *pr["torso"]), c["shirt"]))
    run("torso")
    leg("kf", "af", "tf", False)
    run("legs")
    if not p["club_behind"]:
        club()
    parts.append(Part("neck", capsule(p["neck"], head_local(p, -1, 4), pr["neck"]), c["skin"]))
    run("behind_head")
    hx, hy = pr["head"]
    parts.append(Part("head", ellipse(p["head"], hx, hy, math.radians(p.get("tilt", 0))), c["skin"]))
    run("head")
    face(s, p, pr, parts)
    run("hair")
    arm("sh", "el", False)
    run("front")
    return parts


def _above(y_rel: float):
    from g4_rig import FY, PIV
    return FY <= PIV[1] + y_rel


def face(s, p, pr, parts):
    """Eye, brow, nose and mouth in head-local coords (side view, facing +x)."""
    c = s["c"]
    hr = pr["head"][0]
    if s.get("no_face"):
        return
    ex, ey = s.get("eye", (0.45, -0.05))
    eye = head_local(p, ex * hr, ey * hr)
    parts.append(Part("eye_white", ellipse(eye, 1.6, 2.3), "#f8f8ff", shade=False, line=False))
    parts.append(Part("pupil", ellipse(add(eye, (0.7, 0.3)), 0.9, 1.6), c.get("eye", "#2a2238"), shade=False, line=False))
    if c.get("brow"):
        b0, b1 = head_local(p, (ex - 0.2) * hr, (ey - 0.32) * hr), head_local(p, (ex + 0.22) * hr, (ey - 0.36) * hr)
        parts.append(Part("brow", capsule(b0, b1, 0.8), c["brow"], shade=False, line=False))
    m0, m1 = head_local(p, 0.55 * hr, 0.5 * hr), head_local(p, 0.82 * hr, 0.45 * hr)
    if not s.get("no_mouth"):
        parts.append(Part("mouth", capsule(m0, m1, 0.6), dk(c["skin"], 0.55), shade=False, line=False))
    ear = head_local(p, -0.12 * hr, 0.12 * hr)
    if not s.get("no_ear"):
        parts.append(Part("ear", ellipse(ear, 2.0, 2.6), dk(c["skin"], 0.92), line=False))


# ---------------------------------------------------------------- feature helpers

def cap(color, brim=1.0, back_hair=None):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = []
        if back_hair:
            out.append(Part("hair", poly([head_local(p, x * hr, y * hr) for x, y in
                                          [(-0.2, -0.6), (-1.15, -0.2), (-1.35, 0.25), (-1.0, 0.25), (-1.2, 0.6), (-0.7, 0.55), (-0.45, 0.2)]]), back_hair))
        dome = ellipse(head_local(p, -0.05 * hr, -0.38 * hr), hr * 1.05, hr * 0.72, math.radians(p.get("tilt", 0))) & \
            _halfplane(p, 0.05 * hr)
        out.append(Part("cap", dome, color))
        b = [head_local(p, x * hr, y * hr) for x, y in [(0.3, -0.32), (1.0 + 0.5 * brim, -0.18), (1.0 + 0.55 * brim, -0.02), (0.3, -0.12)]]
        out.append(Part("brim", poly(b), dk(color, 0.88)))
        return out
    return f


def _local(p):
    from g4_rig import FX, FY, PIV
    hx, hy = p["head"]
    t = math.radians(p.get("tilt", 0))
    x, y = FX - (PIV[0] + hx), FY - (PIV[1] + hy)
    return x * math.cos(t) + y * math.sin(t), -x * math.sin(t) + y * math.cos(t)


def hair_cap(p, pr, top=-0.38, back=-0.15, color=None):
    """Hair mass: the crown above `top` and the back of the head behind `back` (head-local
    units of the head radius), so the face and eye stay clear."""
    hr = pr["head"][0]
    lx, ly = _local(p)
    shell = ellipse(head_local(p, -0.08 * hr, -0.1 * hr), hr * 1.12, hr * 1.1, math.radians(p.get("tilt", 0)))
    return shell & ((ly <= top * hr) | (lx <= back * hr)) & (ly <= 0.55 * hr)


def _halfplane(p, y_cut):
    """Fine-grid mask of head-local y <= y_cut (top part of the head)."""
    from g4_rig import FX, FY, PIV
    hx, hy = p["head"]
    t = math.radians(p.get("tilt", 0))
    x, y = FX - (PIV[0] + hx), FY - (PIV[1] + hy)
    ly = -x * math.sin(t) + y * math.cos(t)
    return ly <= y_cut


def collar(color):
    def f(s, p, pr):
        a = lerp(p["sh"], p["neck"], 0.2)
        return [Part("collar", capsule(add(a, (-3, 0)), add(a, (2, 0.5)), 2.0), color)]
    return f


def hairpoly(color, pts):
    def f(s, p, pr):
        hr = pr["head"][0]
        return [Part("hair", poly([head_local(p, x * hr, y * hr) for x, y in pts]), color)]
    return f


# ---------------------------------------------------------------- roster specs

SPECS: dict[str, dict] = {
    "rex": dict(
        name="Rex", build=humanoid,
        c=dict(skin="#f2b98e", shirt="#ee7a2a", pants="#2f6b4c", shoe="#7a3f22", glove="#f4f4f8", hair="#e0682a", brow="#b4471c"),
        features={"torso": [collar("#f4f4f8")],
                  "hair": [cap("#ee7a2a", 1.0, back_hair="#e0682a")]},
        prompt="young golfer boy, orange baseball cap, spiky orange hair, orange polo shirt with white collar, "
               "dark green trousers, brown shoes, white golf glove",
    ),
}


# ---------------------------------------------------------------- more feature helpers

def hl(p, pr, pts):
    hr = pr["head"][0]
    return [head_local(p, x * hr, y * hr) for x, y in pts]


def ponytail(color, length=1.0):
    def f(s, p, pr):
        hr = pr["head"][0]
        sway = -p.get("tilt", 0) * 0.04
        base = head_local(p, -0.75 * hr, -0.45 * hr)
        pts = [base, add(base, (-5 * length, 3 + sway)), add(base, (-7 * length, 10)), add(base, (-6 * length, 17 * length))]
        return [Part("hair", chain(pts, [3.6, 3.4, 3.0, 1.6]), color)]
    return f


def visor(color, hair):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = [Part("hair", hair_cap(p, pr, -0.45, -0.2), hair)]
        out.append(Part("cap", poly(hl(p, pr, [(-1.05, -0.7), (0.62, -0.86), (0.68, -0.45), (-1.05, -0.36)])), color))
        out.append(Part("brim", poly(hl(p, pr, [(0.4, -0.8), (1.7, -0.62), (1.72, -0.42), (0.4, -0.45)])), dk(color, 0.93)))
        return out
    return f


def skirt(color, length=13.0, flare=4.0):
    def f(s, p, pr):
        h = p["hip"]
        a = math.atan2(p["sh"][1] - h[1], p["sh"][0] - h[0]) + math.pi / 2   # body "down" direction
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        top = add(h, (-dx * 3, -dy * 3))
        w0, w1 = 8.5, 8.5 + flare
        pts = [add(top, (nx * w0, ny * w0)), add(top, (-nx * w0, -ny * w0)),
               add(top, (-nx * w1 + dx * length, -ny * w1 + dy * length)), add(top, (nx * w1 + dx * length, ny * w1 + dy * length))]
        return [Part("skirt", poly(pts), color)]
    return f


def beard(color, size=1.0):
    def f(s, p, pr):
        return [Part("beard", poly(hl(p, pr, [(-0.25, 0.05), (0.55, 0.12), (1.0, 0.25), (1.02, 0.6), (0.7, 1.05 + 0.4 * size),
                                               (0.2, 1.15 + 0.45 * size), (-0.2, 0.85 + 0.2 * size), (-0.35, 0.4)])), color),
                Part("beard", poly(hl(p, pr, [(0.45, 0.28), (1.08, 0.2), (1.12, 0.38), (0.5, 0.45)])), dk(color, 1.08))]
    return f


def helmet(color, horn=None, rim=None):
    def f(s, p, pr):
        hr = pr["head"][0]
        out = []
        if horn:
            out.append(Part("horn", poly(hl(p, pr, [(-0.55, -0.55), (-1.25, -1.05), (-1.55, -1.75), (-1.0, -1.25), (-0.3, -0.9)])), horn))
        out.append(Part("helmet", ellipse(head_local(p, -0.05 * hr, -0.4 * hr), hr * 1.12, hr * 0.9, math.radians(p.get("tilt", 0))) & _halfplane(p, -0.36 * hr), color))
        out.append(Part("helmet", poly(hl(p, pr, [(-1.18, -0.5), (1.12, -0.5), (1.12, -0.3), (-1.18, -0.3)])), rim or dk(color, 0.85)))
        if horn:
            out.append(Part("horn", poly(hl(p, pr, [(0.45, -0.6), (1.1, -1.2), (1.2, -1.9), (0.75, -1.25), (0.15, -0.95)])), horn))
        return out
    return f


def vest(color, open_front=True, low=0.2):
    def f(s, p, pr):
        waist = lerp(p["hip"], p["sh"], low)
        chest = add(p["sh"], (-2.5, 1.5))
        r0, r1 = pr["torso"]
        m = capsule(waist, chest, r0 + 0.8, r1 + 1.0)
        if open_front:
            m &= ~capsule(add(waist, (r0 * 0.45, 0)), add(chest, (r1 * 0.5, 0)), r0 * 0.55)
        return [Part("vest", m, color)]
    return f


def belt(color, buckle="#e8c45a"):
    def f(s, p, pr):
        w = lerp(p["hip"], p["sh"], 0.2)
        a = math.atan2(p["sh"][1] - p["hip"][1], p["sh"][0] - p["hip"][0]) + math.pi / 2
        dx, dy = math.cos(a), math.sin(a)
        r = pr["torso"][0] + 0.5
        return [Part("belt", capsule(add(w, (dy * r, -dx * r)), add(w, (-dy * r, dx * r)), 1.4), color),
                Part("buckle", ellipse(add(w, (-dy * (r - 1.5), dx * (r - 1.5))), 1.5, 1.6), buckle, line=False)]
    return f


SPECS.update({
    "mira": dict(
        name="Mira", build=humanoid, short_pants=True, sock_from=0.3, shorts_len=0.3,
        c=dict(skin="#f2c4a0", shirt="#f6c83a", pants="#28306a", shoe="#f2f2f6", glove="#f4f4f8", hair="#8a4cc0", brow="#5a2a80",
               sock="#f6f6fa"),
        prop=dict(thigh=(4.4, 3.8), shin=(3.6, 2.9), torso=(7.2, 8.4), upper=(3.1, 2.8), fore=(2.7, 2.4), head=(9.8, 10.3)),
        features={"back": [ponytail("#8a4cc0")], "torso": [skirt("#28306a", 9.0, 4.5), collar("#f4f4f8")],
                  "hair": [visor("#f8f8fc", "#8a4cc0")]},
        prompt="slim sporty girl golfer, bright white sun visor, long purple ponytail, yellow polo shirt, short navy pleated skirt, "
               "white knee socks, white sneakers, white golf glove",
    ),
    "bjorn": dict(
        name="Bjorn", build=humanoid,
        c=dict(skin="#e8b08c", shirt="#4c7c3e", pants="#5e4a3a", shoe="#4e3420", glove="#8a6040", hair="#cc5528", brow="#a8401c"),
        prop=dict(thigh=(6.4, 5.4), shin=(5.2, 4.4), torso=(10.5, 12.0), upper=(4.4, 3.9), fore=(3.9, 3.5), hand=3.8,
                  head=(10.4, 10.6), pelvis=(10.0, 7.0), shoe=3.9),
        features={"torso": [vest("#9a7a52", low=0.3), belt("#3a2618")],
                  "hair": [beard("#cc5528", 1.0), helmet("#a6aebb", horn="#efe6cf")]},
        prompt="stocky broad viking golfer, big bushy red beard, round steel helmet with two small horns, brown fur vest over green long sleeved tunic, "
               "brown trousers, leather boots",
    ),
})


# ---------------------------------------------------------------- per-character pose + backdrop

LIGHT_BG = (236, 236, 240)
SLATE_BG = (112, 122, 146)


def bg_of(cid: str) -> tuple[int, int, int]:
    return tuple(SPECS[cid].get("bg", LIGHT_BG))


def bg_word(cid: str) -> str:
    return "plain flat light grey background" if bg_of(cid) == LIGHT_BG else "plain flat dark slate blue background"


def pose_for(cid: str, name: str) -> dict:
    """Solved pose for a character: shared keyframe, per-character fixes, then body size
    (scaled about the pivot, so feet stay planted and the club keeps its lie)."""
    import g4_poses
    s = SPECS[cid]
    p = g4_poses.solved(name, s.get("pose_fix", {}).get(name))
    k = float(s.get("size", 1.0))
    if k != 1.0:
        for key, v in list(p.items()):
            if isinstance(v, tuple) and len(v) == 2:
                p[key] = (v[0] * k, v[1] * k)
    return p


import g4_roster  # noqa: E402,F401  (registers the legacy roster specs)
import g4_roster2  # noqa: E402,F401
