import { randomUUID } from 'node:crypto';
import type { Appearance } from '../profile/appearance.ts';

export type MatchAssignment = {
  matchId: string;
  mode: 'quick' | 'private';
  ranked: boolean;
  courseId: string;
  targetPoints: number;
  /** Private rooms: every ball is available to everyone (host setting). Otherwise per-player unlocks by level. */
  allAbilities: boolean;
  createdAt: string;
  players: Array<{
    playerId: string;
    displayName: string;
    trophies: number;
    /** Player level (from lifetime XP); the game server derives each player's unlocked balls from it. */
    level: number;
    slot: number;
    appearance: Appearance;
  }>;
};

export type GameServer = {
  serverId: string;
  host: string;
  port: number;
  version: string;
  registeredAtMs: number;
  lastHeartbeatMs: number;
  /** Status the server last reported about itself. */
  reportedStatus: 'idle' | 'busy';
  reportedMatchId: string | null;
  /** Match the backend has allocated to this server (pending, delivered or running). */
  matchId: string | null;
  /** Assignment waiting to be handed out on the next idle heartbeat. */
  pendingAssignment: MatchAssignment | null;
};

/**
 * In-memory game server registry (v1, single backend instance; Redis is the
 * planned scale-out path).
 */
export class ServerRegistry {
  servers = new Map<string, GameServer>();

  register(host: string, port: number, version: string, nowMs: number): { server: GameServer; replaced: GameServer | null } {
    let replaced: GameServer | null = null;
    for (const s of this.servers.values()) {
      if (s.host === host && s.port === port) {
        replaced = s;
        this.servers.delete(s.serverId);
        break;
      }
    }
    const server: GameServer = {
      serverId: randomUUID(),
      host,
      port,
      version,
      registeredAtMs: nowMs,
      lastHeartbeatMs: nowMs,
      reportedStatus: 'idle',
      reportedMatchId: null,
      matchId: null,
      pendingAssignment: null,
    };
    this.servers.set(server.serverId, server);
    return { server, replaced };
  }

  get(serverId: string): GameServer | undefined {
    return this.servers.get(serverId);
  }

  /** A free server is alive, has no allocated match and last reported itself idle. */
  findFree(): GameServer | undefined {
    let best: GameServer | undefined;
    for (const s of this.servers.values()) {
      if (s.matchId !== null || s.reportedStatus !== 'idle') continue;
      if (!best || s.lastHeartbeatMs > best.lastHeartbeatMs) best = s;
    }
    return best;
  }

  hasFree(): boolean {
    return this.findFree() !== undefined;
  }

  /**
   * Records a heartbeat. Returns the pending assignment exactly once, when the
   * server reports idle; the server is considered busy from then on.
   */
  heartbeat(server: GameServer, status: 'idle' | 'busy', matchId: string | null, nowMs: number): MatchAssignment | null {
    server.lastHeartbeatMs = nowMs;
    server.reportedStatus = status;
    server.reportedMatchId = matchId;
    if (server.pendingAssignment && status === 'idle') {
      const assignment = server.pendingAssignment;
      server.pendingAssignment = null;
      server.reportedStatus = 'busy';
      return assignment;
    }
    return null;
  }

  /** Frees the server if it is still allocated to `matchId`. */
  release(serverId: string, matchId: string): void {
    const s = this.servers.get(serverId);
    if (s && s.matchId === matchId) {
      s.matchId = null;
      s.pendingAssignment = null;
      s.reportedStatus = 'idle';
      s.reportedMatchId = null;
    }
  }

  /** Removes servers with no heartbeat for `timeoutMs`; returns them. */
  sweep(nowMs: number, timeoutMs: number): GameServer[] {
    const dropped: GameServer[] = [];
    for (const s of this.servers.values()) {
      if (nowMs - s.lastHeartbeatMs >= timeoutMs) dropped.push(s);
    }
    for (const s of dropped) this.servers.delete(s.serverId);
    return dropped;
  }
}
