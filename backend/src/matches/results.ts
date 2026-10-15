import { z } from 'zod';
import type { Pool, PoolClient, Queryable } from '../db.ts';
import { withTransaction } from '../db.ts';
import { badRequest, conflict, notFound } from '../errors.ts';
import { idSchema } from '../profile/appearance.ts';
import { levelForXp } from '../profile/level.ts';
import { PLAYER_COLUMNS, STANDARD_ABILITY } from '../profile/repo.ts';
import type { PlayerRow } from '../profile/repo.ts';
import type { MatchAssignment } from '../servers/registry.ts';
import { applyTrophies, computeReward } from './rewards.ts';

const count = z.int().min(0).max(1_000_000);

export const ResultSchema = z.object({
  endedReason: z.enum(['completed', 'aborted']),
  players: z
    .array(
      z.object({
        playerId: z.uuid(),
        placement: z.int().min(1).max(64),
        points: count.default(0),
        holesWon: count.default(0),
        holesPlayed: count.default(0),
        shots: count.default(0),
        abilitiesUsed: z.record(idSchema, count).default({}),
        disconnected: z.boolean().default(false),
      }),
    )
    .min(1)
    .max(64),
  holes: z
    .array(z.object({ holeId: z.string().min(1).max(64), finishOrder: z.array(z.uuid()).max(64) }))
    .max(200)
    .default([]),
});

export type MatchResultInput = z.output<typeof ResultSchema>;

export type RewardEntry = { playerId: string; trophyDelta: number; xpGained: number; coinsGained: number };

type MatchRow = {
  id: string;
  mode: 'quick' | 'private';
  ranked: boolean;
  status: string;
  assignment: MatchAssignment;
};

async function storedRewards(db: Queryable, matchId: string): Promise<RewardEntry[]> {
  const { rows } = await db.query<{ player_id: string; trophy_delta: number; xp_gained: number; coins_gained: number }>(
    `SELECT player_id, trophy_delta, xp_gained, coins_gained FROM match_players WHERE match_id = $1 ORDER BY slot`,
    [matchId],
  );
  return rows.map((r) => ({
    playerId: r.player_id,
    trophyDelta: r.trophy_delta,
    xpGained: r.xp_gained,
    coinsGained: r.coins_gained,
  }));
}

/**
 * Processes a game server's match result in ONE transaction. Idempotent on
 * matchId: the match row is locked FOR UPDATE and its status checked, so a
 * repeated (or concurrent) report returns the stored rewards and changes nothing.
 */
export async function processResult(
  pool: Pool,
  matchId: string,
  input: MatchResultInput,
  nowMs: number,
): Promise<{ rewards: RewardEntry[]; alreadyProcessed: boolean }> {
  return withTransaction(pool, async (c: PoolClient) => {
    const { rows } = await c.query<MatchRow>(
      `SELECT id, mode, ranked, status, assignment FROM matches WHERE id = $1 FOR UPDATE`,
      [matchId],
    );
    const match = rows[0];
    if (!match) throw notFound('Unknown match');
    if (match.status === 'completed' || match.status === 'aborted') {
      return { rewards: await storedRewards(c, matchId), alreadyProcessed: true };
    }
    if (match.status === 'cancelled') throw conflict('Match was cancelled');

    const roster = match.assignment.players;
    const rosterIds = new Set(roster.map((p) => p.playerId));
    const seen = new Set<string>();
    for (const p of input.players) {
      if (!rosterIds.has(p.playerId)) throw badRequest(`Player ${p.playerId} is not in the match roster`);
      if (seen.has(p.playerId)) throw badRequest(`Player ${p.playerId} is listed twice`);
      seen.add(p.playerId);
    }
    for (const id of rosterIds) {
      if (!seen.has(id)) throw badRequest(`Roster player ${id} is missing from the result`);
    }

    const sortedIds = [...rosterIds].sort();
    const { rows: playerRows } = await c.query<PlayerRow>(
      `SELECT ${PLAYER_COLUMNS} FROM players WHERE id = ANY($1::uuid[]) ORDER BY id FOR UPDATE`,
      [sortedIds],
    );
    const players = new Map(playerRows.map((r) => [r.id, r]));
    const endedAt = new Date(nowMs);
    const completed = input.endedReason === 'completed';
    const playerCount = roster.length;
    const rewards: RewardEntry[] = [];

    for (const slotEntry of roster) {
      const res = input.players.find((p) => p.playerId === slotEntry.playerId);
      const row = players.get(slotEntry.playerId);
      if (!res || !row) throw new Error(`inconsistent roster for ${slotEntry.playerId}`);

      const reward = computeReward({
        ranked: match.ranked,
        endedReason: input.endedReason,
        playerCount,
        placement: res.placement,
        holesWon: res.holesWon,
        disconnected: res.disconnected,
      });
      const { trophiesAfter, effectiveDelta } = applyTrophies(row.trophies, reward.trophyDelta);
      const xpAfter = row.xp + reward.xpGained;
      const levelBefore = levelForXp(row.xp);
      const levelAfter = levelForXp(xpAfter);
      const newHighest = trophiesAfter > row.highest_trophies;

      if (completed) {
        const usage: Record<string, number> = { ...(row.ability_usage ?? {}) };
        let abilityCount = 0;
        for (const [id, n] of Object.entries(res.abilitiesUsed)) {
          if (n <= 0) continue;
          usage[id] = (usage[id] ?? 0) + n;
          if (id !== STANDARD_ABILITY) abilityCount += n;
        }
        const won = res.placement === 1;
        const streak = won ? row.current_win_streak + 1 : 0;
        await c.query(
          `UPDATE players SET
             trophies = $2, highest_trophies = $3, highest_trophies_at = $4, xp = $5, coins = coins + $6,
             stat_matches = stat_matches + 1, stat_wins = stat_wins + $7,
             stat_holes_played = stat_holes_played + $8, stat_hole_wins = stat_hole_wins + $9,
             stat_shots = stat_shots + $10, stat_abilities_used = stat_abilities_used + $11,
             ability_usage = $12, current_win_streak = $13, longest_win_streak = GREATEST(longest_win_streak, $13),
             updated_at = $14
           WHERE id = $1`,
          [
            row.id,
            trophiesAfter,
            newHighest ? trophiesAfter : row.highest_trophies,
            newHighest ? endedAt : row.highest_trophies_at,
            xpAfter,
            reward.coinsGained,
            won ? 1 : 0,
            res.holesPlayed,
            res.holesWon,
            res.shots,
            abilityCount,
            JSON.stringify(usage),
            streak,
            endedAt,
          ],
        );
      }

      await c.query(
        `INSERT INTO match_players (match_id, player_id, slot, display_name, placement, points, holes_won, holes_played,
           shots, abilities_used, disconnected, trophy_delta, trophies_after, xp_gained, coins_gained,
           level_before, level_after, ended_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)`,
        [
          matchId,
          row.id,
          slotEntry.slot,
          slotEntry.displayName,
          res.placement,
          res.points,
          res.holesWon,
          res.holesPlayed,
          res.shots,
          JSON.stringify(res.abilitiesUsed),
          res.disconnected,
          effectiveDelta,
          trophiesAfter,
          reward.xpGained,
          reward.coinsGained,
          levelBefore,
          levelAfter,
          endedAt,
        ],
      );
      rewards.push({
        playerId: row.id,
        trophyDelta: effectiveDelta,
        xpGained: reward.xpGained,
        coinsGained: reward.coinsGained,
      });
    }

    await c.query(
      `UPDATE matches SET status = $2, ended_reason = $2, ended_at = $3, result = $4 WHERE id = $1`,
      [matchId, input.endedReason, endedAt, JSON.stringify({ holes: input.holes })],
    );
    return { rewards, alreadyProcessed: false };
  });
}

type MyRow = {
  id: string;
  mode: 'quick' | 'private';
  ranked: boolean;
  course_id: string;
  ended_at: Date;
  ended_reason: 'completed' | 'aborted';
  player_count: number;
  placement: number;
  trophy_delta: number;
  trophies_after: number;
  xp_gained: number;
  coins_gained: number;
  level_before: number;
  level_after: number;
};

function myRewards(r: MyRow) {
  return {
    trophyDelta: r.trophy_delta,
    trophiesAfter: r.trophies_after,
    xpGained: r.xp_gained,
    coinsGained: r.coins_gained,
    levelBefore: r.level_before,
    levelAfter: r.level_after,
  };
}

const MY_SELECT = `SELECT m.id, m.mode, m.ranked, m.course_id, m.ended_at, m.ended_reason,
    jsonb_array_length(m.assignment->'players')::int AS player_count,
    mp.placement, mp.trophy_delta, mp.trophies_after, mp.xp_gained, mp.coins_gained, mp.level_before, mp.level_after
  FROM match_players mp JOIN matches m ON m.id = mp.match_id`;

export async function listMyMatches(db: Queryable, playerId: string, limit: number) {
  const { rows } = await db.query<MyRow>(
    `${MY_SELECT} WHERE mp.player_id = $1 AND m.status IN ('completed', 'aborted')
     ORDER BY m.ended_at DESC, m.id DESC LIMIT $2`,
    [playerId, limit],
  );
  return rows.map((r) => ({
    matchId: r.id,
    mode: r.mode,
    ranked: r.ranked,
    courseId: r.course_id,
    endedAt: r.ended_at.toISOString(),
    endedReason: r.ended_reason,
    placement: r.placement,
    playerCount: r.player_count,
    myRewards: myRewards(r),
  }));
}

export type MatchDetailResult =
  | { kind: 'not_found' }
  | { kind: 'forbidden' }
  | { kind: 'ok'; body: unknown };

export async function getMatchDetail(db: Queryable, matchId: string, playerId: string): Promise<MatchDetailResult> {
  const { rows } = await db.query<{ status: string; assignment: MatchAssignment }>(
    `SELECT status, assignment FROM matches WHERE id = $1`,
    [matchId],
  );
  const match = rows[0];
  if (!match) return { kind: 'not_found' };
  if (!match.assignment.players.some((p) => p.playerId === playerId)) return { kind: 'forbidden' };
  if (match.status !== 'completed' && match.status !== 'aborted') return { kind: 'not_found' };

  const { rows: mine } = await db.query<MyRow>(`${MY_SELECT} WHERE mp.match_id = $1 AND mp.player_id = $2`, [
    matchId,
    playerId,
  ]);
  const me = mine[0];
  if (!me) return { kind: 'not_found' };
  const { rows: all } = await db.query<{
    player_id: string;
    display_name: string;
    placement: number;
    points: number;
    disconnected: boolean;
  }>(
    `SELECT player_id, display_name, placement, points, disconnected FROM match_players
     WHERE match_id = $1 ORDER BY placement, slot`,
    [matchId],
  );
  return {
    kind: 'ok',
    body: {
      matchId: me.id,
      mode: me.mode,
      ranked: me.ranked,
      courseId: me.course_id,
      endedAt: me.ended_at.toISOString(),
      endedReason: me.ended_reason,
      players: all.map((p) => ({
        playerId: p.player_id,
        displayName: p.display_name,
        placement: p.placement,
        points: p.points,
        disconnected: p.disconnected,
      })),
      myRewards: myRewards(me),
    },
  };
}
