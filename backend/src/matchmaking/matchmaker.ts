import type { FastifyBaseLogger } from 'fastify';
import type { Config } from '../config.ts';
import type { Pool } from '../db.ts';
import { conflict, notFound } from '../errors.ts';
import { issueJoinToken } from '../joinToken.ts';
import type { MatchCoordinator } from '../matches/coordinator.ts';

export type QueueEntry = { playerId: string; trophies: number; queuedAtMs: number };

export type MatchmakingStatus = {
  status: 'idle' | 'searching' | 'matched';
  queuedAt: string | null;
  elapsedMs: number;
  match: null | { matchId: string; serverHost: string; serverPort: number; joinToken: string };
};

/**
 * Quick Play matchmaker (API.md §1.4). The queue is in memory (v1, single
 * instance; Redis is the planned scale-out path). `tick()` is safe to call
 * directly from tests with an injected clock.
 */
export class Matchmaker {
  pool: Pool;
  config: Config;
  coordinator: MatchCoordinator;
  now: () => number;
  log: FastifyBaseLogger;
  queue = new Map<string, QueueEntry>();
  /** queuedAt of players that were matched, for status display. */
  matchedQueuedAt = new Map<string, number>();
  /** Extra "is this player busy elsewhere" check (rooms), injected by the app. */
  isInRoom: (playerId: string) => boolean = () => false;
  private ticking = false;
  private pendingEnqueue = new Set<string>();

  constructor(opts: { pool: Pool; config: Config; coordinator: MatchCoordinator; now: () => number; log: FastifyBaseLogger }) {
    this.pool = opts.pool;
    this.config = opts.config;
    this.coordinator = opts.coordinator;
    this.now = opts.now;
    this.log = opts.log;
    this.coordinator.onEnded((m) => {
      for (const pid of m.playerIds) this.matchedQueuedAt.delete(pid);
    });
  }

  isQueued(playerId: string): boolean {
    return this.queue.has(playerId) || this.pendingEnqueue.has(playerId);
  }

  private assertFree(playerId: string): void {
    if (this.isQueued(playerId)) throw conflict('Already searching for a match');
    if (this.coordinator.forPlayer(playerId)) throw conflict('Already in an active match');
    if (this.isInRoom(playerId)) throw conflict('Already in a private room');
  }

  async enqueue(playerId: string): Promise<MatchmakingStatus> {
    this.assertFree(playerId);
    this.pendingEnqueue.add(playerId);
    try {
      const { rows } = await this.pool.query<{ trophies: number }>(`SELECT trophies FROM players WHERE id = $1`, [playerId]);
      const row = rows[0];
      if (!row) throw notFound('Player not found');
      this.queue.set(playerId, { playerId, trophies: row.trophies, queuedAtMs: this.now() });
    } finally {
      this.pendingEnqueue.delete(playerId);
    }
    this.log.info({ playerId }, 'player queued');
    return this.status(playerId);
  }

  /** No-op when not searching; cannot cancel once matched. */
  cancel(playerId: string): void {
    if (this.queue.delete(playerId)) this.log.info({ playerId }, 'player left queue');
  }

  status(playerId: string): MatchmakingStatus {
    const nowMs = this.now();
    const m = this.coordinator.forPlayer(playerId);
    if (m && m.mode === 'quick') {
      const queuedAtMs = this.matchedQueuedAt.get(playerId) ?? m.createdAtMs;
      return {
        status: 'matched',
        queuedAt: new Date(queuedAtMs).toISOString(),
        elapsedMs: Math.max(0, nowMs - queuedAtMs),
        match: {
          matchId: m.matchId,
          serverHost: m.serverHost,
          serverPort: m.serverPort,
          joinToken: issueJoinToken(this.config.joinTokenSecret, m.matchId, playerId, nowMs, this.config.joinTokenTtlSec),
        },
      };
    }
    const q = this.queue.get(playerId);
    if (q) {
      return {
        status: 'searching',
        queuedAt: new Date(q.queuedAtMs).toISOString(),
        elapsedMs: Math.max(0, nowMs - q.queuedAtMs),
        match: null,
      };
    }
    return { status: 'idle', queuedAt: null, elapsedMs: 0, match: null };
  }

  trophyWindow(waitMs: number): number {
    const { trophyWindow, trophyWindowStep, trophyWindowStepMs } = this.config.mm;
    return trophyWindow + trophyWindowStep * Math.floor(Math.max(0, waitMs) / trophyWindowStepMs);
  }

  /**
   * One matchmaking pass. Players are considered oldest first; each anchor
   * gathers the oldest compatible players within its trophy window (the anchor
   * is always the longest-waiting member, so its window is the group's window).
   * Returns the number of matches created.
   */
  async tick(): Promise<number> {
    if (this.ticking) return 0;
    this.ticking = true;
    let created = 0;
    try {
      const { maxPlayers, minPlayers, fillWaitMs, courseId, targetPoints } = this.config.mm;
      const nowMs = this.now();
      // Stable sort: ties keep queue insertion order.
      const entries = [...this.queue.values()].sort((a, b) => a.queuedAtMs - b.queuedAtMs);
      const used = new Set<string>();
      for (const anchor of entries) {
        if (used.has(anchor.playerId)) continue;
        if (!this.coordinator.hasFreeServer()) break;
        const waitMs = nowMs - anchor.queuedAtMs;
        const window = this.trophyWindow(waitMs);
        const group: QueueEntry[] = [anchor];
        for (const c of entries) {
          if (group.length >= maxPlayers) break;
          if (c === anchor || used.has(c.playerId)) continue;
          if (Math.abs(c.trophies - anchor.trophies) <= window) group.push(c);
        }
        const ready = group.length >= maxPlayers || (group.length >= minPlayers && waitMs >= fillWaitMs);
        if (!ready) continue;

        for (const g of group) {
          used.add(g.playerId);
          this.queue.delete(g.playerId);
        }
        let ok = false;
        try {
          const match = await this.coordinator.create({
            mode: 'quick',
            ranked: true,
            courseId,
            targetPoints,
            playerIds: group.map((g) => g.playerId),
          });
          if (match) {
            ok = true;
            created += 1;
            for (const g of group) this.matchedQueuedAt.set(g.playerId, g.queuedAtMs);
          }
        } catch (err) {
          this.log.error({ err }, 'failed to create quick match');
        }
        if (!ok) {
          // Put them back with their original queue time (unless they cancelled meanwhile they never left).
          for (const g of group) {
            if (!this.coordinator.forPlayer(g.playerId)) this.queue.set(g.playerId, g);
          }
          break;
        }
      }
    } finally {
      this.ticking = false;
    }
    return created;
  }
}
