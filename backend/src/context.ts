import type { FastifyBaseLogger } from 'fastify';
import type { AuthService } from './auth/service.ts';
import type { Config } from './config.ts';
import type { Pool } from './db.ts';
import type { MatchCoordinator } from './matches/coordinator.ts';
import type { Matchmaker } from './matchmaking/matchmaker.ts';
import type { RoomService } from './rooms/rooms.ts';
import type { ServerRegistry } from './servers/registry.ts';

/** Shared services, wired once in buildApp and passed to route plugins. */
export type AppContext = {
  config: Config;
  pool: Pool;
  now: () => number;
  log: FastifyBaseLogger;
  auth: AuthService;
  registry: ServerRegistry;
  coordinator: MatchCoordinator;
  matchmaker: Matchmaker;
  rooms: RoomService;
  /** One housekeeping + matchmaking pass (what the interval timer runs). */
  tick: () => Promise<void>;
};
