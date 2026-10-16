# Game Design

**Fairway Frenzy** is a real-time 2D side-view golf racer for Windows PC. It combines:

- the golf mechanics of Super Stickman Golf 3 (precise aim and power, spin, surfaces, hazards,
  ball powers, creative holes);
- the simultaneous online racing of Golf Blitz (everyone plays the same hole at once, balls
  collide, abilities cost energy, finishing order scores points);
- the sprite-art presentation of Super Smash Flash 2.

All content is original.

This document describes the game as implemented. Details live in:

| Document | Covers |
|---|---|
| PHYSICS_SPEC.md | Physics |
| POWERUP_SPEC.md | Balls and unlocks |
| COURSE_MANIFEST.md | Courses |
| HUD_SPEC.md | HUD |
| ART_DIRECTION.md | Art |
| TESTING.md | Tests |
| PERFORMANCE_REPORT.md | Performance |

## Modes

| Mode | Players | Rules |
|---|---|---|
| **Blitz (online)** | 2–6 | Everyone plays the same hole simultaneously from the tee. Finishing order scores points: 2 players 3-0; 3 players 3-1-0; 4 players 3-2-1-0; 5 players 4-3-2-1-0; 6 players 5-4-3-2-1-0. When the first player holes out, the rest have 25 s. Win at 9 points (5 players: 12; 6 players: 15). A tie at the top plays on, with a 15-hole cap. Holes are drawn at random from all six courses. Quick Play is ranked (trophies) with 2–4 players. Private rooms take 2–6 players; the host picks the target, the player cap, one course or all courses, and "all balls for everyone" |
| **Stroke play (solo)** | 1 | One course's nine holes in order. Strokes count against par, plus 1 penalty stroke for each hazard or reset. Balls are limited by charges per round instead of energy. Optional Clean Ball challenge (no abilities). The round ends with a scorecard, medal and personal records |
| **Practice** | 1 | Any hole on repeat. All balls available. Optional debug flight path. Physics Lab tuning panel |

## The shot

**Controls.** There are two control styles, chosen in Settings. Both send the same command to
the same physics.

- **Blitz (default):** press, drag (pull-back or push), release. Power follows drag length.
  Right-click cancels.
- **Classic (SSG3-style):** A/D or the arrow keys rotate the aim arrow (a tap moves one degree;
  hold to speed up). Space starts a power meter with a fixed timing, and Space again hits.

**Spin.** Before the shot, W/S set launch spin from −100% to +100% in 25% steps. In flight,
holding W/S adds top or back spin. Spin acts only through ground contact:

- backspin checks the ball up, or spins it back on steep landings;
- topspin runs it on;
- on ice, spin barely grips.

**Putting.** Near the cup, the full input range covers 42% of power, so small differences
matter.

**No flight-path preview.** A normal shot shows only a solid aim arrow, the power %, the spin and
the meter. The Laser Ball shows a red guide. Practice has an opt-in debug path.

**Ability use.** Space (or click) triggers the selected ball's ability mid-flight, where it has
one. R returns the ball to the last shot position: 3 s cooldown online, +1 stroke in stroke play.

**Cooldown.** Online there is a 1.7 s cooldown between shots, and a shot released up to 0.4 s
early is buffered.

## Balls

There are 15 ball types: all 13 SSG3 types (Regular, Air Brakes, Anti-Grav, Free Shot, Ice,
Laser, Magnet, Mulligan, Nitro, Shield, Sticky, Super, Zig Zag) plus the Blitz abilities Grenade
and Heavy. Each has distinct, tested physics (POWERUP_SPEC.md).

Balls are side-grades, not stat upgrades:

- cosmetics never change physics;
- skins and trails are visual only;
- golfer upgrades are not implemented, by design for now (fair ranked).

Unlocks come by level, solo course completion or an achievement, and every ball can be unlocked
with the six included courses.

## Courses

Six nine-hole courses (54 holes): Golf Land, Beach Land, Sticky Zone, Snow Field, Gravity Lab and
Spin Land. Each is built around its course's mechanic:

- sand and water;
- sticky goo;
- snow vs ice;
- gravity fields;
- spin and conveyors.

The layouts are original (see COURSE_MANIFEST.md for the reference fidelity statement). The
course select screen shows each course's progress, medal and best round.

## Hazards and fairness

- **Water, acid and lava** respawn the ball at the last shot position after 1.1 s. Out of bounds
  does the same.
- **Respawn safety.** A respawn spot inside a hazard or inside terrain, or one that loops back
  into a hazard, falls back to the tee.
- **Stuck balls.** A ball creeping for 9 s is settled. A ball that stalls in zero-G floats at rest
  and can be shot again.
- **Server authority.** The dedicated server is authoritative for shots, physics, collisions,
  hazards, abilities, energy, cooldowns, unlocks, scoring and match end. Clients interpolate
  snapshots and never change game state. The Laser guide uses public physics on the client;
  anyone could compute it, so it is an aid, not hidden information.

## Records and achievements (solo)

Records are kept per profile:

- best round and time per course;
- best Clean Ball round;
- medal per course (gold: 3+ under par; silver: par or better; bronze: completed);
- best strokes per hole;
- totals for holes-in-one and swishes.

A swish is a ball holed with no terrain contact since the shot. Swishes and holes-in-one are
announced but never change Blitz points.

## Not implemented yet

- Card packs.
- The cosmetic collection.
- Rematch.
- Spectator mode.
- Daily challenges.
- Course flyover.
- Shot replay.
- Equipment modifiers for casual modes.
- Collectible objectives.

These are tracked in ROADMAP.md.
