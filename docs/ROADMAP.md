# Roadmap

This roadmap follows the milestone order of the master development directive. "Done" means
implemented, tested and committed; evidence is listed for each milestone. Earlier milestone notes
(the online foundation, Golfer Studio v1 and the v3 visual pass) are in git history; `checkpoint-pre-rebuild` tags the state before this overhaul.

| # | Milestone | Status | Evidence / what remains |
|---|---|---|---|
| 1 | Studio performance | **Done** | Idle 63.7 → 0.45 ms per frame; character switch 97.7 → 1.15 ms; draw calls about 2,470 → 151; memory flat across cycles (PERFORMANCE_REPORT.md, `--perf-studio`). Remaining: one 40 ms frame on first open (sprite loading) |
| 2 | Retire cartoon art | **Done** (with known quality gaps) | All 17 golfers converted to sprites with the same ids; stage art for all six courses; sprite ball, pixel icons, HUD frames and portraits (ART_DIRECTION.md). Gaps: the art is below hand-pixelled SSF2 quality, some soil tiles are busy, stage props are static, and walk, defeat and emote animations fall back to idle |
| 3 | Normal ball physics | **Done** | Real spin, a tuned power curve, soft-surface plugging, a material table, BallPhysicsLab tests A–H (96 checks) and generated tables (docs/physics/lab_results.md) |
| 4 | Shooting controls | **Done** | Blitz drag and Classic meter, aim arrow, power % / spin / putting, no default trajectory, Laser-only guide, practice debug path, input buffering. Not yet automated: real-input tests |
| 5 | Ability catalogue | **Done** | All 13 SSG3 balls plus Grenade and Heavy, each with distinct tested behaviour (POWERUP_SPEC.md); unlock matrix with server enforcement |
| 6 | First course | **Done** (gameplay) | Golf Land: 9 holes, solver-verified, authored meadow art |
| 7 | Courses 2–6 | **Done** | Beach Land, Sticky Zone, Snow Field, Gravity Lab and Spin Land: 54 holes total, all solver-verified and robust (test_playable 55/55, test_sim 306/306), each with its own stage art |
| 8 | Multiplayer score HUD | **Done** | SSF2-inspired portrait and score panels for 2–6 players, adaptive and readable from 1160×736 to 3440×1440 (HUD_SPEC.md, screenshots) |
| 9 | Convert remaining interfaces | **Mostly done** | Done: pixel-art ability icons, card frames, energy cells, sprite ball, studio podium, framed portraits; course select; results with victory pose; Collection and card packs (backend + client); pause-menu mute/report. Still to do: a pixel logo and profile screen polish |
| 10 | Multiplayer and performance validation | **Mostly done** | Online soak for 2/3/4/5/6 players with abilities: all clients agree. Abrupt drop and rejoin mid-match passes. The backend E2E passes. 6-player gameplay on an idle GPU: 1.4–2.5 ms avg, p95 ≤ 3.1 ms, sim tick about 0.15 ms. Still to do: a low-end hardware pass, and warm-up to remove 1–2 isolated frames over 33 ms per course |

Also added beyond the milestone list:

- Ball unlock progression, enforced by the server.
- Off-screen markers and hole flyover.
- Visible gravity fields and belts.
- Practice ghost paths and a shot log.
- Reduced-motion setting.
- Daily challenge.
- Spectator switching.
- Private-room course, player-count and all-balls settings.

## Next steps (priority order)

1. Shader and texture warm-up at hole load, to remove the isolated 33+ ms frames.
2. A low-end hardware (integrated GPU) performance pass.
3. Art quality pass: calmer soil tiles, animated stage props, and walk, defeat and emote
   animations for the golfers.
4. Golfer Studio on sprites: palette variants, and hat and equipment layers on sprite anchors.
5. More collectible content as art lands: hats and equipment on sprite anchors, ball skins and
   trail effects.
6. Optional collectibles on holes, ability mastery challenges, a pixel-art logo.
