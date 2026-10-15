import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import type { Pool } from './db.ts';

export const MIGRATIONS_DIR = path.join(import.meta.dirname, '..', 'migrations');

const LOCK_KEY = 727274001;

/**
 * Applies every not-yet-applied `*.sql` file in lexical order, each in its own
 * transaction, tracking applied files in `schema_migrations`. Concurrent runners
 * are serialized with a Postgres advisory lock.
 */
export async function migrate(
  pool: Pool,
  opts: { dir?: string; log?: (msg: string) => void } = {},
): Promise<string[]> {
  const dir = opts.dir ?? MIGRATIONS_DIR;
  const log = opts.log ?? (() => {});
  const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
  const client = await pool.connect();
  const applied: string[] = [];
  try {
    await client.query('SELECT pg_advisory_lock($1)', [LOCK_KEY]);
    try {
      await client.query(
        `CREATE TABLE IF NOT EXISTS schema_migrations (
           filename text PRIMARY KEY,
           applied_at timestamptz NOT NULL DEFAULT now()
         )`,
      );
      const { rows } = await client.query<{ filename: string }>('SELECT filename FROM schema_migrations');
      const done = new Set(rows.map((r) => r.filename));
      for (const file of files) {
        if (done.has(file)) continue;
        const sql = await readFile(path.join(dir, file), 'utf8');
        await client.query('BEGIN');
        try {
          await client.query(sql);
          await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
          await client.query('COMMIT');
        } catch (err) {
          await client.query('ROLLBACK');
          throw new Error(`Migration ${file} failed: ${(err as Error).message}`, { cause: err });
        }
        applied.push(file);
        log(`applied migration ${file}`);
      }
    } finally {
      await client.query('SELECT pg_advisory_unlock($1)', [LOCK_KEY]);
    }
  } finally {
    client.release();
  }
  return applied;
}
