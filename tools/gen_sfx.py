"""Procedurally synthesises every original sound effect used by the game.

Pure standard library (no numpy). Output: client/assets/audio/sfx/*.wav (44.1 kHz, 16-bit mono).
Run from the repo root:  python tools/gen_sfx.py
Re-running is deterministic (fixed random seed), so the WAVs can be regenerated at any time.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "client", "assets", "audio", "sfx")
rng = random.Random(1337)


def silence(sec):
    return [0.0] * int(sec * SR)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def delay(track, sec):
    return silence(sec) + track


def gain(track, g):
    return [v * g for v in track]


def env(n, attack, decay, curve=4.0):
    """Attack (s) then exponential-ish decay over the remaining samples."""
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append((1.0 - t) ** curve)
    return out


def tone(freq_fn, sec, shape="sine", attack=0.003, curve=4.0, vibrato=0.0, vib_rate=6.0):
    n = int(sec * SR)
    e = env(n, attack, sec, curve)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq_fn(t / sec) if callable(freq_fn) else freq_fn
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase += 2 * math.pi * f / SR
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(phase))
        elif shape == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        elif shape == "soft":  # sine with a touch of 2nd/3rd harmonic
            v = math.sin(phase) + 0.25 * math.sin(2 * phase) + 0.1 * math.sin(3 * phase)
        else:
            v = math.sin(phase)
        out.append(v * e[i])
    return out


def noise(sec, attack=0.002, curve=3.0, lp=None, hp=None, lp_end=None):
    n = int(sec * SR)
    e = env(n, attack, sec, curve)
    out = []
    y = 0.0
    hy = 0.0
    px = 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        if lp is not None:
            cut = lp if lp_end is None else lp + (lp_end - lp) * (i / n)
            a = 1 - math.exp(-2 * math.pi * cut / SR)
            y += a * (x - y)
            x = y
        if hp is not None:
            a = math.exp(-2 * math.pi * hp / SR)
            hy = a * (hy + x - px)
            px = x
            x = hy
        out.append(x * e[i])
    return out


def sweep(f0, f1, curve=1.0):
    return lambda u: f0 + (f1 - f0) * (u ** curve)


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = names[name[0]]
    sharp = 1 if "#" in name else 0
    octave = int(name[-1])
    return 440.0 * 2 ** ((base + sharp + (octave - 4) * 12) / 12.0)


def chime(freq, sec, bright=0.4):
    return mix(tone(freq, sec, "sine", 0.002, 3.0), gain(tone(freq * 2.0, sec * 0.6, "sine", 0.002, 4.0), bright),
               gain(tone(freq * 3.01, sec * 0.35, "sine", 0.002, 5.0), bright * 0.4))


def lowpass(track, cut, passes=2):
    """Gentle one-pole low-pass (applied `passes` times) to round off harsh transients."""
    a = 1 - math.exp(-2 * math.pi * cut / SR)
    for _ in range(passes):
        y = 0.0
        out = []
        for v in track:
            y += a * (v - y)
            out.append(y)
        track = out
    return track


def marimba(freq, sec, bright=0.12):
    """Warm, woody mallet tone: strong fundamental, soft 4th partial, quick decay."""
    return mix(tone(freq, sec, "sine", 0.002, 5), gain(tone(freq * 4.0, sec * 0.25, "sine", 0.002, 6), bright),
               gain(tone(freq * 0.5, sec * 0.6, "sine", 0.004, 4), 0.25))


def reverb(track, amount=0.25, times=(0.031, 0.047, 0.071, 0.097)):
    out = list(track) + [0.0] * int(0.4 * SR)
    for k, d in enumerate(times):
        off = int(d * SR)
        g = amount * (0.7 ** k)
        for i in range(len(track)):
            out[i + off] += track[i] * g
    # second-order tail
    for k, d in enumerate(times):
        off = int(d * SR * 2.3)
        g = amount * 0.35 * (0.7 ** k)
        for i in range(len(track)):
            if i + off < len(out):
                out[i + off] += track[i] * g
    return out


def write(name, track, peak=0.85):
    m = max(1e-9, max(abs(v) for v in track))
    scale = peak / m
    # fade the last 5 ms to avoid clicks
    fade = int(0.005 * SR)
    for i in range(min(fade, len(track))):
        track[-1 - i] *= i / fade
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in track))
    print("wrote", name, "%.2fs" % (len(track) / SR))


def main():
    os.makedirs(OUT, exist_ok=True)
    # --- UI -----------------------------------------------------------------
    write("ui_click", mix(tone(sweep(1250, 900), 0.06, "sine", 0.001, 5), gain(noise(0.008, lp=6000), 0.3)), 0.6)
    write("ui_hover", tone(sweep(1700, 1900), 0.03, "sine", 0.002, 3), 0.35)
    write("ui_back", tone(sweep(720, 420), 0.08, "tri", 0.002, 3), 0.5)
    write("ui_deny", mix(tone(190, 0.07, "square", 0.002, 2), delay(tone(150, 0.09, "square", 0.002, 2), 0.08)), 0.45)
    write("ui_select", tone(sweep(620, 1040, 0.7), 0.07, "tri", 0.002, 3), 0.5)
    write("aim_start", mix(tone(sweep(500, 650), 0.04, "sine", 0.001, 4), gain(noise(0.01, lp=3000), 0.2)), 0.35)
    write("pop", tone(sweep(520, 1500, 0.5), 0.06, "sine", 0.001, 3), 0.55)

    # --- Shots ---------------------------------------------------------------
    # Ball sounds are deliberately soft: sine bodies, ~2 ms attacks, low-passed, a little room.
    write("swing", noise(0.26, attack=0.15, curve=2.5, lp=300, lp_end=1500, hp=180), 0.42)
    hit = mix(tone(sweep(640, 580), 0.18, "sine", 0.0015, 5), gain(tone(1280, 0.06, "sine", 0.0015, 6), 0.15),
              gain(tone(sweep(170, 120), 0.1, "sine", 0.002, 4), 0.55), gain(noise(0.012, attack=0.001, lp=2200), 0.2))
    write("hit", reverb(lowpass(hit, 3200), 0.14), 0.78)

    # --- Surfaces ------------------------------------------------------------
    grass = mix(tone(sweep(135, 95), 0.1, "sine", 0.003, 4), gain(tone(sweep(300, 240), 0.06, "sine", 0.003, 5), 0.4),
                gain(noise(0.045, attack=0.003, lp=700), 0.3))
    write("thud_grass", lowpass(grass, 1200), 0.55)
    sand = mix(noise(0.15, attack=0.008, curve=2.5, lp=1400, lp_end=300), gain(tone(sweep(110, 85), 0.1, "sine", 0.005, 3), 0.4))
    write("thud_sand", lowpass(sand, 1200), 0.45)
    ice = mix(tone(note("G6"), 0.4, "sine", 0.002, 3), gain(tone(note("G6") * 2.0, 0.2, "sine", 0.002, 4), 0.12),
              gain(tone(note("D7"), 0.25, "sine", 0.003, 4), 0.2))
    write("clink_ice", reverb(lowpass(ice, 5000), 0.3), 0.4)
    rock = mix(tone(sweep(880, 800), 0.08, "sine", 0.0015, 6), gain(tone(sweep(240, 190), 0.07, "sine", 0.002, 4), 0.45),
               gain(noise(0.01, attack=0.001, lp=1500), 0.15))
    write("clack_rock", reverb(lowpass(rock, 2600), 0.1), 0.55)
    write("knock_wood", reverb(lowpass(marimba(note("A4"), 0.28), 3000), 0.15), 0.6)
    squish = mix(noise(0.16, attack=0.01, curve=2.5, lp=500, lp_end=180), gain(tone(sweep(200, 90), 0.16, "sine", 0.008, 2.5), 0.7))
    write("squish", lowpass(squish, 600), 0.5)
    write("boing", lowpass(tone(lambda u: 240 + 360 * math.sin(min(1.0, u * 3) * math.pi * 0.5) * (1 - u * 0.4), 0.35, "sine", 0.004, 2.5, 0.025, 10), 1800), 0.5)
    # Hollow wooden plunk, two soft rattles inside the cup, then a gentle two-note bell.
    cup = mix(lowpass(mix(tone(sweep(392, 330), 0.3, "sine", 0.002, 3), gain(tone(784, 0.12, "sine", 0.002, 4), 0.2)), 2000),
              delay(gain(tone(1050, 0.04, "sine", 0.0015, 5), 0.22), 0.08), delay(gain(tone(980, 0.035, "sine", 0.0015, 5), 0.13), 0.14),
              delay(gain(tone(note("E6"), 0.7, "sine", 0.004, 3), 0.3), 0.2), delay(gain(tone(note("B6"), 0.8, "sine", 0.004, 3), 0.22), 0.3))
    write("cup", reverb(cup, 0.3), 0.7)

    # --- Hazards & abilities -------------------------------------------------
    bubbles = []
    for k in range(9):
        f = rng.uniform(450, 1100)
        bubbles.append(delay(gain(tone(sweep(f, f * 1.6), 0.04, "sine", 0.002, 3), 0.25), 0.08 + k * rng.uniform(0.02, 0.05)))
    write("splash", mix(noise(0.55, attack=0.004, curve=2.2, lp=5000, lp_end=500), *bubbles), 0.75)
    crackle = []
    for k in range(40):
        crackle.append(delay(gain(noise(0.006, attack=0.0005, hp=2000), rng.uniform(0.2, 0.7)), rng.uniform(0, 0.55)))
    write("sizzle", mix(gain(noise(0.6, attack=0.01, curve=1.5, hp=2500), 0.4), *crackle), 0.6)
    boom = mix(noise(0.9, attack=0.002, curve=2.5, lp=1800, lp_end=120), gain(tone(sweep(110, 35), 0.6, "sine", 0.002, 2), 1.2),
               gain(noise(0.05, attack=0.0005, lp=9000), 0.6))
    write("explosion", reverb(boom, 0.18), 0.95)
    write("nitro", mix(noise(0.45, attack=0.03, curve=1.6, lp=800, lp_end=6000, hp=200), gain(tone(sweep(90, 260), 0.4, "square", 0.02, 2), 0.25),
                       *[delay(gain(noise(0.008, hp=3000), 0.5), rng.uniform(0.05, 0.4)) for _ in range(25)]), 0.75)
    write("air_brake", mix(noise(0.35, attack=0.005, curve=2.0, lp=3000, lp_end=300), gain(tone(sweep(300, 90), 0.3, "sine", 0.005, 2), 0.7)), 0.7)
    write("ball_clack", lowpass(mix(tone(sweep(1400, 1300), 0.06, "sine", 0.0015, 6), gain(tone(700, 0.05, "sine", 0.002, 5), 0.3)), 3500), 0.5)
    write("whoosh", noise(0.38, attack=0.18, curve=2.0, lp=600, lp_end=3500, hp=250), 0.55)

    # --- Flow & rewards ------------------------------------------------------
    write("countdown_tick", reverb(chime(880, 0.18, 0.25), 0.15), 0.6)
    go = mix(chime(note("A5"), 0.45, 0.35), gain(chime(note("C#6"), 0.45, 0.3), 0.8), gain(chime(note("E6"), 0.45, 0.3), 0.7))
    write("countdown_go", reverb(go, 0.22), 0.75)
    fan = []
    for k, n in enumerate(["C5", "E5", "G5", "C6"]):
        dur = 0.5 if k == 3 else 0.12
        fan.append(delay(mix(tone(note(n), dur, "tri", 0.004, 2.5), gain(tone(note(n) * 2, dur, "sine", 0.004, 3), 0.3)), k * 0.09))
    write("fanfare", reverb(mix(*fan), 0.25), 0.75)
    melody = [("G4", 0.14), ("C5", 0.14), ("E5", 0.14), ("G5", 0.28), ("E5", 0.14), ("G5", 0.7)]
    vic = []
    t = 0.0
    for n, d in melody:
        vic.append(delay(mix(tone(note(n), d + 0.15, "tri", 0.004, 2.2), gain(tone(note(n) * 2, d + 0.1, "sine", 0.004, 3), 0.25),
                             gain(tone(note(n) / 2, d + 0.15, "sine", 0.01, 2), 0.35)), t))
        t += d
    write("victory", reverb(mix(*vic), 0.28), 0.8)
    write("results", reverb(mix(chime(note("E5"), 0.3, 0.3), delay(chime(note("B5"), 0.45, 0.3), 0.12)), 0.25), 0.6)
    write("alert", mix(tone(note("E5"), 0.12, "tri", 0.003, 2), delay(tone(note("C5"), 0.16, "tri", 0.003, 2), 0.13)), 0.55)
    lv = []
    for k, n in enumerate(["C5", "E5", "G5", "B5", "D6", "G6"]):
        lv.append(delay(chime(note(n), 0.35, 0.4), k * 0.07))
    sparkle = [delay(gain(tone(rng.uniform(3000, 6000), 0.05, "sine", 0.001, 4), 0.2), 0.3 + rng.uniform(0, 0.5)) for _ in range(12)]
    write("level_up", reverb(mix(*lv, *sparkle), 0.3), 0.75)


if __name__ == "__main__":
    main()
