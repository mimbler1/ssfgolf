# Physics Specification

This describes the implemented simulation (`client/scripts/sim/`). The same code runs on the
dedicated server, in practice and stroke play, and in the Laser Ball guide. All tunable values
live in `client/data/balance.json` (`physics`, `shot`) and `client/data/materials.json`.
Measured behaviour for the current values is generated into `docs/physics/lab_results.md` by
the BallPhysicsLab test suite (`client/tests/test_abilities.gd`).

## Reference and honesty note

Super Stickman Golf 3's real constants and source are not available. Nothing here is copied
from it or claimed to match it numerically. The targets are the observable *qualities* the
directive asks for:

- clear ballistic arcs;
- a few bounces that lose energy;
- natural rolling that slows on grass and stops on sand;
- backspin that checks a ball up;
- topspin that runs on;
- surfaces that feel different;
- predictable repeat shots.

These are verified by tests against this game's own numbers.

## 1. World and timestep

- **Timestep.** The fixed tick is 1/60 s (`MatchSim.DT`). Each tick is split into substeps so
  that no ball moves more than `max_substep_travel` (3.5 px) per substep, up to 32 substeps.
  This is the tunnelling guard: tested at maximum power against thin walls, the ball never
  passes through.
- **Units.** px and seconds. The ball radius is 9 px, and a golfer is about 85 px tall.
- **Terrain.** Polygons are smoothed into short segments, held in a uniform grid of 96 px cells.
  A winding-number solid test (`SimTerrain.point_in_polygon`) is used for recovery and hazard
  checks.
  - Godot's `Geometry2D.is_point_in_polygon` was replaced after it produced false positives on
    large course polygons.
- **Determinism.** Identical inputs give identical results (lab test H).

## 2. Launch

- **Power curve.** `speed = lerp(min_speed, max_speed, curve(power))`, where `curve` is
  piecewise-linear through `shot.power_curve`: [0,0], [.25,.42], [.5,.68], [.75,.86], [1,1].
  Carry then grows roughly in proportion to power. At 45° on flat grass:

  | Power | Carry |
  |---|---|
  | 10% | 91 px |
  | 25% | about 350 px |
  | 50% | about 770 px |
  | 100% | about 1500 px |

  Half power carries 0.38–0.6 of full; the exact figures are in the lab table. The tested
  invariant is that more power always carries further.
- **Putting profile** (client input, not physics). When the ball is on the ground within 420 px
  horizontally of the cup and level with it within 150 px, the full drag or meter covers only
  42% of the power scale. Small differences then matter. The tag "PUTT" shows on the arrow.
- **Launch spin.**
  `ang_vel = (vx + fwd * spin * gain * |v|) / r`, where:
  - `vx / r` is natural roll;
  - `spin` runs from -1 to +1;
  - `gain` is `spin_gain_back` (2.8) for backspin and `spin_gain_top` (1.4) for topspin.

## 3. Flight

- **Gravity.** 1500 px/s², times the ball's gravity scale. Gravity fields override it (§6).
- **Air drag.** 0.04/s, linear.
- **Speed cap.** 3400 px/s. Nitro's own cap can raise it.
- **Spin in flight.** Spin decays by 10% per second. Holding top/back spin in flight adds
  ±95 rad/s² in the travel direction (`cmd_spin`), up to |ω| ≤ 300 rad/s. Spin does **not** curve
  the flight: there is no Magnus force, which is tested ("spin barely changes the carry"). It
  only acts through contact.

## 4. Contact, bounce, spin, rolling

Each contact resolves along the surface normal *n* and tangent *t*.

**Bounce.**
- Normal speed after impact is `impact * restitution(material) * restitution_scale(ball)`.
- It becomes 0 if the impact is below the material's `bounce_min`, so tiny hops die out instead
  of jittering.
- Bouncy pads add a one-shot launch speed, re-armed by touching another surface.

**Impact friction (spin).**
- The contact point slips at `slip = vt - ω·r - surface_speed`.
- An impulse removes that slip as for a solid ball (inertia factor k = 0.4): `vt -= j`,
  `ω += j/(k·r)`.
- The impulse is capped Coulomb-style at `μ · impact · (1+e) · impact_friction` (1.0).
- Results:
  - **No spin:** a ball launched with natural roll lands with almost no slip and keeps its
    speed.
  - **Backspin:** large slip on landing, so the ball checks up (lab table: 45° full backspin
    stops within about 90 px of where it lands).
  - **Steep backspin:** spins back toward the player.
  - **Topspin:** pushes forward on landing.

**Soft surfaces.**
- Sand (0.85) and snow (0.45) also lose tangential speed and spin on impact
  (`impact_tangent_loss`, scaled by impact strength), so the ball plugs.
- Rough (0.2) behaves the same way, more weakly.

**Rolling contact (every substep in contact).**
- Kinetic friction `μ · load · h` removes slip, where `load = gravity · cos(slope)` from the
  actual local gravity.
- Rolling resistance `roll_drag(material) · roll_drag_scale(ball) · load/g` then slows both speed
  and spin equally.
- Both vanish on walls and ceilings and weaken in low gravity.

**Conveyors.** `surface_speed` (±300 px/s) makes the belt the reference for slip, so friction
carries a resting ball along.

## 5. Rest, stuck and recovery

- **Rest.** A ball comes to rest when all of these hold:
  - it is grounded (it touched within 0.12 s);
  - its speed is below 24 px/s and its slip below 48 px/s;
  - the slope relative to local gravity is within the material's `rest_slope_deg`;
  - it holds that for 0.14 s;
  - no thrust or magnet is acting.
- **Creep.** A ball creeping below 60 px/s for 9 s is settled anyway, so nobody waits forever.
- **Sticky.** Sticky terrain, or the Sticky ball, glues on contact. Shooting off a sticky surface
  gives 0.25 s of unstick grace.
- **Recovery.** After a deep contact, a ball found inside solid terrain is moved to the surface
  above it.

## 6. Gravity fields

A hole may list `fields`:

- `{"type": "gravity", "scale": 0.35, "points": [...]}` multiplies the base gravity inside the
  polygon.
- `{"type": "gravity", "vector": [x, y], "points": [...]}` sets an absolute gravity.

Inside a field the ball's "up" follows the field, so it can roll and rest on a ceiling under
upward gravity (tested). Fields are not hazards.

## 7. Ball-to-ball

- **Collision.** Circles collide with mass-weighted positional correction and an impulse with
  restitution 0.82. Momentum is conserved (tested, within air drag).
- **Heavy.** Mass 4: it keeps going and launches the lighter ball.
- **Immovable balls.** Stuck and shielded balls have infinite mass: they take no knockback but
  others bounce off them.
- **Collision flag.** A ball joins collisions once it has been shot, so tee spawns never shove.
- **Explosions.** Radial impulse with linear falloff and an upward bias. The grenade's owner
  takes 40%. Shields are immune.

## 8. Materials (current values)

| Material | Restitution | Friction μ | Roll drag | Rest slope | Bounce min | Special |
|---|---|---|---|---|---|---|
| grass | 0.40 | 0.45 | 1.25 | 13° | 75 | |
| rough | 0.22 | 0.55 | 3.4 | 22° | 90 | impact loss 0.2 |
| sand | 0.05 | 0.95 | 7.5 | 48° | 200 | impact loss 0.85 |
| snow | 0.12 | 0.62 | 4.2 | 30° | 140 | impact loss 0.45 |
| ice | 0.32 | 0.015 | 0.06 | 1.2° | 70 | spin barely grips |
| rock | 0.55 | 0.35 | 1.1 | 11° | 60 | |
| wood | 0.48 | 0.40 | 1.4 | 12° | 60 | |
| sticky | 0 | 1 | 40 | 90° | inf | glues |
| bouncy | 0.95 | 0.15 | 0.6 | 10° | 60 | +780 px/s launch, once per shot |
| conveyor_r / conveyor_l | 0.30 | 0.70 | 1.2 | 12° | 80 | surface speed ±300 |
| cup | 0.10 | 0.90 | 6 | 70° | 120 | |

## 9. Hazards and respawn

| Ball event | Result |
|---|---|
| Enters a water, lava or acid zone | Hazard, unless it is an Ice ball on water or a Shield ball (see POWERUP_SPEC) |
| Goes out of bounds | Hazard: past the bottom of the hole +120 px, the sides ±300 px, or the top −2500 px |

After a hazard:
- The ball is respawned after 1.1 s at the last shot position.
- If that position is now a hazard or inside terrain, the ball goes to the tee.
- If a respawn leads straight back into a hazard within 2.5 s, the next respawn uses the tee.
- Stroke play adds one penalty stroke.
- Reset (R) also respawns at the last shot position: a 3 s cooldown online, +1 stroke in stroke
  play.

## 10. Cup

- **Width and depth.** The cup is 34 px wide and 30 px deep, cut into the surface automatically.
- **Capture.** Any ball that drops below the lip line inside the cup is holed. A slow ball
  (under 620 px/s) is also holed while over the inner mouth.
- **Swish and ace.** The ball's terrain contacts since the shot (cup excluded) are tracked. Zero
  contacts means a **swish**; one stroke means a **hole-in-one**. Both are sent in the `holed`
  event. Neither changes Blitz points.

## 11. Tests

| File | Covers | Current |
|---|---|---|
| `client/tests/test_sim.gd` | Rest, tunnelling, cup, validation, grenade, sticky, momentum, scoring, forfeits, course validity, random shots of every ability with spin and activations on every hole | 81 checks |
| `client/tests/test_abilities.gd` | BallPhysicsLab tests A–H, spin, surfaces, fields, conveyors, modes, Mulligan/Free Shot, 5–6 players, power curve; writes `docs/physics/lab_results.md` | 89 checks |
| `client/tests/test_playable.gd` | A solver bot finishes every hole using the shared launch functions | |
