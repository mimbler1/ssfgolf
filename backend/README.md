# Fairway Frenzy backend

Node 24 + TypeScript + Fastify 5 + PostgreSQL 16. Implements the contract in [`../docs/API.md`](../docs/API.md):
guest auth, profiles, Quick Play matchmaking, private rooms, the game-server registry, and match results/rewards.

There is no build step. Node 24 runs the `.ts` sources directly (type stripping), so the code uses erasable-only
TypeScript: no enums, namespaces or parameter properties.

## Quick start

```bash
# 1. Database (from the repo root). Only Postgres starts by default.
docker compose up -d postgres

# 2. Backend
cd backend
npm install
npm run dev          # node --watch src/index.ts  (migrations run automatically on startup)
# or: npm start      # node src/index.ts
```

Liveness: `GET http://localhost:8080/health` returns `{ "ok": true }`.

To run the backend in Docker too: `docker compose --profile full up -d --build`.

## Scripts

| Script | What it does |
|---|---|
| `npm start` | Start the server (`node src/index.ts`). |
| `npm run dev` | Start with `--watch`. |
| `npm run migrate` | Apply pending SQL migrations from `migrations/` (also runs automatically on startup). |
| `npm run typecheck` | `tsc --noEmit` (strict). |
| `npm test` | `node --test` over `test/**/*.test.ts`. Needs Postgres (see below). |

## Tests

The tests run against a real Postgres. They use `TEST_DATABASE_URL`, which defaults to
`postgres://fairway:fairway@localhost:5432/fairway_test`. The setup creates the `fairway_test` database if it is
missing. Each test file runs in its own freshly migrated schema, which is dropped afterwards, so files can run in
parallel. HTTP is exercised with Fastify's `app.inject`. The matchmaker and housekeeping are driven with
`ctx.matchmaker.tick()` / `ctx.tick()` and an injected fake clock, so the tests do not sleep.

```bash
docker compose up -d postgres
npm test
```

## Configuration (env)

| Var | Default | Notes |
|---|---|---|
| `PORT` | `8080` | |
| `HOST` | `0.0.0.0` | |
| `DATABASE_URL` | `postgres://fairway:fairway@localhost:5432/fairway` | |
| `GAME_SERVER_KEY` | `dev-server-key-change-me` | `X-Server-Key` for `/internal`. **Must be changed in production.** |
| `JOIN_TOKEN_SECRET` | `dev-join-secret-change-me` | HMAC secret shared with the game server. **Must be changed in production.** |
| `NODE_ENV` | `development` | With `production`, the server refuses to start if either secret above has its default value. |
| `LOG_LEVEL` | `info` | pino level (`silent` to disable). |
| `TRUST_PROXY` | `false` | Set this to `true` behind a reverse proxy so rate limiting uses the client IP. |
| `MM_MAX_PLAYERS` | `4` | |
| `MM_MIN_PLAYERS` | `2` | |
| `MM_FILL_WAIT_MS` | `20000` | |
| `MM_TROPHY_WINDOW` | `150` | Initial ± window. |
| `MM_TROPHY_WINDOW_STEP` | `75` | Widening per step (extra knob). |
| `MM_TROPHY_WINDOW_STEP_MS` | `5000` | Step length (extra knob). |
| `MM_TICK_MS` | `500` | Interval for the matchmaker and housekeeping. |
| `MM_COURSE_ID` | `sunny_meadows` | Quick Play course. |
| `MM_TARGET_POINTS` | `9` | Quick Play target points (extra knob). |
| `RATE_LIMIT_BURST` | `20` | Per-IP token bucket size. |
| `RATE_LIMIT_PER_SEC` | `10` | Refill rate. `/internal/*` is exempt. |

## Layout

```
src/
  index.ts            entrypoint (migrate, listen, start the tick interval, graceful shutdown)
  app.ts              buildApp(config, { pool, now?, logger? }) -> { app, ctx, startBackground }
  config.ts           env parsing + production secret guard
  db.ts, migrate.ts   pg Pool, transaction helper, tiny migration runner (schema_migrations table)
  joinToken.ts        HMAC-SHA256 join tokens (API.md §3), sign + reference verify
  rateLimit.ts        in-memory per-IP token bucket
  auth/               guest create/login (scrypt), sessions (sha256-hashed tokens), bearer hook
  profile/            appearance schema, level curve, /v1/me, /v1/me/matches, /v1/matches/:id, /v1/leaderboard
  matchmaking/        Quick Play queue + tick
  rooms/              private rooms
  servers/            game-server registry + /internal routes
  matches/            match coordinator (allocation, delivery, cancellation, expiry), reward math, result processing
migrations/           NNN_name.sql, applied in order
```

## Design notes and v1 limitations

- **Single instance only.** The matchmaking queue, rooms, the game-server registry and live-match bookkeeping are
  held in memory. A restart forgets them: queued players have to queue again, game servers re-register on their
  next 404 heartbeat, and in-flight matches can still report results because the match records are in Postgres.
  Redis is the planned scale-out path for this shared state.
- Match records are persisted as soon as a match is created (`status = assigned`). They then move to `started`
  (the server's heartbeat reports `busy` with that matchId), and finally to `completed`, `aborted`, `cancelled`
  (the server was lost before starting) or `expired` (no result within 10 minutes).
- Result processing runs in a single transaction. It takes `SELECT … FOR UPDATE` on the match row and checks the
  status, so a repeated or concurrent report returns the stored rewards and never applies them twice.
- Secrets are never logged. Device secrets are stored as scrypt hashes and session tokens as SHA-256 hashes.
  Logger redaction also covers the `authorization` and `x-server-key` headers.
