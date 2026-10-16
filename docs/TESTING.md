# Testing

These are the test suites that exist and what each one verifies, with how to run them. `tools/dev.ps1 test` runs the
fast suites. The longer soak and benchmark tools are run by hand.

## Automated suites

| Suite | Command | Verifies | Last result |
|---|---|---|---|
| Compile | `godot --headless --path client --script res://tests/compile_all.gd` | Every script parses and compiles | 72 / 72 |
| Characters | `... res://tests/test_characters.gd` | Roster definitions, every character × animation pose solves, legacy ids resolve | 1224 poses, 0 failures |
| Simulation | `... res://tests/test_sim.gd` | Resting, tunnelling at max power, cup capture, command validation (energy, cooldown, airborne), grenade, sticky walls, momentum, scoring and match end, disconnect forfeits. **Every hole of every course:** cup cut, tee ground, and 40 random shots cycling all 14 online abilities with random spin, mid-flight activations and in-flight spin. The ball must never end inside terrain or become unshootable | 306 / 306 |
| BallPhysicsLab | `... res://tests/test_abilities.gd` | Directive lab tests A–H, spin, surfaces, gravity fields (low, flipped, zero-G float), conveyors, modes / Free Shot / Mulligan / Clean Ball, 5–6 player rules, power curve. Writes `docs/physics/lab_results.md` | 90 / 90 |
| Playability | `... res://tests/test_playable.gd` | The `CourseSolver` bot finishes every hole (54 course holes + lab) with the plain ball, no spin | 55 / 55 |
| Backend | `cd backend; npm test` | Accounts, matchmaking, rooms (2–6 players), results settlement, rewards, validation | 59 / 59 |
| Online E2E | `python tools/e2e_online.py` | Backend + registered dedicated server + 2 guest clients through matchmaking, a full match, signed tokens and reward settlement | PASSED |
| Multi-client soak | `python tools/e2e_multi.py N [--target P]` | Dedicated server (dev mode, six-course pool) + N headless bots that shoot with random abilities, spin and mid-flight activations. All clients must be welcomed with the full roster and end with **identical** standings, with no script errors | 2, 3, 4, 5, 6 players PASSED |

`godot` means `tools/godot/Godot_v4.7.2-stable_win64_console.exe`.

## Developer tools

| Tool | Purpose |
|---|---|
| `python tools/courses/check.py <course> [--hole N]` | Rebuild a course from `tools/courses/<id>.py`, run the solver and render review maps (terrain, hazards, fields, solver shot paths) |
| `godot --path client --resolution WxH -- --profile perf --perf-studio out.json` | Golfer Studio benchmark (see PERFORMANCE_REPORT.md). Requires a separate `--profile` |
| `-- --practice --course <id> --hole N` | Jump into practice |
| `-- --stroke --course <id>` | Jump into stroke play |
| `-- --courses` | Open course select |
| `-- --studio` | Open the Golfer Studio |
| `-- --practice --course blitz_pool --dev-blitz N --dev-points a,b,...` | Local Blitz match with N players (idle bots) for HUD and flow checks |
| `--dev-aim angle,power [--dev-ability id] [--dev-spin s] [--dev-controls classic]` | Freeze an aim for screenshots |
| `--screenshot out.png --shot-delay S` | Save the viewport and quit |
| `-- --server --insecure-dev --dev-players N [--dev-course id] [--dev-target P]` | Dev game server; clients join with `--connect host:port --dev-name Name@character` |

Use `--profile <name>` for any automated or screenshot run, so a player's real local data is
never modified.

## Manual verification done for this overhaul

- **Screenshots** in `docs/screens/v4/`:
  - aim (regular, laser, classic);
  - course select;
  - stroke play;
  - HUD for 2–6 players at 1920×1080, 1280×720, 1160×736, 2560×1440 and 3440×1440.

## Known gaps

- The perf probe covers the Golfer Studio only. A gameplay frame-time probe (practice and
  6-ball online) is still to be added.
- No automated test drives real mouse or keyboard input. Aim and controls were verified with
  the dev aim hooks and by reading the code.
- Reconnect, and leaving during a hole, are covered by the backend and sim forfeit tests and by
  `e2e_online.py`. The multi-client soak does not yet include deliberate drop and rejoin.
