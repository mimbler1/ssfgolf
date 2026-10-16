# Power-up Specification

This covers every ball type that is implemented. The single source of data is
`client/data/balance.json` → `abilities`; the rules are in `client/scripts/sim/match_sim.gd`
(`apply_ability`, `cmd_activate`, `_mulligan`, `_shield_block`) and the physics in
`sim_physics.gd`. Every row below is verified by `client/tests/test_abilities.gd`
(results in `docs/physics/lab_results.md`).

**Ball skin, trail, ability and physics profile are separate** (directive §19):

- Skins and trails (appearance `ballColor` / `trailColor`) are cosmetic only.
- The ability is chosen per shot and validated by the server.
- Nothing cosmetic touches `SimBall` physics.

## Common rules

- **Choosing.** The ability is picked before the shot; after any shot the selection returns to
  Regular.
- **Paying for it.**
  - **Blitz** (`online`) and **practice:** each ability costs energy. Energy maxes at 10, starts
    at 4 and regenerates 0.45/s. The server rejects shots the player cannot afford.
  - **Stroke play:** limited charges per course instead of energy: 2 each, Free Shot 1,
    Mulligan 2. The Clean Ball challenge sets every charge to 0.
- **Mode check.** Abilities not allowed in the current mode are rejected (`"mode"`).
- **Activation.** `max_activations` sets how many times Space works during one shot. The
  snapshot `manual` flag tells the client when Space does something.
- **Online authority.** Every effect runs only in the authoritative sim. Clients receive state
  flags (shield, ice, anti-grav, magnet, brake, boost) for visuals only.

## SSG3 catalogue (13)

The official in-game one-line descriptions are quoted where they were available. The
behaviour is this game's own implementation, not measured from SSG3.

| Ball | SSG3 description | Implementation | Activation | Blitz cost | Modes |
|---|---|---|---|---|---|
| Regular (`standard`) | — | Reference profile. No guide. | — | 0 | all |
| Air Brakes (`air_brake`) | "Stop your ball mid-air" | 0.35 s of exponential braking (rate 8/s, keeps about 6% of speed) with gravity ×0.35 during the brake. No instant stop or teleport; the ball lands about 130 px past where Space was pressed | Space ×1 | 2 | all |
| Anti-Grav (`anti_grav`) | "Defy gravity for a short time!" | Gravity ×0 for 1.0 s after the hit: it flies straight along the aim. Ends early on any terrain contact | automatic | 3 | all |
| Free Shot (`free_shot`) | "Don't count this stroke!" | Stroke play: the shot does not add a stroke. Excluded from Blitz, where there are no strokes to save; never a disguised Regular ball | — | — | stroke |
| Ice Ball (`ice`) | "Land on water!" | The upward surfaces of water zones become solid ice (ice material) for this ball, until its next shot. It can bounce, roll and stop on ponds. A `freeze` event draws an ice patch | automatic | 2 | all |
| Laser Ball (`laser`) | "Line up your shot with a LASER!" | While selected, the client draws a red laser guide: the flight simulated with the authoritative physics up to the first bounce plus 0.25 s. Physics identical to Regular (tested). The guide ignores other balls and later activations | — | 2 | all |
| Magnet Ball (`magnet`) | "Attracted to the hole!" | A force toward the cup: 1500 px/s² ÷ (1 + (d/260)²) within 900 px, in flight and while rolling. Terrain still blocks it (tested: it does not pull through walls) | automatic | 4 | all |
| Mulligan (`mulligan`) | "Redo your last shot!" | Until the next shot, including after the ball stops, Space returns this ball to where the shot was taken with the cooldown cleared (≤0.25 s). Stroke play refunds the stroke. **Online it is a personal reposition**: no other ball or world state is rewound (tested) | Space | 3 | all |
| Nitro Ball (`nitro`) | "Give your ball an extra boost!" | 0.22 s of thrust along the flight direction (+640 px/s total), speed cap 2300 | Space ×1 | 3 | all |
| Shield Ball (`shield`) | "Protect your ball from lasers and other hazards" | Blocks the first water, lava or acid zone it enters: the ball pops back out of the surface (55% bounce, at least 420 px/s up) and the shield breaks. While shielded it takes no knockback from blasts or balls. Out of bounds is **not** blocked. There are no laser hazards yet | automatic | 2 | all |
| Sticky Ball (`sticky`) | "Stick your ball to walls!" | Glues to the first surface: ground, walls, slopes or ceilings (tested). It can then be shot off that surface (0.25 s unstick grace) | automatic | 2 | all |
| Super Ball (`super`) | — | Launch speed ×1.22 (about 1.5× the carry) | automatic | 3 | all |
| Zig Zag (`zig_zag`) | — | Mirrors the horizontal velocity and the spin (keeps 92%); vertical motion is kept and only ever damped. Up to 3 flips per shot (tested) | Space ×3 | 2 | all |

## Retained Blitz abilities

| Ball | Implementation | Activation | Cost |
|---|---|---|---|
| Grenade (`grenade`) | Explodes on impact (after 0.12 s arming), on Space, on hitting another ball, or after a 3 s fuse. Radius 175 px, impulse 1150 with linear falloff and upward bias. Self-knockback 40%. Shields are immune | impact / Space | 4 |
| Heavy (`heavy`) | Mass ×4, restitution ×0.4, gravity ×1.18, rolling drag ×0.55. Wins collisions (tested momentum), rebounds about 36% as hard off walls, rolls further on slopes | automatic | 3 |

## Conflict rules

There is one ability per shot, and a new shot clears every ability state (`reset_modifiers`).

- **Respawn.** Respawning after a hazard also clears it, so a Mulligan is lost in a hazard.
  The hazard respawn already returns the ball to the same spot.
- **Shield vs grenade.** Shield immunity also applies to the grenade owner's opponents. The
  owner always takes its own 40%.

## Unlocks

This is not implemented yet: online, every ability is currently allowed for everyone (the
`allowed_abilities` hook exists per player). The planned matrix is in GAME_DESIGN.md
(progression), and every ability has an achievable route that does not need courses beyond
the six included.

## Known gaps

- Ability icons in the HUD are still the old vector glyphs. Pixel-art icons are in production.
- There is no hazard type yet that Shield's "lasers" line would apply to.
- SSG3's actual activation timings and strengths are unknown. Ours are tuned for readability and
  tested to be distinct; see the comparison tables in `docs/physics/lab_results.md`.
