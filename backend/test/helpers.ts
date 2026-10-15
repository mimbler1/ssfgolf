import { randomBytes } from 'node:crypto';
import pg from 'pg';
import { buildApp } from '../src/app.ts';
import type { BuiltApp } from '../src/app.ts';
import { loadConfig } from '../src/config.ts';
import type { Config } from '../src/config.ts';
import { createPool } from '../src/db.ts';
import type { Pool } from '../src/db.ts';
import { migrate } from '../src/migrate.ts';
import type { MatchAssignment } from '../src/servers/registry.ts';

export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgres://fairway:fairway@localhost:5432/fairway_test';
export const SERVER_KEY = 'test-server-key';
export const JOIN_SECRET = 'test-join-secret';

/** Creates the test database if it does not exist (safe to call concurrently). */
async function ensureDatabase(): Promise<void> {
  const url = new URL(TEST_DATABASE_URL);
  const dbName = decodeURIComponent(url.pathname.replace(/^\//, ''));
  const adminUrl = new URL(TEST_DATABASE_URL);
  adminUrl.pathname = '/postgres';
  const client = new pg.Client({ connectionString: adminUrl.toString() });
  await client.connect();
  try {
    const { rowCount } = await client.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
    if (!rowCount) {
      try {
        await client.query(`CREATE DATABASE "${dbName.replace(/"/g, '""')}"`);
      } catch (err) {
        const code = (err as { code?: string }).code;
        if (code !== '42P04' && code !== '23505') throw err; // created concurrently
      }
    }
  } finally {
    await client.end();
  }
}

/**
 * Each test file gets its own freshly migrated schema (so files can run in
 * parallel against one database); it is dropped again in cleanup.
 */
export async function setupTestDb(): Promise<{ pool: Pool; schema: string; cleanup: () => Promise<void> }> {
  await ensureDatabase();
  const schema = `t_${randomBytes(6).toString('hex')}`;
  const admin = new pg.Client({ connectionString: TEST_DATABASE_URL });
  await admin.connect();
  await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  await admin.query(`CREATE SCHEMA ${schema}`);
  await admin.end();
  const pool = createPool(TEST_DATABASE_URL, schema);
  await migrate(pool);
  return {
    pool,
    schema,
    cleanup: async () => {
      await pool.end();
      const c = new pg.Client({ connectionString: TEST_DATABASE_URL });
      await c.connect();
      await c.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
      await c.end();
    },
  };
}

export class FakeClock {
  t: number;
  constructor(start = Date.UTC(2026, 0, 1, 12, 0, 0)) {
    this.t = start;
  }
  now = (): number => this.t;
  advance(ms: number): void {
    this.t += ms;
  }
}

export function testConfig(overrides: Partial<Config> = {}): Config {
  const base = loadConfig({
    NODE_ENV: 'test',
    GAME_SERVER_KEY: SERVER_KEY,
    JOIN_TOKEN_SECRET: JOIN_SECRET,
    LOG_LEVEL: 'silent',
  });
  return { ...base, rateLimit: { ...base.rateLimit, enabled: false }, ...overrides };
}

export type TestApp = BuiltApp & { clock: FakeClock; pool: Pool; close: () => Promise<void> };

/** Builds an app over a fresh schema. Call `close()` in `after`. */
export async function createTestApp(overrides: Partial<Config> = {}): Promise<TestApp> {
  const db = await setupTestDb();
  const clock = new FakeClock();
  const built = await buildApp(testConfig(overrides), { pool: db.pool, now: clock.now, logger: false });
  await built.app.ready();
  return {
    ...built,
    clock,
    pool: db.pool,
    close: async () => {
      await built.app.close();
      await db.cleanup();
    },
  };
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
export const serverHeaders = { 'x-server-key': SERVER_KEY };

export type Guest = { playerId: string; deviceId: string; deviceSecret: string; token: string };

export async function newGuest(t: TestApp, displayName?: string): Promise<Guest> {
  const res = await t.app.inject({
    method: 'POST',
    url: '/v1/auth/guest',
    payload: displayName ? { displayName } : {},
  });
  if (res.statusCode !== 200) throw new Error(`guest create failed: ${res.statusCode} ${res.body}`);
  const b = res.json();
  return { playerId: b.playerId, deviceId: b.deviceId, deviceSecret: b.deviceSecret, token: b.sessionToken };
}

export async function newGuests(t: TestApp, n: number): Promise<Guest[]> {
  const out: Guest[] = [];
  for (let i = 0; i < n; i++) out.push(await newGuest(t, `Player_${i}`));
  return out;
}

export async function setTrophies(t: TestApp, playerId: string, trophies: number): Promise<void> {
  await t.pool.query('UPDATE players SET trophies = $2, highest_trophies = GREATEST(highest_trophies, $2) WHERE id = $1', [
    playerId,
    trophies,
  ]);
}

export async function registerServer(t: TestApp, port = 7777, host = '127.0.0.1'): Promise<string> {
  const res = await t.app.inject({
    method: 'POST',
    url: '/internal/servers/register',
    headers: serverHeaders,
    payload: { host, port, version: '0.1.0' },
  });
  if (res.statusCode !== 200) throw new Error(`register failed: ${res.statusCode} ${res.body}`);
  return res.json().serverId;
}

export async function heartbeat(
  t: TestApp,
  serverId: string,
  status: 'idle' | 'busy' = 'idle',
  matchId: string | null = null,
): Promise<{ statusCode: number; assignment: MatchAssignment | null }> {
  const res = await t.app.inject({
    method: 'POST',
    url: `/internal/servers/${serverId}/heartbeat`,
    headers: serverHeaders,
    payload: { status, matchId },
  });
  return { statusCode: res.statusCode, assignment: res.statusCode === 200 ? res.json().assignment : null };
}

export async function queue(t: TestApp, g: Guest) {
  return t.app.inject({ method: 'POST', url: '/v1/matchmaking/queue', headers: bearer(g.token), payload: { mode: 'quick' } });
}

export async function mmStatus(t: TestApp, g: Guest) {
  const res = await t.app.inject({ method: 'GET', url: '/v1/matchmaking/status', headers: bearer(g.token) });
  return res.json();
}

/**
 * Registers a server (if not given), queues players, ticks the matchmaker and
 * fetches the assignment via heartbeat. Returns the assignment.
 */
export async function startQuickMatch(t: TestApp, players: Guest[], serverId?: string) {
  const sid = serverId ?? (await registerServer(t, 7000 + Math.floor(Math.random() * 1000)));
  await heartbeat(t, sid, 'idle');
  for (const p of players) {
    const r = await queue(t, p);
    if (r.statusCode !== 200) throw new Error(`queue failed: ${r.statusCode} ${r.body}`);
  }
  if (players.length < t.ctx.config.mm.maxPlayers) t.clock.advance(t.ctx.config.mm.fillWaitMs);
  const created = await t.ctx.matchmaker.tick();
  if (created !== 1) throw new Error(`expected 1 match, got ${created}`);
  const hb = await heartbeat(t, sid, 'idle');
  if (!hb.assignment) throw new Error('no assignment delivered');
  await heartbeat(t, sid, 'busy', hb.assignment.matchId);
  return { serverId: sid, assignment: hb.assignment };
}

export async function reportResult(t: TestApp, matchId: string, body: unknown) {
  return t.app.inject({
    method: 'POST',
    url: `/internal/matches/${matchId}/result`,
    headers: serverHeaders,
    payload: body as Record<string, unknown>,
  });
}

export async function getMe(t: TestApp, g: Guest) {
  const res = await t.app.inject({ method: 'GET', url: '/v1/me', headers: bearer(g.token) });
  return res.json();
}
