import { randomUUID } from 'node:crypto';
import type { FastifyBaseLogger } from 'fastify';
import type { Pool } from '../db.ts';
import { notFound } from '../errors.ts';
import { levelForXp } from '../profile/level.ts';
import { getPlayers } from '../profile/repo.ts';
import type { GameServer, MatchAssignment, ServerRegistry } from '../servers/registry.ts';

export type ActiveMatch = {
  matchId: string;
  mode: 'quick' | 'private';
  ranked: boolean;
  courseId: string;
  targetPoints: number;
  roomCode: string | null;
  serverId: string;
  serverHost: string;
  serverPort: number;
  playerIds: string[];
  createdAtMs: number;
  /** True once the game server reported it is running this match. */
  started: boolean;
};

export type MatchEndReason = 'reported' | 'cancelled' | 'expired';

export type CreateMatchOptions = {
  mode: 'quick' | 'private';
  ranked: boolean;
  courseId: string;
  targetPoints: number;
  playerIds: string[];
  roomCode?: string | null;
  /** Private rooms only: every ball for everyone. */
  allAbilities?: boolean;
};

/**
 * Owns the lifecycle of live matches: server allocation, persistence of the
 * match record, delivery bookkeeping, cancellation and expiry. Live state is
 * in memory (v1, single instance); match records are persisted in Postgres.
 */
export class MatchCoordinator {
  pool: Pool;
  registry: ServerRegistry;
  now: () => number;
  log: FastifyBaseLogger;
  serverTimeoutMs: number;
  matchTimeoutMs: number;
  matches = new Map<string, ActiveMatch>();
  byPlayer = new Map<string, string>();
  listeners: Array<(m: ActiveMatch, reason: MatchEndReason) => void> = [];

  constructor(opts: {
    pool: Pool;
    registry: ServerRegistry;
    now: () => number;
    log: FastifyBaseLogger;
    serverTimeoutMs: number;
    matchTimeoutMs: number;
  }) {
    this.pool = opts.pool;
    this.registry = opts.registry;
    this.now = opts.now;
    this.log = opts.log;
    this.serverTimeoutMs = opts.serverTimeoutMs;
    this.matchTimeoutMs = opts.matchTimeoutMs;
  }

  onEnded(fn: (m: ActiveMatch, reason: MatchEndReason) => void): void {
    this.listeners.push(fn);
  }

  hasFreeServer(): boolean {
    return this.registry.hasFree();
  }

  forPlayer(playerId: string): ActiveMatch | undefined {
    const id = this.byPlayer.get(playerId);
    return id ? this.matches.get(id) : undefined;
  }

  get(matchId: string): ActiveMatch | undefined {
    return this.matches.get(matchId);
  }

  /**
   * Allocates a free server and creates the match. Returns null when no server
   * is free. All in-memory reservations happen synchronously before the first
   * await, so concurrent callers can never double-book a server or a player.
   */
  async create(opts: CreateMatchOptions): Promise<ActiveMatch | null> {
    const server = this.registry.findFree();
    if (!server) return null;
    const nowMs = this.now();
    const match: ActiveMatch = {
      matchId: randomUUID(),
      mode: opts.mode,
      ranked: opts.ranked,
      courseId: opts.courseId,
      targetPoints: opts.targetPoints,
      roomCode: opts.roomCode ?? null,
      serverId: server.serverId,
      serverHost: server.host,
      serverPort: server.port,
      playerIds: [...opts.playerIds],
      createdAtMs: nowMs,
      started: false,
    };
    server.matchId = match.matchId;
    this.matches.set(match.matchId, match);
    for (const pid of match.playerIds) this.byPlayer.set(pid, match.matchId);

    try {
      const players = await getPlayers(this.pool, match.playerIds);
      const assignment: MatchAssignment = {
        matchId: match.matchId,
        mode: match.mode,
        ranked: match.ranked,
        courseId: match.courseId,
        targetPoints: match.targetPoints,
        allAbilities: opts.allAbilities ?? false,
        createdAt: new Date(nowMs).toISOString(),
        players: match.playerIds.map((pid, slot) => {
          const p = players.get(pid);
          if (!p) throw new Error(`player ${pid} not found`);
          return {
            playerId: pid,
            displayName: p.display_name,
            trophies: p.trophies,
            level: levelForXp(Number(p.xp)),
            slot,
            appearance: p.appearance,
          };
        }),
      };
      await this.pool.query(
        `INSERT INTO matches (id, mode, ranked, course_id, target_points, room_code, server_id, server_host, server_port,
                              status, assignment, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'assigned', $10, $11)`,
        [
          match.matchId,
          match.mode,
          match.ranked,
          match.courseId,
          match.targetPoints,
          match.roomCode,
          server.serverId,
          server.host,
          server.port,
          JSON.stringify(assignment),
          new Date(nowMs),
        ],
      );
      // The server may have been dropped or replaced while we were awaiting.
      if (this.registry.get(server.serverId) !== server || server.matchId !== match.matchId) {
        await this.cancel(match, 'server_lost');
        return null;
      }
      server.pendingAssignment = assignment;
      this.log.info({ matchId: match.matchId, serverId: server.serverId, mode: match.mode, players: match.playerIds.length }, 'match assigned');
      return match;
    } catch (err) {
      this.release(match);
      throw err;
    }
  }

  /** Handles a heartbeat; returns the assignment to deliver, if any. */
  async heartbeat(serverId: string, status: 'idle' | 'busy', matchId: string | null): Promise<MatchAssignment | null> {
    const server = this.registry.get(serverId);
    if (!server) throw notFound('Unknown serverId; re-register');
    const assignment = this.registry.heartbeat(server, status, matchId, this.now());
    if (assignment) {
      this.log.info({ matchId: assignment.matchId, serverId }, 'assignment delivered');
    }
    if (status === 'busy' && matchId && matchId === server.matchId) {
      const m = this.matches.get(matchId);
      if (m && !m.started) {
        m.started = true;
        await this.pool.query(`UPDATE matches SET status = 'started', started_at = $2 WHERE id = $1 AND status = 'assigned'`, [
          matchId,
          new Date(this.now()),
        ]);
        this.log.info({ matchId, serverId }, 'match started');
      }
    }
    return assignment;
  }

  /** Registers a server; a re-registration of the same host:port drops the old entry. */
  async register(host: string, port: number, version: string): Promise<GameServer> {
    const { server, replaced } = this.registry.register(host, port, version, this.now());
    if (replaced) {
      this.log.info({ serverId: replaced.serverId, host, port }, 'server re-registered; old entry replaced');
      await this.handleServerGone(replaced);
    }
    return server;
  }

  /** Called after a result has been committed. */
  completed(matchId: string): void {
    const m = this.matches.get(matchId);
    if (m) this.finish(m, 'reported');
  }

  /** Periodic housekeeping: stale servers and expired matches. */
  async sweep(): Promise<void> {
    const nowMs = this.now();
    for (const server of this.registry.sweep(nowMs, this.serverTimeoutMs)) {
      this.log.warn({ serverId: server.serverId, host: server.host, port: server.port }, 'server heartbeat timeout; dropped');
      await this.handleServerGone(server);
    }
    for (const m of [...this.matches.values()]) {
      if (nowMs - m.createdAtMs >= this.matchTimeoutMs) {
        await this.pool.query(
          `UPDATE matches SET status = 'expired', cancel_reason = 'timeout' WHERE id = $1 AND status IN ('assigned', 'started')`,
          [m.matchId],
        );
        this.log.warn({ matchId: m.matchId }, 'match expired without result');
        this.finish(m, 'expired');
      }
    }
  }

  private async handleServerGone(server: GameServer): Promise<void> {
    for (const m of [...this.matches.values()]) {
      if (m.serverId === server.serverId && !m.started) {
        await this.cancel(m, 'server_lost');
      }
    }
  }

  async cancel(m: ActiveMatch, reason: string): Promise<void> {
    try {
      await this.pool.query(
        `UPDATE matches SET status = 'cancelled', cancel_reason = $2, ended_at = $3
         WHERE id = $1 AND status IN ('assigned', 'started')`,
        [m.matchId, reason, new Date(this.now())],
      );
    } finally {
      this.log.warn({ matchId: m.matchId, reason }, 'match cancelled');
      this.finish(m, 'cancelled');
    }
  }

  private release(m: ActiveMatch): void {
    this.matches.delete(m.matchId);
    for (const pid of m.playerIds) {
      if (this.byPlayer.get(pid) === m.matchId) this.byPlayer.delete(pid);
    }
    this.registry.release(m.serverId, m.matchId);
  }

  private finish(m: ActiveMatch, reason: MatchEndReason): void {
    if (!this.matches.has(m.matchId)) return;
    this.release(m);
    for (const fn of this.listeners) {
      try {
        fn(m, reason);
      } catch (err) {
        this.log.error({ err, matchId: m.matchId }, 'match end listener failed');
      }
    }
  }
}
