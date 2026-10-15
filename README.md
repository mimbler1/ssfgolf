# Project Fairway Frenzy (working title)

A real-time multiplayer 2D stickman golf racing game for Windows PC. Up to four players race
on the same side-view course at once. There are no turns: you shoot whenever your cooldown is
ready, bump your rivals, spend energy on special balls, and race to the cup. First to 9 points wins.

This is an original game. It is inspired by the *genre* of real-time golf racers, but all code,
art, audio, courses and names are original.

| Component | Tech | Folder |
|---|---|---|
| Game client and dedicated server (same project) | Godot **4.7.2-stable**, typed GDScript | `client/` |
| Backend API (accounts, matchmaking, rooms, rewards) | Node 24, TypeScript, Fastify 5, zod | `backend/` |
| Database | PostgreSQL 16 (Docker) | `docker-compose.yml` |
| Docs | Architecture, gameplay, art direction, course format, roadmap | `docs/` |
| Dev tooling | Launcher, tests, sound, course and sprite generators | `tools/` |

## Setup (Windows)

1. Prerequisites: **Docker Desktop**, **Node 24+**, **Python 3.11+** (only for tools and tests).
2. Install the pinned engine. This downloads the official build and verifies its checksum:
   `powershell ./tools/get-godot.ps1`
3. Start the database: `./tools/dev.ps1 db`
4. Install backend dependencies once: `cd backend; npm install`

## Running locally

From PowerShell in the repo root:

```powershell
./tools/dev.ps1 all        # Postgres + backend + 2 game servers + 2 game clients (alice, bob)
```

Or start each piece yourself:

```powershell
./tools/dev.ps1 backend    # API on http://127.0.0.1:8080
./tools/dev.ps1 server     # dedicated game server on UDP 7777, registers with the backend
./tools/dev.ps1 clients 2  # two windows with separate local identities
```

In each client, choose a name and press **PLAY ONLINE**. When two players queue, they are matched
after 5 seconds in dev (20 seconds by default), or immediately when four are waiting.
**Private Match** creates a room code that friends can join. **Practice** works offline.

### Playing over the internet

- Run the backend somewhere reachable.
- Run each game server with `--public-host <public IP or DNS> --port <UDP port>` and open that UDP
  port. Set `GAME_SERVER_KEY` and `JOIN_TOKEN_SECRET` on the backend, and pass the same values to
  each server (`--server-key`, `--join-secret`, or `FAIRWAY_*` env vars).
- Point clients at the backend in **Settings → Network**.

The backend refuses to start in production with the default secrets.

### Controls

| Action | Default |
|---|---|
| Aim and shoot | Click and drag anywhere, release to shoot (pull-back slingshot; can be switched to push) |
| Cancel aim | Right mouse / X |
| Pick ball | 1–6, or click a card |
| Trigger ability mid-flight | Space |
| Return to last shot | R |
| Hole overview / zoom | Hold Shift / mouse wheel, `=` `-` |
| Scoreboard / menu | Tab / Esc |
| Emotes | Hold T for the emote wheel, or F1–F8 |

All of these can be remapped in **Settings → Controls**.

## Tests

```powershell
./tools/dev.ps1 test
```

This runs:

| Test | What it checks |
|---|---|
| `client/tests/compile_all.gd` | Every script compiles |
| `client/tests/test_sim.gd` | 81 simulation checks: resting, no tunnelling, cup capture, cooldown and energy validation, abilities, ball momentum, 9-point scoring, forfeits, and course validity plus a 40-shot robustness sweep per hole |
| `client/tests/test_playable.gd` | A solver bot must finish every hole |
| `backend` → `npm test` | 59 API and integration tests against real Postgres |
| `tools/e2e_online.py` | Full flow: backend + registered dedicated server + two headless clients, guest auth → roster character on the profile → matchmaking → signed join tokens → match with emotes → reward settlement |

## Developer command-line flags (client)

| Flag (after `--`) | Effect |
|---|---|
| `--practice [--course id] [--hole n] [--lab]` | Jump straight into practice |
| `--studio` | Open the Golfer Studio |
| `--profile NAME` | Use a separate local identity (several clients on one PC) |
| `--backend URL` | Override the backend URL |
| `--server --port N [--insecure-dev --dev-players N]` | Run as a dedicated server. `--insecure-dev` accepts `dev:<name>` tokens with no backend, for local testing only |
| `--connect host:port --dev-name X` | Direct-connect to an `--insecure-dev` server |
| `--screenshot out.png --shot-delay S` | Save a screenshot and quit (art review) |
| `--dev-character ID` | Practice/Studio: play as a roster character without saving it |
| `--dev-emote N` / `--dev-wheel` | Practice: perform emote N / open the emote wheel after loading |
| `res://scenes/dev/gallery.tscn -- --gallery-skins [ids] [poses] [scale] [sprites]` | Roster art review (live-painted, or from baked sheets) |
| `res://scenes/dev/gallery.tscn -- --gallery-emotes [t]` | Stickman presets frozen mid-emote |

## Character sprite sheets

The roster characters (Ace, Nana Birdie, Brick, Bolt, Skipper, Frost) are drawn by
`client/scripts/render/character_skin.gd` over the same animation rig as the Stickman, then baked
into sprite sheets in `client/assets/characters/` (`<id>.png` atlas + `<id>.json` frame data).
After changing character art or any animation, rebake:

```powershell
./tools/bake_sprites.ps1            # all characters (a small window opens while it renders)
./tools/bake_sprites.ps1 ace,nana   # just some
```

The sheet format is documented in `character_sheet.gd`. A hand-drawn sheet in the same format can
replace a baked one.

## Exporting a Windows build

Install the Godot 4.7.2 export templates (Editor → Manage Export Templates), then:

```powershell
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path client --export-release "Windows Desktop"
```

Presets for the game client and a headless dedicated server are in `client/export_presets.cfg`.

See `docs/ROADMAP.md` for what is built and what comes next.
