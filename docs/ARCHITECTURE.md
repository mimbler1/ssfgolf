# Architecture

## Overview

```
 ┌──────────────┐  HTTPS/JSON (REST)   ┌─────────────────┐   SQL   ┌────────────┐
 │ Game client  │ ───────────────────▶ │ Backend (Node)  │ ──────▶ │ PostgreSQL │
 │ (Godot 4.7)  │ ◀── join token ────  │ Fastify + zod   │         └────────────┘
 └──────┬───────┘                      └───────┬─────────┘
        │ ENet/UDP (commands ▲, snapshots ▼)   │ /internal (X-Server-Key):
        ▼                                      │ register, heartbeat → assignment,
 ┌──────────────────────┐ ◀────────────────────┘ match result
 │ Dedicated server     │
 │ (same Godot project, │
 │  --headless --server)│
 └──────────────────────┘
```

## Key decisions

- **One Godot project for the client and the dedicated server.**
  - The simulation code (`client/scripts/sim/`) is literally the same on both sides. Practice mode
    runs it locally, the server runs it authoritatively, and the client's aim preview uses it to
    predict trajectories.
  - The server is launched with `--headless -- --server`. The export preset includes a
    dedicated-server build.
- **Custom 2D ball physics instead of Godot's rigid bodies** (`sim_physics.gd`). Golf feel is the
  heart of the game, so it needs exact control: per-material restitution, friction and rolling
  drag; slope-dependent resting; and predictable bounces.
  - Fixed 60 Hz ticks, with each tick split into substeps so no ball moves more than 3.5 px per
    substep. This is the tunnelling guard, a tested equivalent of continuous collision detection.
  - Each ball also gets an interior-recovery check after any deep contact.
  - Determinism across machines is **not** assumed. The server is the only source of truth.
- **Authoritative server.**
  - Clients only send commands: shoot (angle, power, ability index), trigger ability, reset ball,
    emote, leave, ping.
  - The server validates phase, cooldown, ground contact, energy, ability ownership, NaN/Inf input,
    and a per-peer rate limit (20 commands per second).
  - Everything else (positions, collisions, hazards, placement, scoring, energy) is simulated on
    the server and broadcast.
- **Networking (Godot high-level multiplayer over ENet).**
  - Channel 0 is reliable: commands, and time-stamped events (shot, ability, explosion, hazard,
    holed, hole end, match end…).
  - Channel 1 is unreliable-ordered: binary snapshots (`snapshot_codec.gd`, about 24 + 28·N bytes)
    at 30 Hz from the 60 Hz simulation.
  - Clients estimate the server clock from snapshot arrival times and render about 100 ms in the
    past, interpolating between snapshots. This gives smooth remote balls with no rubber-banding.
    Events are replayed at the same render time, so effects line up with the balls.
- **Backend owns identity, matchmaking and rewards.**
  - Guest accounts: device id plus secret. The secret is stored scrypt-hashed on the server and
    encrypted on the PC. Sessions are opaque tokens, stored SHA-256-hashed.
  - The backend signs per-player **join tokens** (HMAC-SHA256) that the game server verifies
    offline (`join_token.gd`).
  - Match results go to `/internal/matches/:id/result`, which is idempotent and settles in a single
    transaction, so retries can't double-grant rewards.
- **Data-driven content.** Balance (`data/balance.json`), materials (`data/materials.json`),
  courses (`data/courses/*.json`) and appearance options are data, not code. New holes, materials
  and ability parameters need no code changes. New ability *behaviours* are a single `match`
  branch in `match_sim.gd`.

## Client structure (`client/scripts`)

| Folder | Role |
|---|---|
| `sim/` | `SimTerrain` (spline terrain, cup cutting, spatial grid, raycasts), `SimBall`, `SimPhysics`, `MatchSim` (rules) |
| `net/` | `net.gd` (RPC bridge autoload), `snapshot_codec.gd`, `join_token.gd` |
| `server/` | `game_server.gd`: lifecycle, backend registration/heartbeat, join validation, broadcasting |
| `game/` | `MatchView` interface with `LocalMatchView` (practice) and `NetMatchView` (online); `game_scene.gd`; `hud.gd` |
| `render/` | Vector renderers: backdrop, terrain, ball, golfer rig, trajectory, FX particles |
| `ui/` | Theme tokens, main menu, Golfer Studio, settings, icons, buttons |
| `autoload/` | `GameData`, `Settings` (incl. input remapping), `Sfx`, `Backend` (HTTP + session), `Router` |

## Match lifecycle

1. The client queues (`POST /v1/matchmaking/queue`) and polls status.
2. The backend matchmaker groups players by trophy window (which widens over time). It starts
   immediately with 4 players, or with 2–3 after the fill wait. It persists the match and hands
   the assignment to an idle registered server on that server's next heartbeat.
3. Clients receive `{serverHost, serverPort, joinToken}` and connect.
   - The server verifies each token.
   - A client that arrives before the assignment is held for up to 8 s.
4. The match starts when everyone has joined.
   - If some players are missing after 25 s but at least 2 are present, it starts and the missing
     players forfeit.
   - Otherwise the match is aborted, with no trophy changes.
5. Holes run as: countdown → play → (first finisher starts a 25 s window; hard cap 120 s) →
   results. This repeats until someone reaches the target score with a unique lead, or 15 holes
   have been played.
6. The server posts the result (with retries). The backend settles trophies, XP, coins, stats and
   history in one transaction. Clients poll `GET /v1/matches/:id` to show rewards.

## Disconnects

- A disconnected player keeps their slot for **30 s** and can reconnect with the same token.
  Their ball stays put and they don't block the hole from ending.
- After the grace period they forfeit and are placed last.
- A deliberate **Leave** forfeits immediately.
- If one player remains, the match completes in their favour. If none remain, it's aborted.

## Known v1 limitations

- **Single backend instance.** The queue, rooms and server registry are held in memory; Redis is
  the planned scale-out path. Match records are persisted.
- **No client-side prediction of your own ball.** Your shot appears after about RTT/2 + 100 ms.
  Local prediction with reconciliation is on the roadmap.
- **No automated test under simulated latency or packet loss yet.** Use a tool such as *clumsy* on
  Windows meanwhile.
