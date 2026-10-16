import { z } from 'zod';

export const DEFAULT_GAME_SERVER_KEY = 'dev-server-key-change-me';
export const DEFAULT_JOIN_TOKEN_SECRET = 'dev-join-secret-change-me';

const intVar = (def: number) => z.coerce.number().int().default(def);
const boolVar = (def: boolean) =>
  z
    .enum(['true', 'false', '1', '0', 'yes', 'no'])
    .default(def ? 'true' : 'false')
    .transform((v) => v === 'true' || v === '1' || v === 'yes');

const EnvSchema = z.object({
  NODE_ENV: z.string().default('development'),
  PORT: intVar(8080),
  HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  DATABASE_URL: z.string().default('postgres://fairway:fairway@localhost:5432/fairway'),
  GAME_SERVER_KEY: z.string().min(1).default(DEFAULT_GAME_SERVER_KEY),
  JOIN_TOKEN_SECRET: z.string().min(1).default(DEFAULT_JOIN_TOKEN_SECRET),
  TRUST_PROXY: boolVar(false),
  MM_MAX_PLAYERS: intVar(4),
  MM_MIN_PLAYERS: intVar(2),
  MM_FILL_WAIT_MS: intVar(20000),
  MM_TROPHY_WINDOW: intVar(150),
  MM_TROPHY_WINDOW_STEP: intVar(75),
  MM_TROPHY_WINDOW_STEP_MS: intVar(5000),
  MM_TICK_MS: intVar(500),
  MM_COURSE_ID: z.string().regex(/^[a-z0-9_]{1,32}$/).default('blitz_pool'),
  MM_TARGET_POINTS: intVar(9),
  RATE_LIMIT_BURST: intVar(20),
  RATE_LIMIT_PER_SEC: intVar(10),
});

export type Config = {
  env: string;
  isProduction: boolean;
  port: number;
  host: string;
  logLevel: string;
  databaseUrl: string;
  /** Optional search_path schema (used by tests for isolation). */
  databaseSchema: string | null;
  gameServerKey: string;
  joinTokenSecret: string;
  trustProxy: boolean;
  joinTokenTtlSec: number;
  sessionTtlMs: number;
  mm: {
    maxPlayers: number;
    minPlayers: number;
    fillWaitMs: number;
    trophyWindow: number;
    trophyWindowStep: number;
    trophyWindowStepMs: number;
    tickMs: number;
    courseId: string;
    targetPoints: number;
  };
  servers: {
    heartbeatIntervalMs: number;
    timeoutMs: number;
  };
  /** How long a player stays "matched" (match considered active) without a reported result. */
  matchTimeoutMs: number;
  roomIdleMs: number;
  rateLimit: {
    enabled: boolean;
    burst: number;
    perSec: number;
  };
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = EnvSchema.safeParse(env);
  if (!parsed.success) {
    const msg = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration: ${msg}`);
  }
  const e = parsed.data;
  const isProduction = e.NODE_ENV === 'production';
  if (isProduction) {
    if (e.GAME_SERVER_KEY === DEFAULT_GAME_SERVER_KEY) {
      throw new Error('GAME_SERVER_KEY must be changed from its default in production');
    }
    if (e.JOIN_TOKEN_SECRET === DEFAULT_JOIN_TOKEN_SECRET) {
      throw new Error('JOIN_TOKEN_SECRET must be changed from its default in production');
    }
  }
  if (e.MM_MIN_PLAYERS < 2 || e.MM_MAX_PLAYERS < e.MM_MIN_PLAYERS) {
    throw new Error('MM_MIN_PLAYERS must be >= 2 and <= MM_MAX_PLAYERS');
  }
  if (e.MM_TICK_MS < 10) throw new Error('MM_TICK_MS must be >= 10');
  return {
    env: e.NODE_ENV,
    isProduction,
    port: e.PORT,
    host: e.HOST,
    logLevel: e.LOG_LEVEL,
    databaseUrl: e.DATABASE_URL,
    databaseSchema: null,
    gameServerKey: e.GAME_SERVER_KEY,
    joinTokenSecret: e.JOIN_TOKEN_SECRET,
    trustProxy: e.TRUST_PROXY,
    joinTokenTtlSec: 600,
    sessionTtlMs: 30 * 24 * 60 * 60 * 1000,
    mm: {
      maxPlayers: e.MM_MAX_PLAYERS,
      minPlayers: e.MM_MIN_PLAYERS,
      fillWaitMs: e.MM_FILL_WAIT_MS,
      trophyWindow: e.MM_TROPHY_WINDOW,
      trophyWindowStep: e.MM_TROPHY_WINDOW_STEP,
      trophyWindowStepMs: e.MM_TROPHY_WINDOW_STEP_MS,
      tickMs: e.MM_TICK_MS,
      courseId: e.MM_COURSE_ID,
      targetPoints: e.MM_TARGET_POINTS,
    },
    servers: {
      heartbeatIntervalMs: 1000,
      timeoutMs: 10_000,
    },
    matchTimeoutMs: 10 * 60 * 1000,
    roomIdleMs: 30 * 60 * 1000,
    rateLimit: {
      enabled: true,
      burst: e.RATE_LIMIT_BURST,
      perSec: e.RATE_LIMIT_PER_SEC,
    },
  };
}
