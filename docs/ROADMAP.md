# Roadmap

This roadmap follows the milestone order of the master development directive. "Done" means
implemented, tested and committed; evidence is listed for each milestone. Earlier milestone notes
(the online foundation, Golfer Studio v1 and the v3 visual pass) are in git history; `checkpoint-pre-rebuild` tags the state before this overhaul.

| # | Milestone | Status | Evidence / what remains |
|---|---|---|---|
| 1 | Studio performance | **Done** | Idle 54–64 → 4–6 ms per frame; character switch 97 → 6 ms (PERFORMANCE_REPORT.md, `--perf-studio`). Remaining: one-frame hitches on first open (80–128 ms) from building legacy toon cards |
| 2 | Retire cartoon art | **In progress** | Inventory written (ART_REPLACEMENT_INVENTORY.md). The roster is converting to sprites with the same ids (CHARACTER_CONVERSION.md). Still to do: stage art for five themes, the sprite ball, effects, and studio customisation on sprites |
| 3 | Normal ball physics | **Done** | Real spin, a tuned power curve, soft-surface plugging, a material table, BallPhysicsLab tests A–H (96 checks) and generated tables (docs/physics/lab_results.md) |
| 4 | Shooting controls | **Done** | Blitz drag and Classic meter, aim arrow, power % / spin / putting, no default trajectory, Laser-only guide, practice debug path, input buffering. Not yet automated: real-input tests |
| 5 | Ability catalogue | **Done** | All 13 SSG3 balls plus Grenade and Heavy, each with distinct tested behaviour (POWERUP_SPEC.md); unlock matrix with server enforcement |
| 6 | First course | **Done** (gameplay) | Golf Land: 9 holes, solver-verified, authored meadow art |
| 7 | Courses 2–6 | **Done** (gameplay) / art pending | Beach Land, Sticky Zone, Snow Field, Gravity Lab and Spin Land: 54 holes total, all solver-verified and robust (test_playable 55/55, test_sim 306/306). Stage art for themes 2–6 is the main remaining visual gap |
| 8 | Multiplayer score HUD | **Done** | SSF2-inspired portrait and score panels for 2–6 players, adaptive and readable from 1160×736 to 3440×1440 (HUD_SPEC.md, screenshots) |
| 9 | Convert remaining interfaces | **Mostly done** | Done: pixel-art ability icons, card frames, energy cells, sprite ball, studio podium, framed portraits; course select; results with victory pose; Collection and card packs (new, backend + client); pause-menu mute/report. Still to do: a pixel logo, profile screen polish, hiding any character still not converted |
| 10 | Multiplayer and performance validation | **Mostly done** | Online soak for 2/3/4/5/6 players with abilities: all clients agree. Abrupt drop and rejoin mid-match passes. The backend E2E passes. Gameplay perf probe added (sim tick ~0.13 ms). Still to do: re-measure frame times on an idle GPU, and a low-end hardware pass |

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

1. Integrate the character and UI art tracks: the converted roster, portraits, ability icons,
   sprite ball and HUD frames. Then hide any character that is still toon-only from the roster.
2. Stage art for Beach Land, Sticky Zone, Snow Field, Gravity Lab and Spin Land, through the same
   pipeline as the meadow.
3. Re-measure gameplay and studio performance with the GPU idle, and update
   PERFORMANCE_REPORT.md.
4. Golfer Studio on sprites: palette variants, and hat and equipment layers on sprite anchors.
5. More collectible content as art lands: hats and equipment on sprite anchors, ball skins and
   trail effects.
6. Optional collectibles on holes, ability mastery challenges, a pixel-art logo.
