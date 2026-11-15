import { config } from './config';
import { createPool } from './db';
import { loadSeedQuestions, removeSeedQuestions, seedQuestions, SEED_NAME } from './seedQuestions';

// npm run seed:questions            adds the starter questions (safe to repeat)
// npm run seed:questions -- --remove  removes them and the community account
async function main() {
  const pool = createPool(config.databaseUrl);
  try {
    if (process.argv.includes('--remove')) {
      const removed = await removeSeedQuestions(pool);
      console.log(removed ? `Removed ${SEED_NAME} and its questions.` : 'Nothing to remove.');
    } else {
      const added = await seedQuestions(pool, loadSeedQuestions());
      console.log(`Added ${added} starter questions as ${SEED_NAME}.`);
    }
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Seeding failed:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
});
