import { buildApp } from './app.ts';
import { loadConfig } from './config.ts';
import { createPool } from './db.ts';
import { migrate } from './migrate.ts';

const config = loadConfig();
const pool = createPool(config.databaseUrl, config.databaseSchema);
const { app, startBackground } = await buildApp(config, { pool });

try {
  const applied = await migrate(pool, { log: (m) => app.log.info(m) });
  app.log.info({ applied: applied.length }, 'migrations complete');
  await app.listen({ port: config.port, host: config.host });
  startBackground();
} catch (err) {
  app.log.fatal({ err }, 'failed to start');
  await pool.end().catch(() => {});
  process.exit(1);
}

let shuttingDown = false;
async function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  app.log.info({ signal }, 'shutting down');
  try {
    await app.close();
    await pool.end();
  } finally {
    process.exit(0);
  }
}
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
