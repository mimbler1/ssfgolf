import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { safeEqual } from '../auth/crypto.ts';
import type { AppContext } from '../context.ts';
import { notFound, parse, unauthorized } from '../errors.ts';
import { ResultSchema, processResult } from '../matches/results.ts';

const RegisterBody = z.object({
  host: z.string().min(1).max(255),
  port: z.int().min(1).max(65535),
  version: z.string().max(64).default(''),
});

const HeartbeatBody = z.object({
  status: z.enum(['idle', 'busy']),
  matchId: z.uuid().nullable().default(null),
});

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const IdParam = z.object({ serverId: z.string().optional(), matchId: z.string().optional() });

/** Game-server internal API (API.md §2). Exempt from rate limiting. */
export async function internalRoutes(app: FastifyInstance, opts: { ctx: AppContext }): Promise<void> {
  const { config, coordinator, pool, now } = opts.ctx;

  app.addHook('onRequest', async (req) => {
    const key = req.headers['x-server-key'];
    if (typeof key !== 'string' || !safeEqual(key, config.gameServerKey)) {
      throw unauthorized('Invalid or missing X-Server-Key');
    }
  });

  app.post('/internal/servers/register', async (req) => {
    const body = parse(RegisterBody, req.body ?? {});
    const server = await coordinator.register(body.host, body.port, body.version);
    req.log.info({ serverId: server.serverId, host: server.host, port: server.port, version: server.version }, 'game server registered');
    return { serverId: server.serverId, heartbeatIntervalMs: config.servers.heartbeatIntervalMs };
  });

  app.post('/internal/servers/:serverId/heartbeat', async (req) => {
    const serverId = parse(IdParam, req.params).serverId ?? '';
    const body = parse(HeartbeatBody, req.body ?? {});
    if (!UUID_RE.test(serverId)) throw notFound('Unknown serverId; re-register');
    const assignment = await coordinator.heartbeat(serverId, body.status, body.matchId);
    return { assignment };
  });

  app.post('/internal/matches/:matchId/result', async (req) => {
    const matchId = parse(IdParam, req.params).matchId ?? '';
    if (!UUID_RE.test(matchId)) throw notFound('Unknown match');
    const body = parse(ResultSchema, req.body ?? {});
    const { rewards, alreadyProcessed } = await processResult(pool, matchId, body, now());
    // Release in-memory state (server idle, players idle, room open). Safe to repeat.
    coordinator.completed(matchId);
    req.log.info({ matchId, endedReason: body.endedReason, alreadyProcessed }, 'match result processed');
    return { rewards };
  });
}
