# Backend API Contract — v1

Project Fairway Frenzy backend (`/backend`). Fastify + TypeScript on Node 24, PostgreSQL 16.
All bodies are JSON. All timestamps are ISO-8601 UTC strings. All IDs are UUID strings unless noted.

Errors always use this shape with an appropriate 4xx/5xx status:

```json
{ "error": { "code": "snake_case_code", "message": "Human readable" } }
```

Common codes: `bad_request`, `unauthorized`, `forbidden`, `not_found`, `conflict`, `rate_limited`, `internal`.

---

## 1. Player-facing API (`/v1/...`)

Authenticated endpoints require `Authorization: Bearer <sessionToken>`.

### 1.1 Auth

`POST /v1/auth/guest`

Creates a new guest account, or logs in to an existing one.

Request (all fields optional):
```json
{ "deviceId": "uuid", "deviceSecret": "string", "displayName": "string" }
```
- No `deviceId` → create a new account. The server generates `deviceId` and a random 32-byte `deviceSecret` (base64url). The secret is returned **only once**; the server stores only a scrypt hash.
- With `deviceId` + `deviceSecret` → verify the secret and log in. A wrong secret returns `401 unauthorized`.
- `displayName` (create only): 3–16 chars, `^[A-Za-z0-9_ ]+$`, trimmed. Defaults to `Golfer####`.

Response `200`:
```json
{
  "playerId": "uuid",
  "deviceId": "uuid",
  "deviceSecret": "only-present-on-create",
  "sessionToken": "opaque string",
  "expiresAt": "iso",
  "profile": { "...Profile..." }
}
```
Session tokens are 32 random bytes (base64url). Only their SHA-256 hash is stored. Sessions expire after 30 days.

`POST /v1/auth/logout` (auth) → `204`. Revokes the current session.

### 1.2 Profile

`GET /v1/me` (auth) → `200 Profile`

```json
{
  "playerId": "uuid",
  "displayName": "Golfer1234",
  "createdAt": "iso",
  "level": 3,
  "xp": 412,
  "xpIntoLevel": 162,
  "xpForNextLevel": 200,
  "trophies": 130,
  "highestTrophies": 150,
  "coins": 240,
  "appearance": { "...Appearance..." },
  "stats": {
    "matches": 10, "wins": 4, "holesPlayed": 38, "holeWins": 15,
    "shots": 210, "abilitiesUsed": 33, "favoriteAbility": "nitro",
    "currentWinStreak": 1, "longestWinStreak": 3
  }
}
```
- Level curve: going from level `n` to `n+1` requires `100 + 50*(n-1)` XP. `xp` is lifetime total. Players start at level 1 with 0 XP.
- `favoriteAbility` is the most-used non-standard ability, or `null`.

`PATCH /v1/me` (auth). Body: `{ "displayName"?: string, "appearance"?: Appearance }`. Returns `200 Profile`.

`GET /v1/me/matches?limit=20` (auth, max limit 50) → `200 { "matches": [MatchSummary] }`. Newest first.

`GET /v1/matches/:matchId` (auth). Only participants may read it (`403` otherwise). Returns `404` until the game server has reported the result.
```json
{
  "matchId": "uuid", "mode": "quick" | "private", "ranked": true,
  "courseId": "sunny_meadows", "endedAt": "iso", "endedReason": "completed" | "aborted",
  "players": [ { "playerId": "uuid", "displayName": "x", "placement": 1, "points": 9, "disconnected": false } ],
  "myRewards": { "trophyDelta": 30, "trophiesAfter": 160, "xpGained": 105, "coinsGained": 40,
                 "levelBefore": 3, "levelAfter": 4 }
}
```
A `MatchSummary` has the same shape without `players`, plus `"placement"` and `"playerCount"`.

`GET /v1/leaderboard?limit=50` (auth, max 100) → `200 { "entries": [ { "rank": 1, "playerId": "uuid", "displayName": "x", "trophies": 900, "level": 12 } ] }`. Ordered by trophies desc, ties broken by earlier `highestTrophies` achievement and then by `playerId`.

### 1.3 Appearance (versioned, validated server-side)

```json
{
  "v": 1,
  "character": "stickman",
  "bodyColor": "#2b2d42",
  "outlineColor": "#11121c",
  "headShape": "round",
  "headScale": 1.0,
  "limbThickness": 1.0,
  "eyes": "dot",
  "mouth": "smile",
  "hat": "cap" | null,
  "hatColor": "#e63946",
  "shirt": "tee" | null,
  "shirtColor": "#457b9d",
  "ballColor": "#ffffff",
  "trailColor": "#ffd166"
}
```
Validation:
- `v` must be `1`.
- Colors match `^#[0-9a-fA-F]{6}$`.
- String ids match `^[a-z0-9_]{1,32}$`. The server does not check them against a catalog in v1; clients fall back to defaults for unknown ids.
- `headScale` is in [0.8, 1.3]. `limbThickness` is in [0.7, 1.5].
- `character` is optional: `"stickman"` (the customisable rig, also the meaning when absent) or a
  roster character id (`ace`, `nana`, `brick`, `bolt`, `skipper`, `frost`). Roster characters
  ignore the body/face/hat/shirt fields; ball and trail colours still apply.
- Unknown keys are rejected.

Default appearance for new accounts: the example above, with `hat: null` and `shirt: "tee"`.

### 1.4 Matchmaking (Quick Play, ranked)

`POST /v1/matchmaking/queue` (auth). Body `{ "mode": "quick" }`. Returns `200 MatchmakingStatus`. Returns `409 conflict` if the player is already queued, in a room that is starting, or in an active match.

`GET /v1/matchmaking/status` (auth) → `200 MatchmakingStatus`:
```json
{
  "status": "idle" | "searching" | "matched",
  "queuedAt": "iso or null",
  "elapsedMs": 4200,
  "match": null | {
    "matchId": "uuid", "serverHost": "127.0.0.1", "serverPort": 7777, "joinToken": "..."
  }
}
```
`DELETE /v1/matchmaking/queue` (auth) → `204`. Cancels the search. This is a no-op when not searching. It cannot cancel once matched.

A match stays in `matched` status for the player until the game server reports its result, or until 10 minutes pass.

Matching rules. All values come from environment config, with the defaults shown:
- `MM_MAX_PLAYERS=4`, `MM_MIN_PLAYERS=2`, `MM_FILL_WAIT_MS=20000`.
- Trophy window starts at ±`MM_TROPHY_WINDOW=150` and widens by `+75` every 5 s of waiting. The window used is that of the longest-waiting player in the group.
- A group starts immediately once it has `MM_MAX_PLAYERS` players. It starts with ≥ `MM_MIN_PLAYERS` once the oldest member has waited `MM_FILL_WAIT_MS`.
- A match needs a free registered game server. Without one, players stay `searching`.
- The matchmaker runs on an interval of `MM_TICK_MS=500`.

### 1.5 Private rooms (friendly, unranked)

Room codes are 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.

`Room`:
```json
{
  "code": "K7Q2MX", "hostId": "uuid", "status": "open" | "starting" | "in_match",
  "settings": { "maxPlayers": 4, "targetPoints": 9, "courseId": "sunny_meadows" },
  "members": [ { "playerId": "uuid", "displayName": "x", "ready": false, "isHost": true } ],
  "match": null | { "matchId": "...", "serverHost": "...", "serverPort": 7777, "joinToken": "..." }
}
```
`match.joinToken` is specific to the requesting member.

- `POST /v1/rooms` (auth). Body `{ "maxPlayers"?: 2..4, "targetPoints"?: 3..21, "courseId"?: id }`. Creates the room; the caller becomes host. Returns `200 Room`. Returns `409` if the caller is already in a room, queue or match.
- `GET /v1/rooms/:code` (auth, members only) → `200 Room`.
- `POST /v1/rooms/:code/join` (auth) → `200 Room`. Returns `404` for an unknown code and `409` if the room is full or not `open`.
- `POST /v1/rooms/:code/leave` (auth) → `204`. If the host leaves, the next member becomes host. An empty room is deleted.
- `POST /v1/rooms/:code/ready` (auth). Body `{ "ready": bool }` → `200 Room`.
- `PATCH /v1/rooms/:code` (auth, host only, room `open`). Body is a partial of `settings` → `200 Room`. Any settings change resets every non-host member's `ready` to false.
- `POST /v1/rooms/:code/start` (auth, host only). Requires ≥2 members and all non-host members ready. It allocates a game server; status becomes `starting`, then `in_match` once allocated. Returns `200 Room` and `503` with code `no_server` if no server is free.
- After the game server reports the result, the room returns to `open` with all `ready=false`.
- Rooms are held in memory in v1. A room with no member requests for 30 minutes is deleted.

### 1.6 Rate limits

Use a simple in-memory per-IP token bucket: about 20 requests/second burst and 10/s sustained. `/internal` routes are exempt.

---

## 2. Game-server internal API (`/internal/...`)

Every request requires the header `X-Server-Key: <GAME_SERVER_KEY>` (env). A wrong or missing key returns `401`.

`POST /internal/servers/register`. Body `{ "host": "127.0.0.1", "port": 7777, "version": "0.1.0" }` → `200 { "serverId": "uuid", "heartbeatIntervalMs": 1000 }`.
Re-registering the same host:port replaces the old entry.

`POST /internal/servers/:serverId/heartbeat`. Body `{ "status": "idle" | "busy", "matchId": "uuid or null" }` → `200 { "assignment": MatchAssignment | null }`.
- The backend hands a pending assignment to an idle server on its next heartbeat. The server is then considered busy.
- A server with no heartbeat for 10 s is dropped. Matches assigned to it but never started are cancelled, and the players return to `idle` (rooms return to `open`).
- An unknown `serverId` returns `404`; the server must re-register.

`MatchAssignment`:
```json
{
  "matchId": "uuid",
  "mode": "quick" | "private",
  "ranked": true,
  "courseId": "sunny_meadows",
  "targetPoints": 9,
  "createdAt": "iso",
  "players": [
    { "playerId": "uuid", "displayName": "x", "trophies": 120, "slot": 0, "appearance": { "...Appearance..." } }
  ]
}
```
Quick-play matches use `courseId: "sunny_meadows"` and `targetPoints: 9` in v1 (config `MM_COURSE_ID`).

`POST /internal/matches/:matchId/result`:
```json
{
  "endedReason": "completed" | "aborted",
  "players": [
    { "playerId": "uuid", "placement": 1, "points": 9, "holesWon": 3, "holesPlayed": 5,
      "shots": 21, "abilitiesUsed": { "nitro": 2, "grenade": 1 }, "disconnected": false }
  ],
  "holes": [ { "holeId": "sm_01", "finishOrder": ["uuid", "uuid"] } ]
}
```
- The endpoint is **idempotent**: a second report for the same match returns the first result and changes nothing. Processing runs in **one transaction**.
- Every listed `playerId` must be in the assignment roster (`400` otherwise). Every roster player must be present.
- `aborted` matches record history and apply no trophy changes. Their XP and coins are 0.
- Returns `200 { "rewards": [ { "playerId": "uuid", "trophyDelta": 30, "xpGained": 105, "coinsGained": 40 } ] }`.
- After processing, the server is idle again, and players' matchmaking status returns to `idle`.

### 2.1 Reward rules (ranked quick play, `completed`)

- Trophy delta by placement:
  - 4 players: `[+30, +12, -6, -16]`
  - 3 players: `[+25, 0, -12]`
  - 2 players: `[+20, -12]`
- Disconnected players always receive the last-place delta. Trophies never go below 0.
- XP: `40 + 15*holesWon + [30,20,10,0][placement-1]`, using the last bonus value for placements beyond 4.
- Coins: `15 + 5*holesWon + [25,15,8,0][placement-1]`.
- Private (unranked) `completed` matches give no trophies, half the XP (floored) and no coins.
- Stats update for every completed match: `matches`, `wins` (placement 1), `holesPlayed`, `holeWins` (the `holesWon` field), `shots`, `abilitiesUsed` and its per-ability counts (used for `favoriteAbility`), and win streaks (a non-first placement resets the current streak).
- `highestTrophies = max(highestTrophies, trophies)`.

---

## 3. Join tokens (backend ↔ game server)

The backend signs a join token for each player in a match, using HMAC-SHA256 with `JOIN_TOKEN_SECRET`. The game server shares this secret.

Format: `base64url(payloadJson) + "." + base64url(hmacSha256(secret, base64url(payloadJson)))`. Base64url has no padding.

Payload: `{ "m": "<matchId>", "p": "<playerId>", "exp": <unix seconds> }`. Tokens expire 10 minutes after issue.

The game server verifies the signature and expiry, and checks that `p` is in the roster of the assignment for match `m`.

---

## 4. Configuration (env)

| Var | Default (dev) | Notes |
|---|---|---|
| `PORT` | `8080` | |
| `HOST` | `0.0.0.0` | |
| `DATABASE_URL` | `postgres://fairway:fairway@localhost:5432/fairway` | |
| `GAME_SERVER_KEY` | `dev-server-key-change-me` | Must be changed in production. |
| `JOIN_TOKEN_SECRET` | `dev-join-secret-change-me` | Must be changed in production. |
| `MM_*` | see §1.4 | |
| `NODE_ENV` | `development` | In production, refuse to start with the default secrets. |
