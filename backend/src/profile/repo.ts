import type { Queryable } from '../db.ts';
import type { Appearance } from './appearance.ts';
import { levelInfo } from './level.ts';

export type PlayerRow = {
  id: string;
  display_name: string;
  created_at: Date;
  appearance: Appearance;
  xp: number;
  trophies: number;
  highest_trophies: number;
  highest_trophies_at: Date;
  coins: number;
  stat_matches: number;
  stat_wins: number;
  stat_holes_played: number;
  stat_hole_wins: number;
  stat_shots: number;
  stat_abilities_used: number;
  ability_usage: Record<string, number>;
  current_win_streak: number;
  longest_win_streak: number;
};

export const PLAYER_COLUMNS = `id, display_name, created_at, appearance, xp, trophies, highest_trophies,
  highest_trophies_at, coins, stat_matches, stat_wins, stat_holes_played, stat_hole_wins, stat_shots,
  stat_abilities_used, ability_usage, current_win_streak, longest_win_streak`;

/** The "standard" shot is not an ability for favoriteAbility / abilitiesUsed purposes. */
export const STANDARD_ABILITY = 'standard';

export function favoriteAbility(usage: Record<string, number>): string | null {
  let best: string | null = null;
  let bestCount = 0;
  for (const [id, count] of Object.entries(usage)) {
    if (id === STANDARD_ABILITY || !(count > 0)) continue;
    if (count > bestCount || (count === bestCount && best !== null && id < best)) {
      best = id;
      bestCount = count;
    }
  }
  return best;
}

export function toProfile(row: PlayerRow) {
  const lv = levelInfo(row.xp);
  return {
    playerId: row.id,
    displayName: row.display_name,
    createdAt: row.created_at.toISOString(),
    level: lv.level,
    xp: row.xp,
    xpIntoLevel: lv.xpIntoLevel,
    xpForNextLevel: lv.xpForNextLevel,
    trophies: row.trophies,
    highestTrophies: row.highest_trophies,
    coins: row.coins,
    appearance: row.appearance,
    stats: {
      matches: row.stat_matches,
      wins: row.stat_wins,
      holesPlayed: row.stat_holes_played,
      holeWins: row.stat_hole_wins,
      shots: row.stat_shots,
      abilitiesUsed: row.stat_abilities_used,
      favoriteAbility: favoriteAbility(row.ability_usage ?? {}),
      currentWinStreak: row.current_win_streak,
      longestWinStreak: row.longest_win_streak,
    },
  };
}

export type Profile = ReturnType<typeof toProfile>;

export async function getPlayer(db: Queryable, playerId: string): Promise<PlayerRow | null> {
  const { rows } = await db.query<PlayerRow>(`SELECT ${PLAYER_COLUMNS} FROM players WHERE id = $1`, [playerId]);
  return rows[0] ?? null;
}

export async function getPlayers(db: Queryable, playerIds: string[]): Promise<Map<string, PlayerRow>> {
  const { rows } = await db.query<PlayerRow>(`SELECT ${PLAYER_COLUMNS} FROM players WHERE id = ANY($1::uuid[])`, [
    playerIds,
  ]);
  return new Map(rows.map((r) => [r.id, r]));
}
