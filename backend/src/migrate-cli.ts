import { config } from './config';
import { createPool } from './db';
import { migrate } from './migrate';

async function main() {
  const url =
    process.argv.includes('--test-db') ? config.testDatabaseUrl : config.databaseUrl;
  const pool = createPool(url);
  try {
    const ran = await migrate(pool);
    if (ran.length === 0) {
      console.log('No pending migrations.');
    } else {
      for (const file of ran) console.log(`Applied ${file}`);
    }
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Migration failed:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
});
