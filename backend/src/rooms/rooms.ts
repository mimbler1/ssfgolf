import { randomInt } from 'node:crypto';
import type { FastifyBaseLogger } from 'fastify';
import type { Config } from '../config.ts';
import type { Pool } from '../db.ts';
import { AppError, conflict, forbidden, notFound } from '../errors.ts';
import { issueJoinToken } from '../joinToken.ts';
import type { MatchCoordinator } from '../matches/coordinator.ts';

export const ROOM_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const ROOM_CODE_LENGTH = 6;

export type RoomSettings = { maxPlayers: number; targetPoints: number; courseId: string };

export type RoomMember = { playerId: string; displayName: string; ready: boolean };

export type Room = {
  code: string;
  hostId: string;
  status: 'open' | 'starting' | 'in_match';
  settings: RoomSettings;
  /** Join order; the host is promoted from here when the host leaves. */
  members: RoomMember[];
  matchId: string | null;
  lastActivityMs: number;
};

/**
 * Private rooms (API.md §1.5). In memory in v1 (single instance; Redis is the
 * planned scale-out path).
 */
export class RoomService {
  pool: Pool;
  config: Config;
  coordinator: MatchCoordinator;
  now: () => number;
  log: FastifyBaseLogger;
  rooms = new Map<string, Room>();
  byPlayer = new Map<string, string>();
  /** Injected by the app: is the player in the quick-play queue? */
  isQueued: (playerId: string) => boolean = () => false;

  constructor(opts: { pool: Pool; config: Config; coordinator: MatchCoordinator; now: () => number; log: FastifyBaseLogger }) {
    this.pool = opts.pool;
    this.config = opts.config;
    this.coordinator = opts.coordinator;
    this.now = opts.now;
    this.log = opts.log;
    this.coordinator.onEnded((m) => {
      if (!m.roomCode) return;
      const room = this.rooms.get(m.roomCode);
      if (!room || room.matchId !== m.matchId) return;
      room.status = 'open';
      room.matchId = null;
      for (const mem of room.members) mem.ready = false;
      if (room.members.length === 0) this.deleteRoom(room);
    });
  }

  roomOf(playerId: string): Room | undefined {
    const code = this.byPlayer.get(playerId);
    return code ? this.rooms.get(code) : undefined;
  }

  isInRoom(playerId: string): boolean {
    return this.byPlayer.has(playerId);
  }

  private assertFree(playerId: string): void {
    if (this.byPlayer.has(playerId)) throw conflict('Already in a room');
    if (this.isQueued(playerId)) throw conflict('Already searching for a match');
    if (this.coordinator.forPlayer(playerId)) throw conflict('Already in an active match');
  }

  private async displayName(playerId: string): Promise<string> {
    const { rows } = await this.pool.query<{ display_name: string }>(`SELECT display_name FROM players WHERE id = $1`, [
      playerId,
    ]);
    const row = rows[0];
    if (!row) throw notFound('Player not found');
    return row.display_name;
  }

  private newCode(): string {
    for (;;) {
      let code = '';
      for (let i = 0; i < ROOM_CODE_LENGTH; i++) code += ROOM_CODE_ALPHABET[randomInt(ROOM_CODE_ALPHABET.length)];
      if (!this.rooms.has(code)) return code;
    }
  }

  private lookup(code: string): Room {
    const room = this.rooms.get(code.toUpperCase());
    if (!room) throw notFound('Room not found');
    return room;
  }

  private member(room: Room, playerId: string): RoomMember {
    const m = room.members.find((x) => x.playerId === playerId);
    if (!m) throw forbidden('Not a member of this room');
    room.lastActivityMs = this.now();
    return m;
  }

  private deleteRoom(room: Room): void {
    this.rooms.delete(room.code);
    for (const m of room.members) {
      if (this.byPlayer.get(m.playerId) === room.code) this.byPlayer.delete(m.playerId);
    }
    this.log.info({ code: room.code }, 'room deleted');
  }

  view(room: Room, viewerId: string) {
    const m = room.status === 'in_match' && room.matchId ? this.coordinator.get(room.matchId) : undefined;
    const nowMs = this.now();
    return {
      code: room.code,
      hostId: room.hostId,
      status: room.status,
      settings: { ...room.settings },
      members: room.members.map((x) => ({
        playerId: x.playerId,
        displayName: x.displayName,
        ready: x.ready,
        isHost: x.playerId === room.hostId,
      })),
      match:
        m && m.playerIds.includes(viewerId)
          ? {
              matchId: m.matchId,
              serverHost: m.serverHost,
              serverPort: m.serverPort,
              joinToken: issueJoinToken(this.config.joinTokenSecret, m.matchId, viewerId, nowMs, this.config.joinTokenTtlSec),
            }
          : null,
    };
  }

  async create(playerId: string, settings: Partial<RoomSettings>): Promise<Room> {
    this.assertFree(playerId);
    const displayName = await this.displayName(playerId);
    this.assertFree(playerId);
    const room: Room = {
      code: this.newCode(),
      hostId: playerId,
      status: 'open',
      settings: {
        maxPlayers: settings.maxPlayers ?? 4,
        targetPoints: settings.targetPoints ?? this.config.mm.targetPoints,
        courseId: settings.courseId ?? this.config.mm.courseId,
      },
      members: [{ playerId, displayName, ready: false }],
      matchId: null,
      lastActivityMs: this.now(),
    };
    this.rooms.set(room.code, room);
    this.byPlayer.set(playerId, room.code);
    this.log.info({ code: room.code, hostId: playerId }, 'room created');
    return room;
  }

  get(playerId: string, code: string): Room {
    const room = this.lookup(code);
    this.member(room, playerId);
    return room;
  }

  async join(playerId: string, code: string): Promise<Room> {
    let room = this.lookup(code);
    if (room.members.some((m) => m.playerId === playerId)) {
      room.lastActivityMs = this.now();
      return room;
    }
    if (room.status !== 'open') throw conflict('Room is not open');
    if (room.members.length >= room.settings.maxPlayers) throw conflict('Room is full');
    this.assertFree(playerId);
    const displayName = await this.displayName(playerId);
    // Re-check after the await.
    room = this.lookup(code);
    if (room.status !== 'open') throw conflict('Room is not open');
    if (room.members.length >= room.settings.maxPlayers) throw conflict('Room is full');
    this.assertFree(playerId);
    room.members.push({ playerId, displayName, ready: false });
    room.lastActivityMs = this.now();
    this.byPlayer.set(playerId, room.code);
    return room;
  }

  leave(playerId: string, code: string): void {
    const room = this.lookup(code);
    this.member(room, playerId);
    room.members = room.members.filter((m) => m.playerId !== playerId);
    this.byPlayer.delete(playerId);
    if (room.members.length === 0) {
      if (room.status !== 'in_match') this.deleteRoom(room);
      else this.rooms.delete(room.code); // match continues; nobody left to return to the room
      return;
    }
    if (room.hostId === playerId) {
      const next = room.members[0];
      if (next) {
        room.hostId = next.playerId;
        next.ready = false;
      }
    }
  }

  setReady(playerId: string, code: string, ready: boolean): Room {
    const room = this.lookup(code);
    const m = this.member(room, playerId);
    if (room.status !== 'open') throw conflict('Room is not open');
    m.ready = ready;
    return room;
  }

  updateSettings(playerId: string, code: string, patch: Partial<RoomSettings>): Room {
    const room = this.lookup(code);
    this.member(room, playerId);
    if (room.hostId !== playerId) throw forbidden('Only the host can change settings');
    if (room.status !== 'open') throw conflict('Room is not open');
    if (patch.maxPlayers !== undefined && patch.maxPlayers < room.members.length) {
      throw conflict('maxPlayers is below the current member count');
    }
    room.settings = { ...room.settings, ...patch };
    for (const m of room.members) if (m.playerId !== room.hostId) m.ready = false;
    return room;
  }

  async start(playerId: string, code: string): Promise<Room> {
    const room = this.lookup(code);
    this.member(room, playerId);
    if (room.hostId !== playerId) throw forbidden('Only the host can start the match');
    if (room.status !== 'open') throw conflict('Room is not open');
    if (room.members.length < 2) throw conflict('At least 2 members are required');
    if (room.members.some((m) => m.playerId !== room.hostId && !m.ready)) throw conflict('Not all members are ready');
    if (!this.coordinator.hasFreeServer()) throw new AppError(503, 'no_server', 'No game server is available');

    room.status = 'starting';
    try {
      // Host gets slot 0, then the rest in join order.
      const ordered = [room.hostId, ...room.members.map((m) => m.playerId).filter((id) => id !== room.hostId)];
      const match = await this.coordinator.create({
        mode: 'private',
        ranked: false,
        courseId: room.settings.courseId,
        targetPoints: room.settings.targetPoints,
        playerIds: ordered,
        roomCode: room.code,
      });
      if (!match) {
        if (room.status === 'starting') room.status = 'open';
        throw new AppError(503, 'no_server', 'No game server is available');
      }
      room.status = 'in_match';
      room.matchId = match.matchId;
      this.log.info({ code: room.code, matchId: match.matchId }, 'room match started');
      return room;
    } catch (err) {
      if (room.status === 'starting') room.status = 'open';
      throw err;
    }
  }

  /** Deletes rooms that have seen no member request for `roomIdleMs` (rooms in a match are kept). */
  sweep(): void {
    const nowMs = this.now();
    for (const room of [...this.rooms.values()]) {
      if (room.status === 'open' && nowMs - room.lastActivityMs >= this.config.roomIdleMs) this.deleteRoom(room);
    }
  }
}
