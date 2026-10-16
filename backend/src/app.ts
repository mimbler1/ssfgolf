import Fastify from 'fastify';
import type { FastifyError, FastifyInstance } from 'fastify';
import { authRoutes } from './auth/routes.ts';
import { createAuthService } from './auth/service.ts';
import type { Config } from './config.ts';
import type { AppContext } from './context.ts';
import type { Pool } from './db.ts';
import { AppError, codeForStatus, errorBody } from './errors.ts';
import { MatchCoordinator } from './matches/coordinator.ts';
import { Matchmaker } from './matchmaking/matchmaker.ts';
import { matchmakingRoutes } from './matchmaking/routes.ts';
import { reportRoutes } from './collection/reports.ts';
import { collectionRoutes } from './collection/routes.ts';
import { profileRoutes } from './profile/routes.ts';
import { createRateLimiter } from './rateLimit.ts';
import { RoomService } from './rooms/rooms.ts';
import { roomRoutes } from './rooms/routes.ts';
import { ServerRegistry } from './servers/registry.ts';
import { internalRoutes } from './servers/routes.ts';

export type AppDeps = {
  pool: Pool;
  /** Injectable clock (ms since epoch). Defaults to Date.now. */
  now?: () => number;
  /** Fastify logger option; defaults to pino at config.logLevel. */
  logger?: boolean | Record<string, unknown>;
};

export type BuiltApp = {
  app: FastifyInstance;
  ctx: AppContext;
  /** Starts the matchmaker / housekeeping interval (not started by buildApp, so tests stay deterministic). */
  startBackground: () => void;
};

export async function buildApp(config: Config, deps: AppDeps): Promise<BuiltApp> {
  const now = deps.now ?? Date.now;
  const app = Fastify({
    logger: deps.logger ?? {
      level: config.logLevel,
      redact: {
        paths: [
          'req.headers.authorization',
          'req.headers["x-server-key"]',
          'deviceSecret',
          'sessionToken',
          'joinToken',
        ],
        censor: '[redacted]',
      },
    },
    trustProxy: config.trustProxy,
    bodyLimit: 256 * 1024,
  });

  // Accept empty JSON bodies (e.g. POST /logout with a JSON content-type) as "no body".
  app.removeContentTypeParser('application/json');
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (_req, body, done) => {
    const text = typeof body === 'string' ? body : body.toString('utf8');
    if (text.trim() === '') {
      done(null, undefined);
      return;
    }
    try {
      done(null, JSON.parse(text));
    } catch {
      done(new AppError(400, 'bad_request', 'Malformed JSON body'), undefined);
    }
  });

  const log = app.log;
  const pool = deps.pool;
  const auth = createAuthService({ pool, now, sessionTtlMs: config.sessionTtlMs });
  const registry = new ServerRegistry();
  const coordinator = new MatchCoordinator({
    pool,
    registry,
    now,
    log,
    serverTimeoutMs: config.servers.timeoutMs,
    matchTimeoutMs: config.matchTimeoutMs,
  });
  const matchmaker = new Matchmaker({ pool, config, coordinator, now, log });
  const rooms = new RoomService({ pool, config, coordinator, now, log });
  matchmaker.isInRoom = (pid) => rooms.isInRoom(pid);
  rooms.isQueued = (pid) => matchmaker.isQueued(pid);

  const ctx: AppContext = {
    config,
    pool,
    now,
    log,
    auth,
    registry,
    coordinator,
    matchmaker,
    rooms,
    tick: async () => {
      await coordinator.sweep();
      rooms.sweep();
      await matchmaker.tick();
    },
  };

  if (config.rateLimit.enabled) {
    const limiter = createRateLimiter({ burst: config.rateLimit.burst, perSec: config.rateLimit.perSec, now });
    app.addHook('onRequest', async (req, reply) => {
      if (req.url.startsWith('/internal/') || req.url === '/internal') return;
      if (!limiter.take(req.ip)) {
        reply.header('retry-after', '1');
        throw new AppError(429, 'rate_limited', 'Too many requests');
      }
    });
  }

  app.setErrorHandler((err: FastifyError | AppError | Error, req, reply) => {
    if (err instanceof AppError) {
      if (err.statusCode >= 500) req.log.warn({ code: err.code }, err.message);
      return reply.code(err.statusCode).send(errorBody(err.code, err.message));
    }
    const status = (err as FastifyError).statusCode;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      return reply.code(status).send(errorBody(codeForStatus(status), err.message));
    }
    req.log.error({ err }, 'unhandled error');
    return reply.code(500).send(errorBody('internal', 'Internal server error'));
  });

  app.setNotFoundHandler((_req, reply) => {
    reply.code(404).send(errorBody('not_found', 'Route not found'));
  });

  app.get('/health', async () => ({ ok: true }));

  await app.register(authRoutes, { ctx });
  await app.register(profileRoutes, { ctx });
  await app.register(collectionRoutes, { ctx });
  await app.register(reportRoutes, { ctx });
  await app.register(matchmakingRoutes, { ctx });
  await app.register(roomRoutes, { ctx });
  await app.register(internalRoutes, { ctx });

  let timer: NodeJS.Timeout | null = null;
  let running = false;
  const startBackground = () => {
    if (timer) return;
    timer = setInterval(() => {
      if (running) return;
      running = true;
      ctx
        .tick()
        .catch((err: unknown) => log.error({ err }, 'background tick failed'))
        .finally(() => {
          running = false;
        });
    }, config.mm.tickMs);
    timer.unref();
  };
  app.addHook('onClose', async () => {
    if (timer) clearInterval(timer);
    timer = null;
  });

  return { app, ctx, startBackground };
}
