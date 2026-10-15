import { loadConfig } from '../config.ts';
import { createPool } from '../db.ts';
import { migrate } from '../migrate.ts';

const config = loadConfig();
const pool = createPool(config.databaseUrl, config.databaseSchema);
try {
  const applied = await migrate(pool, { log: (m) => console.log(m) });
  console.log(applied.length ? `Applied ${applied.length} migration(s).` : 'Database is up to date.');
} catch (err) {
  console.error(err);
  process.exitCode = 1;
} finally {
  await pool.end();
}
