"""v4 keyframe poses (art px relative to the pivot, +x = facing side, y up negative).

Keys: hip, sh (near shoulder), sh_f (far shoulder), neck, head (centre), tilt (deg, + = looking
down), kb/ab/tb (back knee/ankle/toe), kf/af/tf (front), hd (hands on the grip), bend/bend_f
(elbow bend side: +1 = elbow out in front), ca (club angle deg, 0 = +x, 90 = down),
club_behind (draw club behind body/head).

Elbows are solved by two-bone IK from shoulder and hand so arm length never changes.
"""
from __future__ import annotations

import math

UPPER, FORE = 12.0, 11.5     # arm segment lengths (art px)
CLUB = 39.0                  # grip -> club head length (art px)


def ik(sh, hd, bend: float, up: float = UPPER, lo: float = FORE):
    dx, dy = hd[0] - sh[0], hd[1] - sh[1]
    d = max(min(math.hypot(dx, dy), up + lo - 0.01), abs(up - lo) + 0.01)
    a = (up * up - lo * lo + d * d) / (2 * d)
    h = math.sqrt(max(up * up - a * a, 0.0))
    ux, uy = dx / max(math.hypot(dx, dy), 1e-6), dy / max(math.hypot(dx, dy), 1e-6)
    mx, my = sh[0] + ux * a, sh[1] + uy * a
    # perpendicular (rotate +90 in screen coords); bend picks the side
    return (mx - uy * h * bend, my + ux * h * bend)


def _arm_reach(sh, hd, up=UPPER, lo=FORE):
    """Pull the hand in so it is reachable (keeps poses honest if a key is edited)."""
    dx, dy = hd[0] - sh[0], hd[1] - sh[1]
    d = math.hypot(dx, dy)
    m = up + lo - 0.6
    if d <= m:
        return hd
    return (sh[0] + dx / d * m, sh[1] + dy / d * m)


BASE = dict(hip=(-5, -40), sh=(5, -60), sh_f=(2, -60), neck=(8, -63), head=(13, -72), tilt=16,
            kb=(-5, -22), ab=(-9, -5), tb=(-2, -2), kf=(4, -22), af=(7, -5), tf=(14, -2),
            hd=(13, -37), bend=1, bend_f=1, ca=63, club_behind=False)


def P(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


POSES: dict[str, dict] = {
    "address": P(),
    "takeaway": P(sh=(4, -60), sh_f=(1, -60), neck=(7, -63), head=(12, -72), hd=(4, -38), ca=158, kf=(4, -22)),
    "halfback": P(hip=(-6, -40), sh=(2, -61), sh_f=(-1, -61), neck=(6, -64), head=(11, -72), tilt=14,
                  hd=(-13, -50), bend=-1, bend_f=-1, ca=-96, kf=(2, -22), kb=(-6, -22)),
    "top": P(hip=(-6, -40), sh=(1, -61), sh_f=(-2, -61), neck=(6, -64), head=(11, -72), tilt=12,
             hd=(-6, -71), bend=-1, bend_f=-1, ca=-28, club_behind=True, kf=(1, -22), kb=(-6, -22)),
    "down": P(hip=(-3, -40), sh=(3, -60), sh_f=(0, -60), neck=(7, -63), head=(12, -72), tilt=14,
              hd=(-4, -45), bend=-1, bend_f=-1, ca=-128, kf=(5, -22)),
    "impact": P(hip=(-2, -40), sh=(6, -60), sh_f=(3, -60), neck=(9, -63), head=(13, -72), tilt=16,
                hd=(15, -37), ca=64, kf=(6, -23), kb=(-3, -21), ab=(-8, -6), tb=(-2, -2)),
    "follow": P(hip=(0, -41), sh=(8, -61), sh_f=(5, -61), neck=(10, -64), head=(14, -72), tilt=4,
                hd=(24, -54), bend=1, ca=-72, kf=(6, -23), kb=(-1, -21), ab=(-6, -8), tb=(-1, -2)),
    "finish": P(hip=(1, -42), sh=(5, -63), sh_f=(2, -63), neck=(7, -66), head=(11, -74), tilt=-6,
                hd=(3, -76), bend=1, bend_f=1, ca=166, club_behind=True,
                kf=(6, -23), af=(7, -5), kb=(3, -21), ab=(-3, -8), tb=(2, -2)),
}
# victory: upright "Yes!" - near fist pumps at the chest, club raised high in the far hand behind
VIC = dict(hip=(-2, -41), sh=(2, -62), sh_f=(-1, -62), neck=(4, -65), head=(7, -74), tilt=-8,
           kb=(-6, -22), ab=(-9, -5), tb=(-3, -2), kf=(5, -22), af=(8, -5), tf=(14, -2), bend=1, bend_f=1,
           club_far=True, club_behind=True)
POSES.update({
    "vic_0": P(**{**VIC, "hip": (-2, -39), "sh": (3, -59), "sh_f": (0, -59), "neck": (5, -62), "head": (8, -71), "tilt": 6,
                  "kb": (-7, -21), "kf": (6, -20), "hd": (12, -44), "hd_f": (-9, -48), "ca": -118}),
    "vic_1": P(**{**VIC, "hd": (16, -56), "hd_f": (-7, -83), "ca": -121}),
    "vic_2": P(**{**VIC, "hip": (-2, -42), "sh": (2, -63), "sh_f": (-1, -63), "neck": (4, -66), "head": (7, -75),
                  "hd": (17, -60), "hd_f": (-8, -85), "ca": -126, "ab": (-8, -7), "tb": (-3, -2)}),
    "vic_3": P(**{**VIC, "hd": (15, -53), "hd_f": (-6, -81), "ca": -117}),
})
# neutral stand (portrait source only): upright, arms relaxed at the sides, no club
POSES["stand"] = P(**{**VIC, "club_far": False, "club_behind": False, "tilt": -2, "hd": (6, -40), "hd_f": (-6, -41),
                      "bend": -1, "bend_f": 1, "ca": 90, "empty_hands": True})
VICTORY = ["vic_0", "vic_1", "vic_2", "vic_3"]

SWING = ["address", "takeaway", "halfback", "top", "down", "impact", "follow", "finish"]
CONTACT = 5


def solved(name: str, fix: dict | None = None) -> dict:
    p = dict(POSES[name])
    p.update(fix or {})
    p["hd"] = _arm_reach(p["sh"], p["hd"])
    p["el"] = ik(p["sh"], p["hd"], p["bend"])
    if "hd_f" in p:
        p["hd_f"] = _arm_reach(p["sh_f"], p["hd_f"])
    p["el_f"] = ik(p["sh_f"], p.get("hd_f", p["hd"]), p["bend_f"])
    a = math.radians(p["ca"])
    p["grip"] = p["hd_f"] if p.get("club_far") else p["hd"]
    p["ch"] = (p["grip"][0] + CLUB * math.cos(a), p["grip"][1] + CLUB * math.sin(a))
    return p
