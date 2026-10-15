import pg from 'pg';

export type Pool = pg.Pool;
export type PoolClient = pg.PoolClient;
/** Anything that can run a query: the pool or a checked-out client. */
export type Queryable = pg.Pool | pg.PoolClient;

export function createPool(connectionString: string, schema: string | null = null): pg.Pool {
  const config: pg.PoolConfig = { connectionString, max: 10 };
  if (schema) {
    if (!/^[a-z_][a-z0-9_]*$/.test(schema)) throw new Error(`Invalid schema name: ${schema}`);
    config.options = `-c search_path=${schema}`;
  }
  return new pg.Pool(config);
}

export async function withTransaction<T>(pool: pg.Pool, fn: (client: pg.PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // ignore rollback failure; the original error is more useful
    }
    throw err;
  } finally {
    client.release();
  }
}
